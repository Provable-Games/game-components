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
    use game_components_interfaces::prize::{IPRIZE_ID, IPrize};
    use metagame_extensions_interfaces::extension::ExtensionConfig;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::prize::store::Store;
    use crate::prize::structs::{
        CustomShares, Prize, PrizeRecord, PrizeType, StoredPrize, TokenPrizePayload,
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
        /// `prize_id -> 1-indexed leaderboard position` for built-in
        /// non-distributed prizes (Single payouts to position N).
        /// Distributed prizes don't use this; extension prizes own
        /// their own per-position semantics. Zero means unset.
        Prize_payout_position: Map<u64, u32>,
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

        fn get_payout_position(self: @ComponentState<TContractState>, prize_id: u64) -> u32 {
            self.Prize_payout_position.entry(prize_id).read()
        }

        fn set_payout_position(
            ref self: ComponentState<TContractState>, prize_id: u64, position: u32,
        ) {
            self.Prize_payout_position.entry(prize_id).write(position);
        }
    }


    #[embeddable_as(PrizeImpl)]
    impl PrizeComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IPrize<ComponentState<TContractState>> {
        fn get_prize(self: @ComponentState<TContractState>, prize_id: u64) -> PrizeRecord {
            crate::prize::api::PrizeImpl::get_prize(self, prize_id)
        }

        fn get_total_prizes(self: @ComponentState<TContractState>) -> u64 {
            crate::prize::api::PrizeImpl::get_total_prizes(self)
        }

        fn is_prize_claimed(
            self: @ComponentState<TContractState>, context_id: u64, prize_type: PrizeType,
        ) -> bool {
            crate::prize::api::PrizeImpl::is_prize_claimed(self, context_id, prize_type)
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
            crate::prize::api::PrizeInternalImpl::_get_prize(self, prize_id)
        }

        /// Get custom shares for a prize (used for Custom distribution)
        /// Uses packed storage: reads 1 slot per 15 shares instead of 1 slot per share
        fn _get_custom_shares(self: @ComponentState<TContractState>, prize_id: u64) -> Array<u16> {
            crate::prize::api::PrizeInternalImpl::_get_custom_shares(self, prize_id)
        }

        /// One custom share by 1-indexed position — a single storage read.
        ///
        /// `_get_prize` deliberately returns Custom with an empty span, so a
        /// claim settling one position reads its share through here instead of
        /// paying to rebuild the whole curve.
        fn _get_custom_share_at(
            self: @ComponentState<TContractState>, prize_id: u64, position: u32,
        ) -> u16 {
            crate::prize::api::PrizeInternalImpl::_get_custom_share_at(self, prize_id, position)
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
            crate::prize::api::PrizeInternalImpl::set_token_record(
                ref self, prize_id, context_id, sponsor_address, payload,
            )
        }

        /// Get total prizes count (internal)
        fn _get_total_prizes(self: @ComponentState<TContractState>) -> u64 {
            crate::prize::api::PrizeInternalImpl::_get_total_prizes(self)
        }

        /// Increment total prizes and return the new prize ID
        fn increment_prize_count(ref self: ComponentState<TContractState>) -> u64 {
            crate::prize::api::PrizeInternalImpl::increment_prize_count(ref self)
        }

        /// Hash a prize type for use as storage key
        fn hash_prize_type(
            self: @ComponentState<TContractState>, prize_type: PrizeType,
        ) -> felt252 {
            crate::prize::api::PrizeInternalImpl::hash_prize_type(self, prize_type)
        }

        /// Check if a prize has been claimed (internal)
        fn _is_prize_claimed(
            self: @ComponentState<TContractState>, context_id: u64, prize_type: PrizeType,
        ) -> bool {
            crate::prize::api::PrizeInternalImpl::_is_prize_claimed(self, context_id, prize_type)
        }

        /// Check if a prize has been claimed using pre-computed hash (gas optimization)
        fn _is_prize_claimed_by_hash(
            self: @ComponentState<TContractState>, context_id: u64, prize_type_hash: felt252,
        ) -> bool {
            crate::prize::api::PrizeInternalImpl::_is_prize_claimed_by_hash(
                self, context_id, prize_type_hash,
            )
        }

        /// Mark a prize as claimed
        fn set_prize_claimed(
            ref self: ComponentState<TContractState>, context_id: u64, prize_type: PrizeType,
        ) {
            crate::prize::api::PrizeInternalImpl::set_prize_claimed(
                ref self, context_id, prize_type,
            )
        }

        /// Mark a prize as claimed using pre-computed hash (gas optimization)
        fn _set_prize_claimed_by_hash(
            ref self: ComponentState<TContractState>, context_id: u64, prize_type_hash: felt252,
        ) {
            crate::prize::api::PrizeInternalImpl::_set_prize_claimed_by_hash(
                ref self, context_id, prize_type_hash,
            )
        }

        /// Assert that a prize exists (has non-zero token address)
        fn assert_prize_exists(self: @ComponentState<TContractState>, prize_id: u64) {
            crate::prize::api::PrizeInternalImpl::assert_prize_exists(self, prize_id)
        }

        /// Assert that a prize has not been claimed
        fn assert_prize_not_claimed(
            self: @ComponentState<TContractState>, context_id: u64, prize_type: PrizeType,
        ) {
            crate::prize::api::PrizeInternalImpl::assert_prize_not_claimed(
                self, context_id, prize_type,
            )
        }

        /// Read the leaderboard position a built-in prize pays out to.
        /// Zero when unset (distributed prizes, extension prizes, or
        /// prizes added without a position).
        fn get_payout_position(self: @ComponentState<TContractState>, prize_id: u64) -> u32 {
            crate::prize::api::PrizeInternalImpl::get_payout_position(self, prize_id)
        }

        /// Record the leaderboard position a built-in prize pays out to.
        /// Hosts call this at add_prize time for non-distributed token
        /// prizes; the component then owns the per-prize position storage
        /// so any other consumer of PrizeComponent shares the same
        /// position-aware claim flow.
        fn set_payout_position(
            ref self: ComponentState<TContractState>, prize_id: u64, position: u32,
        ) {
            crate::prize::api::PrizeInternalImpl::set_payout_position(ref self, prize_id, position)
        }

        /// Assert that a prize has not been claimed using pre-computed hash (gas optimization)
        fn _assert_prize_not_claimed_by_hash(
            self: @ComponentState<TContractState>, context_id: u64, prize_type_hash: felt252,
        ) {
            crate::prize::api::PrizeInternalImpl::_assert_prize_not_claimed_by_hash(
                self, context_id, prize_type_hash,
            )
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
            crate::prize::api::PrizeInternalImpl::add_prize(ref self, context_id, prize)
        }

        /// Internal: deposit tokens, store prize data, return prize_id.
        /// Host fills in the id (assigned), context_id (caller-supplied),
        /// and sponsor_address (`get_caller_address()`) around the
        /// supplied `payload`.
        fn _add_token_prize(
            ref self: ComponentState<TContractState>, context_id: u64, payload: TokenPrizePayload,
        ) -> u64 {
            crate::prize::api::PrizeInternalImpl::_add_token_prize(ref self, context_id, payload)
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
            crate::prize::api::PrizeInternalImpl::_set_extension(
                ref self, context_id, prize_id, ext,
            )
        }

        /// Forward a payout call to the prize extension configured for
        /// `(context_id, prize_id)`. Reverts if `prize_id` was added via
        /// the built-in `Prize::Token` path (no extension address stored).
        ///
        /// The host is a pure dispatcher: it passes the supplied
        /// `(token_id, payout_params)` straight through. The extension
        /// resolves recipient, eligibility, and dedupe entirely from its
        /// own state. `token_id = Some(id)` typically signals a claim
        /// (extension derives recipient via `owner_of(id)`); `None`
        /// signals a non-claim flow (sponsor refund, dao distribution,
        /// raffle) and the extension extracts whatever it needs from
        /// `payout_params`.
        ///
        /// Hosts are responsible for any cross-cutting concerns
        /// (finalization checks, reentrancy guards) before invoking this.
        fn payout_prize_extension(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            token_id: Option<felt252>,
            payout_params: Span<felt252>,
        ) {
            crate::prize::api::PrizeInternalImpl::payout_prize_extension(
                ref self, context_id, prize_id, token_id, payout_params,
            )
        }

        /// Payout full ERC20 amount to a recipient
        fn payout_erc20(
            ref self: ComponentState<TContractState>,
            token_address: ContractAddress,
            amount: u128,
            recipient: ContractAddress,
        ) {
            crate::prize::api::PrizeInternalImpl::payout_erc20(
                ref self, token_address, amount, recipient,
            )
        }

        /// Payout ERC721 to a recipient
        fn payout_erc721(
            ref self: ComponentState<TContractState>,
            token_address: ContractAddress,
            token_id: u128,
            recipient: ContractAddress,
        ) {
            crate::prize::api::PrizeInternalImpl::payout_erc721(
                ref self, token_address, token_id, recipient,
            )
        }

        /// Refund ERC20 prize to the original sponsor
        fn refund_prize_erc20(
            ref self: ComponentState<TContractState>, prize_id: u64, amount: u128,
        ) {
            crate::prize::api::PrizeInternalImpl::refund_prize_erc20(ref self, prize_id, amount)
        }

        /// Refund ERC721 prize to the original sponsor
        fn refund_prize_erc721(
            ref self: ComponentState<TContractState>, prize_id: u64, token_id: u128,
        ) {
            crate::prize::api::PrizeInternalImpl::refund_prize_erc721(ref self, prize_id, token_id)
        }

        // --- Extension helpers ---

        /// Get extension address for a context and prize (zero = built-in).
        fn get_extension_address(
            self: @ComponentState<TContractState>, context_id: u64, prize_id: u64,
        ) -> ContractAddress {
            crate::prize::api::PrizeInternalImpl::get_extension_address(self, context_id, prize_id)
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
