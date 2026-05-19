// SPDX-License-Identifier: BUSL-1.1

/// PrizeComponent handles prize storage, deposits, and claims for any context.
/// This component manages:
/// - Prize storage and retrieval
/// - Prize deposit processing
/// - Prize claim tracking
/// - Total prize count metrics
///
/// TODO: Reclaim prize functionality for unclaimed prizes based on some context rules

#[starknet::component]
pub mod PrizeComponent {
    use core::num::traits::Zero;
    use game_components_interfaces::prize::{IPRIZE_ID, IPrize};
    use metagame_extensions_interfaces::extension::ExtensionConfig;
    use metagame_extensions_interfaces::prize_extension::{
        IPRIZE_EXTENSION_ID, IPrizeExtensionDispatcher, IPrizeExtensionDispatcherTrait,
    };
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::prize::prize::prize::hash_prize_type;
    use crate::prize::prize_store::{PrizeStoreImpl, PrizeStoreTrait};
    use crate::prize::store::Store;
    use crate::prize::structs::{
        CustomShares, ExtensionPrizePayload, Prize, PrizeRecord, PrizeType, StoredPrize,
        TokenPrizePayload, TokenTypeData,
    };

    #[storage]
    pub struct Storage {
        /// Prize data keyed by prize_id
        /// Uses StoredPrize for storage (with Store trait)
        /// For ERC20: amount + distribution config packed efficiently
        Prize_prizes: Map<u64, StoredPrize>,
        /// Prize claims keyed by (context_id, prize_type_hash)
        /// where prize_type_hash is poseidon hash of serialized PrizeType
        Prize_claims: Map<(u64, felt252), bool>,
        /// Total prizes created across all contexts
        Prize_total_prizes: u64,
        /// Packed custom distribution shares: (prize_id, slot_index) -> CustomShares
        /// Each slot packs up to 15 u16 shares (16 bits each = 240 bits per felt252)
        /// slot_index = share_index / 15
        Prize_custom_shares_packed: Map<(u64, u8), CustomShares>,
        /// Number of custom shares for a prize
        Prize_custom_shares_count: Map<u64, u32>,
        /// Extension address keyed by (context_id, prize_id). The
        /// extension contract owns the authoritative config — we only
        /// store the address needed for claim-time dispatch and to
        /// resolve `IPrizeExtension.get_config` for reads.
        Prize_extension_address: Map<(u64, u64), ContractAddress>,
        /// `prize_id -> context_id` reverse index for extension prizes.
        /// Needed because `get_prize(prize_id)` takes only the id but
        /// extension storage is keyed by (context_id, prize_id). Built-in
        /// prizes have their context_id stored in `StoredPrize.context_id`
        /// and are absent from this map.
        Prize_extension_prize_context: Map<u64, u64>,
        /// `prize_id -> sponsor_address` for extension prizes (the
        /// caller of `add_prize` at registration). Built-in prizes
        /// keep sponsor on `StoredPrize.sponsor_address`.
        Prize_extension_prize_sponsor: Map<u64, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    // Implement the Store trait for this component
    impl ComponentStore<
        TContractState, +HasComponent<TContractState>,
    > of Store<ComponentState<TContractState>> {
        fn get_prize(self: @ComponentState<TContractState>, prize_id: u64) -> StoredPrize {
            self.Prize_prizes.entry(prize_id).read()
        }

        fn set_prize(ref self: ComponentState<TContractState>, prize_id: u64, prize: StoredPrize) {
            self.Prize_prizes.entry(prize_id).write(prize);
        }

        fn get_claim(
            self: @ComponentState<TContractState>, context_id: u64, hash: felt252,
        ) -> bool {
            self.Prize_claims.entry((context_id, hash)).read()
        }

        fn set_claim(
            ref self: ComponentState<TContractState>, context_id: u64, hash: felt252, claimed: bool,
        ) {
            self.Prize_claims.entry((context_id, hash)).write(claimed);
        }

        fn get_total_prizes(self: @ComponentState<TContractState>) -> u64 {
            self.Prize_total_prizes.read()
        }

        fn set_total_prizes(ref self: ComponentState<TContractState>, count: u64) {
            self.Prize_total_prizes.write(count);
        }

        fn get_custom_shares_count(self: @ComponentState<TContractState>, prize_id: u64) -> u32 {
            self.Prize_custom_shares_count.entry(prize_id).read()
        }

        fn set_custom_shares_count(
            ref self: ComponentState<TContractState>, prize_id: u64, count: u32,
        ) {
            self.Prize_custom_shares_count.entry(prize_id).write(count);
        }

        fn get_custom_shares_packed(
            self: @ComponentState<TContractState>, prize_id: u64, slot: u8,
        ) -> CustomShares {
            self.Prize_custom_shares_packed.entry((prize_id, slot)).read()
        }

        fn set_custom_shares_packed(
            ref self: ComponentState<TContractState>, prize_id: u64, slot: u8, shares: CustomShares,
        ) {
            self.Prize_custom_shares_packed.entry((prize_id, slot)).write(shares);
        }

        fn get_extension_address(
            self: @ComponentState<TContractState>, context_id: u64, prize_id: u64,
        ) -> ContractAddress {
            self.Prize_extension_address.entry((context_id, prize_id)).read()
        }

        fn set_extension_address(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            addr: ContractAddress,
        ) {
            self.Prize_extension_address.entry((context_id, prize_id)).write(addr);
        }

        fn get_extension_prize_context(
            self: @ComponentState<TContractState>, prize_id: u64,
        ) -> u64 {
            self.Prize_extension_prize_context.entry(prize_id).read()
        }

        fn set_extension_prize_context(
            ref self: ComponentState<TContractState>, prize_id: u64, context_id: u64,
        ) {
            self.Prize_extension_prize_context.entry(prize_id).write(context_id);
        }

        fn get_extension_prize_sponsor(
            self: @ComponentState<TContractState>, prize_id: u64,
        ) -> ContractAddress {
            self.Prize_extension_prize_sponsor.entry(prize_id).read()
        }

        fn set_extension_prize_sponsor(
            ref self: ComponentState<TContractState>, prize_id: u64, sponsor: ContractAddress,
        ) {
            self.Prize_extension_prize_sponsor.entry(prize_id).write(sponsor);
        }
    }

    /// Resolve a `prize_id` to its full `Prize` sum-type view.
    ///
    /// Branching: the `Prize_extension_prize_context` reverse index is
    /// populated only for extension prizes. A non-zero read identifies
    /// the prize as an extension, lets us reconstruct the
    /// `(context_id, prize_id)` key, and we dispatch to the
    /// extension's `get_config` view to fetch the original config
    /// blob. Built-in prizes fall through to the
    /// `PrizeStoreTrait::get_token_prize` store-bridge path.
    fn resolve_prize<TContractState, +HasComponent<TContractState>>(
        self: @ComponentState<TContractState>, prize_id: u64,
    ) -> PrizeRecord {
        let context_id = Store::get_extension_prize_context(self, prize_id);
        if context_id == 0 {
            return PrizeStoreTrait::get_token_record(self, prize_id);
        }
        let extension_address = Store::get_extension_address(self, context_id, prize_id);
        let sponsor_address = Store::get_extension_prize_sponsor(self, prize_id);
        let context_owner = get_contract_address();
        let dispatcher = IPrizeExtensionDispatcher { contract_address: extension_address };
        let extension_config = dispatcher.get_config(context_owner, context_id, prize_id);
        PrizeRecord {
            id: prize_id,
            context_id,
            sponsor_address,
            prize: Prize::Extension(
                ExtensionPrizePayload { address: extension_address, config: extension_config },
            ),
        }
    }

    #[embeddable_as(PrizeImpl)]
    impl PrizeComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IPrize<ComponentState<TContractState>> {
        fn get_prize(self: @ComponentState<TContractState>, prize_id: u64) -> PrizeRecord {
            resolve_prize(self, prize_id)
        }

        fn get_total_prizes(self: @ComponentState<TContractState>) -> u64 {
            PrizeStoreTrait::get_total_prizes(self)
        }

        fn is_prize_claimed(
            self: @ComponentState<TContractState>, context_id: u64, prize_type: PrizeType,
        ) -> bool {
            PrizeStoreTrait::is_prize_claimed(self, context_id, prize_type)
        }
    }

    #[generate_trait]
    pub impl PrizeInternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of PrizeInternalTrait<TContractState> {
        /// Get a prize by its ID.
        ///
        /// For built-in (`Prize::Config`) prizes this reads the
        /// `StoredPrize` slot and assembles a `PrizeData { kind: Config, ... }`.
        ///
        /// For extension (`Prize::Extension`) prizes this:
        ///   1. detects the kind via the `prize_id -> context_id`
        ///      reverse index populated by `_set_extension`,
        ///   2. reads the extension address from
        ///      `Prize_extension_address[(context_id, prize_id)]`,
        ///   3. dispatches `IPrizeExtension.get_config(...)` to fetch
        ///      the original config blob the sponsor passed at
        ///      `add_prize` time,
        ///   4. assembles a `PrizeData { kind: Extension, ... }`.
        ///
        /// Note: extension prizes incur a cross-contract call on every
        /// read. Callers wanting bulk reads should batch / cache
        /// accordingly.
        fn _get_prize(self: @ComponentState<TContractState>, prize_id: u64) -> PrizeRecord {
            resolve_prize(self, prize_id)
        }

        /// Get custom shares for a prize (used for Custom distribution)
        /// Uses packed storage: reads 1 slot per 15 shares instead of 1 slot per share
        fn _get_custom_shares(self: @ComponentState<TContractState>, prize_id: u64) -> Array<u16> {
            PrizeStoreTrait::get_custom_shares(self, prize_id)
        }

        /// Store a token-prize record (converts to StoredPrize for storage).
        /// Extension prizes are not persisted via this path.
        fn set_token_record(
            ref self: ComponentState<TContractState>,
            prize_id: u64,
            context_id: u64,
            sponsor_address: ContractAddress,
            payload: TokenPrizePayload,
        ) {
            PrizeStoreTrait::set_token_record(
                ref self, prize_id, context_id, sponsor_address, payload,
            );
        }

        /// Get total prizes count (internal)
        fn _get_total_prizes(self: @ComponentState<TContractState>) -> u64 {
            PrizeStoreTrait::get_total_prizes(self)
        }

        /// Increment total prizes and return the new prize ID
        fn increment_prize_count(ref self: ComponentState<TContractState>) -> u64 {
            PrizeStoreTrait::increment_prize_count(ref self)
        }

        /// Hash a prize type for use as storage key
        fn hash_prize_type(
            self: @ComponentState<TContractState>, prize_type: PrizeType,
        ) -> felt252 {
            hash_prize_type(prize_type)
        }

        /// Check if a prize has been claimed (internal)
        fn _is_prize_claimed(
            self: @ComponentState<TContractState>, context_id: u64, prize_type: PrizeType,
        ) -> bool {
            PrizeStoreTrait::is_prize_claimed(self, context_id, prize_type)
        }

        /// Check if a prize has been claimed using pre-computed hash (gas optimization)
        fn _is_prize_claimed_by_hash(
            self: @ComponentState<TContractState>, context_id: u64, prize_type_hash: felt252,
        ) -> bool {
            PrizeStoreTrait::is_prize_claimed_by_hash(self, context_id, prize_type_hash)
        }

        /// Mark a prize as claimed
        fn set_prize_claimed(
            ref self: ComponentState<TContractState>, context_id: u64, prize_type: PrizeType,
        ) {
            PrizeStoreTrait::set_prize_claimed(ref self, context_id, prize_type);
        }

        /// Mark a prize as claimed using pre-computed hash (gas optimization)
        fn _set_prize_claimed_by_hash(
            ref self: ComponentState<TContractState>, context_id: u64, prize_type_hash: felt252,
        ) {
            PrizeStoreTrait::set_prize_claimed_by_hash(ref self, context_id, prize_type_hash);
        }

        /// Assert that a prize exists (has non-zero token address)
        fn assert_prize_exists(self: @ComponentState<TContractState>, prize_id: u64) {
            PrizeStoreTrait::assert_prize_exists(self, prize_id);
        }

        /// Assert that a prize has not been claimed
        fn assert_prize_not_claimed(
            self: @ComponentState<TContractState>, context_id: u64, prize_type: PrizeType,
        ) {
            PrizeStoreTrait::assert_prize_not_claimed(self, context_id, prize_type);
        }

        /// Assert that a prize has not been claimed using pre-computed hash (gas optimization)
        fn _assert_prize_not_claimed_by_hash(
            self: @ComponentState<TContractState>, context_id: u64, prize_type_hash: felt252,
        ) {
            PrizeStoreTrait::assert_prize_not_claimed_by_hash(self, context_id, prize_type_hash);
        }

        /// Add a prize or set extension for a context.
        /// Returns the prize_id in both cases.
        /// - `Prize::Token(payload)`: deposits tokens, stores prize
        ///   data. Host assigns id/context_id/sponsor_address.
        /// - `Prize::Extension(payload)`: increments prize count,
        ///   registers the extension address keyed by
        ///   `(context_id, prize_id)`, captures sponsor, and
        ///   dispatches `IPrizeExtension.add_prize(...)`.
        fn add_prize(
            ref self: ComponentState<TContractState>, context_id: u64, prize: Prize,
        ) -> u64 {
            match prize {
                Prize::Token(payload) => self._add_token_prize(context_id, payload),
                Prize::Extension(payload) => {
                    let ext = ExtensionConfig { address: payload.address, config: payload.config };
                    assert!(!ext.address.is_zero(), "Prize: Extension address cannot be zero");
                    let src5 = ISRC5Dispatcher { contract_address: ext.address };
                    let display_address: felt252 = ext.address.into();
                    assert!(
                        src5.supports_interface(IPRIZE_EXTENSION_ID),
                        "Prize: Extension {} does not support IPrizeExtension",
                        display_address,
                    );
                    let prize_id = PrizeStoreTrait::increment_prize_count(ref self);
                    self._set_extension(context_id, prize_id, ext);
                    prize_id
                },
            }
        }

        /// Internal: deposit tokens, store prize data, return prize_id.
        /// Host fills in the id (assigned), context_id (caller-supplied),
        /// and sponsor_address (`get_caller_address()`) around the
        /// supplied `payload`.
        fn _add_token_prize(
            ref self: ComponentState<TContractState>, context_id: u64, payload: TokenPrizePayload,
        ) -> u64 {
            let token_address = payload.token_address;
            let token_type = payload.token_type;

            // Deposit the prize tokens
            match @token_type {
                TokenTypeData::erc20(erc20_data) => {
                    let amount = *erc20_data.amount;
                    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
                    assert!(amount > 0, "Prize: ERC20 prize token amount must be greater than 0");
                    assert!(
                        token_dispatcher
                            .transfer_from(
                                get_caller_address(), get_contract_address(), amount.into(),
                            ),
                        "Prize: ERC20 transfer_from failed",
                    );
                },
                TokenTypeData::erc721(erc721_data) => {
                    let token_id = *erc721_data.id;
                    let token_dispatcher = IERC721Dispatcher { contract_address: token_address };
                    token_dispatcher
                        .transfer_from(
                            get_caller_address(), get_contract_address(), token_id.into(),
                        );
                },
            }

            // Get next prize ID
            let id = PrizeStoreTrait::increment_prize_count(ref self);

            // Store custom shares if this is a Custom distribution (using packed storage)
            if let TokenTypeData::erc20(erc20_data) = @token_type {
                if let Option::Some(dist) = erc20_data.distribution {
                    if let game_components_utilities::distribution::structs::Distribution::Custom(shares) =
                        dist {
                        PrizeStoreTrait::store_custom_shares(ref self, id, *shares);
                    }
                }
            }

            // Persist the built-in token prize. Host fills id,
            // context_id, sponsor_address around the supplied payload.
            let sponsor = get_caller_address();
            let payload = TokenPrizePayload { token_address, token_type };
            PrizeStoreTrait::set_token_record(ref self, id, context_id, sponsor, payload);

            id
        }

        /// Internal: persist the extension address + the reverse
        /// `prize_id -> context_id` index, then forward the config to
        /// the extension. The config blob is NOT persisted here — it
        /// lives on the extension contract, and reads (`get_prize`)
        /// fetch it back via `IPrizeExtension.get_config`.
        fn _set_extension(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            ext: ExtensionConfig,
        ) {
            Store::set_extension_address(ref self, context_id, prize_id, ext.address);
            // Reverse index for the prize_id-only `get_prize` lookup.
            Store::set_extension_prize_context(ref self, prize_id, context_id);
            // Capture sponsor (the caller of the host's `add_prize`).
            Store::set_extension_prize_sponsor(ref self, prize_id, get_caller_address());

            let dispatcher = IPrizeExtensionDispatcher { contract_address: ext.address };
            dispatcher.add_prize(context_id, prize_id, ext.config);
        }

        /// Forward a claim call to the prize extension configured for
        /// `(context_id, prize_id)`. Reverts if `prize_id` was added via
        /// the built-in `Prize::Config` path (no extension address
        /// stored). `claim_params` is opaque — the extension deserializes
        /// whatever shape it expects.
        ///
        /// Hosts are responsible for any cross-cutting concerns
        /// (finalization checks, reentrancy guards, double-claim
        /// protection on the host side) before invoking this.
        fn claim_prize_extension(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            claim_params: Span<felt252>,
        ) {
            let extension_address = Store::get_extension_address(@self, context_id, prize_id);
            assert!(!extension_address.is_zero(), "Prize: No extension configured for prize");
            let dispatcher = IPrizeExtensionDispatcher { contract_address: extension_address };
            dispatcher.claim_prize(context_id, prize_id, claim_params);
        }

        /// Payout full ERC20 amount to a recipient
        fn payout_erc20(
            ref self: ComponentState<TContractState>,
            token_address: ContractAddress,
            amount: u128,
            recipient: ContractAddress,
        ) {
            let erc20 = IERC20Dispatcher { contract_address: token_address };
            assert!(erc20.transfer(recipient, amount.into()), "Prize: ERC20 transfer failed");
        }

        /// Payout ERC721 to a recipient
        fn payout_erc721(
            ref self: ComponentState<TContractState>,
            token_address: ContractAddress,
            token_id: u128,
            recipient: ContractAddress,
        ) {
            let erc721 = IERC721Dispatcher { contract_address: token_address };
            erc721.transfer_from(get_contract_address(), recipient, token_id.into());
        }

        /// Refund ERC20 prize to the original sponsor
        fn refund_prize_erc20(
            ref self: ComponentState<TContractState>, prize_id: u64, amount: u128,
        ) {
            let record = PrizeStoreTrait::get_token_record(@self, prize_id);
            let token_address = match record.prize {
                Prize::Token(payload) => payload.token_address,
                Prize::Extension(_) => panic!("Prize: extension prize cannot be refunded as ERC20"),
            };
            let erc20 = IERC20Dispatcher { contract_address: token_address };
            assert!(
                erc20.transfer(record.sponsor_address, amount.into()),
                "Prize: ERC20 refund transfer failed",
            );
        }

        /// Refund ERC721 prize to the original sponsor
        fn refund_prize_erc721(
            ref self: ComponentState<TContractState>, prize_id: u64, token_id: u128,
        ) {
            let record = PrizeStoreTrait::get_token_record(@self, prize_id);
            let token_address = match record.prize {
                Prize::Token(payload) => payload.token_address,
                Prize::Extension(_) => panic!(
                    "Prize: extension prize cannot be refunded as ERC721",
                ),
            };
            let erc721 = IERC721Dispatcher { contract_address: token_address };
            erc721.transfer_from(get_contract_address(), record.sponsor_address, token_id.into());
        }

        // --- Extension helpers ---

        /// Get extension address for a context and prize (zero = built-in).
        fn get_extension_address(
            self: @ComponentState<TContractState>, context_id: u64, prize_id: u64,
        ) -> ContractAddress {
            Store::get_extension_address(self, context_id, prize_id)
        }
    }

    #[generate_trait]
    pub impl PrizeInitializerImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of PrizeInitializerTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IPRIZE_ID);
        }
    }
}
