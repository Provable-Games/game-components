/// EntryFeeComponent handles entry fee storage and deposits for any context.
/// This component manages:
/// - Entry fee configuration per context (tournament, quest, etc.)
/// - Token address and amount
/// - Game creator share and refund share (packed in EntryFeeData)
/// - Additional shares (stored separately)
/// - Entry fee deposit processing

#[starknet::component]
pub mod EntryFeeComponent {
    use core::num::traits::Zero;
    use game_components_interfaces::entry_fee::{IENTRY_FEE_ID, IEntryFee};
    use game_components_utilities::distribution::packed_shares::CustomShares;
    use game_components_utilities::distribution::structs::{
        PackedDistribution, PackedDistributionStorePacking,
    };
    use metagame_extensions_interfaces::entry_fee_extension::{
        IENTRY_FEE_EXTENSION_ID, IEntryFeeExtensionDispatcher, IEntryFeeExtensionDispatcherTrait,
    };
    use metagame_extensions_interfaces::extension::ExtensionConfig;
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::entry_fee::entry_fee_store::{EntryFeeStoreImpl, EntryFeeStoreTrait};
    use crate::entry_fee::store::Store;
    use crate::entry_fee::structs::{
        AdditionalShare, EntryFee, EntryFeeClaimType, EntryFeeConfig, EntryFeeDeposit,
        PackedAdditionalShares,
    };

    #[storage]
    pub struct Storage {
        /// Entry fee token address keyed by context_id
        EntryFee_token: Map<u64, ContractAddress>,
        /// Raw packed entry fee data keyed by context_id (felt252 for selective unpacking)
        /// Contains: amount, game_creator_share, refund_share, game_creator_claimed,
        /// additional_count
        EntryFee_data: Map<u64, felt252>,
        /// Additional share recipients per context: (context_id, index) -> recipient
        /// Recipients must be stored separately as ContractAddress is 251 bits
        EntryFee_additional_recipient: Map<(u64, u8), ContractAddress>,
        /// Packed additional shares per context: (context_id, slot_index) -> PackedAdditionalShares
        /// Each slot packs up to 16 shares (15 bits each = 240 bits per felt252)
        /// slot_index = share_index / 16
        EntryFee_additional_shares_packed: Map<(u64, u8), PackedAdditionalShares>,
        /// Packed custom distribution shares per context: (context_id, slot_index) -> CustomShares
        /// Each slot packs up to 15 u16 shares (16 bits each = 240 bits per felt252).
        /// Unset unless the context uses a `Distribution::Custom` payout split.
        /// The number of shares is the `positions` field of the sibling
        /// `EntryFee_distribution` entry (they are written atomically in
        /// `set_entry_fee_config`) — no separate count is stored.
        EntryFee_distribution_shares_packed: Map<(u64, u8), CustomShares>,
        /// Distribution shape + paid-places count packed into a single
        /// felt252 (see `PackedDistribution`). Zero-valued when no
        /// distribution is configured for the context.
        EntryFee_distribution: Map<u64, PackedDistribution>,
        /// Refund claimed: (context_id, token_id) -> claimed
        EntryFee_refund_claimed: Map<(u64, felt252), bool>,
        /// Position-based distribution claim: (context_id, position) -> claimed.
        /// Hosts that distribute the fee pool by leaderboard position use this
        /// to dedupe per-position payouts. Previously tracked in each host's
        /// own storage; centralised here so any consumer of EntryFeeComponent
        /// gets the dedupe behaviour for free.
        EntryFee_position_claimed: Map<(u64, u32), bool>,
        /// Extension address for extension-enhanced entry fees. Doubles as
        /// the "is this context's fee an extension?" flag: zero means no
        /// extension is configured. The extension contract owns the
        /// authoritative config — this component only stores the address
        /// it needs for dispatch.
        EntryFee_extension_address: Map<u64, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    // Implement the Store trait for this component
    impl ComponentStore<
        TContractState, +HasComponent<TContractState>,
    > of Store<ComponentState<TContractState>> {
        fn get_token(self: @ComponentState<TContractState>, context_id: u64) -> ContractAddress {
            self.EntryFee_token.entry(context_id).read()
        }

        fn set_token(
            ref self: ComponentState<TContractState>, context_id: u64, token: ContractAddress,
        ) {
            self.EntryFee_token.entry(context_id).write(token);
        }

        fn get_data_raw(self: @ComponentState<TContractState>, context_id: u64) -> felt252 {
            self.EntryFee_data.entry(context_id).read()
        }

        fn set_data_raw(ref self: ComponentState<TContractState>, context_id: u64, data: felt252) {
            self.EntryFee_data.entry(context_id).write(data);
        }

        fn get_additional_recipient(
            self: @ComponentState<TContractState>, context_id: u64, index: u8,
        ) -> ContractAddress {
            self.EntryFee_additional_recipient.entry((context_id, index)).read()
        }

        fn set_additional_recipient(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            index: u8,
            recipient: ContractAddress,
        ) {
            self.EntryFee_additional_recipient.entry((context_id, index)).write(recipient);
        }

        fn get_packed_shares(
            self: @ComponentState<TContractState>, context_id: u64, slot: u8,
        ) -> PackedAdditionalShares {
            self.EntryFee_additional_shares_packed.entry((context_id, slot)).read()
        }

        fn set_packed_shares(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            slot: u8,
            shares: PackedAdditionalShares,
        ) {
            self.EntryFee_additional_shares_packed.entry((context_id, slot)).write(shares);
        }

        fn get_refund_claimed(
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> bool {
            self.EntryFee_refund_claimed.entry((context_id, token_id)).read()
        }

        fn set_refund_claimed(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            token_id: felt252,
            claimed: bool,
        ) {
            self.EntryFee_refund_claimed.entry((context_id, token_id)).write(claimed);
        }

        fn get_position_claimed(
            self: @ComponentState<TContractState>, context_id: u64, position: u32,
        ) -> bool {
            self.EntryFee_position_claimed.entry((context_id, position)).read()
        }

        fn set_position_claimed(
            ref self: ComponentState<TContractState>, context_id: u64, position: u32, claimed: bool,
        ) {
            self.EntryFee_position_claimed.entry((context_id, position)).write(claimed);
        }

        fn get_extension_address(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> ContractAddress {
            self.EntryFee_extension_address.entry(context_id).read()
        }

        fn set_extension_address(
            ref self: ComponentState<TContractState>, context_id: u64, address: ContractAddress,
        ) {
            self.EntryFee_extension_address.entry(context_id).write(address);
        }

        fn get_distribution_shares_packed(
            self: @ComponentState<TContractState>, context_id: u64, slot: u8,
        ) -> CustomShares {
            self.EntryFee_distribution_shares_packed.entry((context_id, slot)).read()
        }

        fn set_distribution_shares_packed(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            slot: u8,
            shares: CustomShares,
        ) {
            self.EntryFee_distribution_shares_packed.entry((context_id, slot)).write(shares);
        }

        fn get_distribution(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> PackedDistribution {
            self.EntryFee_distribution.entry(context_id).read()
        }

        fn set_distribution(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            distribution: PackedDistribution,
        ) {
            self.EntryFee_distribution.entry(context_id).write(distribution);
        }
    }

    #[embeddable_as(EntryFeeImpl)]
    impl EntryFeeComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IEntryFee<ComponentState<TContractState>> {
        fn get_entry_fee(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Option<EntryFeeConfig> {
            EntryFeeStoreTrait::get_entry_fee(self, context_id)
        }
    }

    #[generate_trait]
    pub impl EntryFeeInternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of EntryFeeInternalTrait<TContractState> {
        /// Get entry fee for a context (internal)
        /// Returns None if no entry fee is set (token address is zero)
        fn _get_entry_fee(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Option<EntryFeeConfig> {
            EntryFeeStoreTrait::get_entry_fee(self, context_id)
        }

        /// Get additional shares for a context
        /// Uses packed storage: reads 1 slot per 16 shares instead of 1 slot per share
        fn _get_additional_shares(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Span<AdditionalShare> {
            EntryFeeStoreTrait::get_additional_shares(self, context_id)
        }

        /// Persist a custom distribution shares array for a context.
        /// Packs 15 `u16` shares per `felt252` slot via `CustomShares`.
        /// Consumers pair this with their own paid-places count semantics.
        fn _store_distribution_shares(
            ref self: ComponentState<TContractState>, context_id: u64, shares: Span<u16>,
        ) {
            EntryFeeStoreTrait::store_distribution_shares(ref self, context_id, shares);
        }

        /// Read `count` custom distribution shares for a context. Callers
        /// supply the count (typically sourced from the sibling
        /// `PackedDistribution.positions`); returns an empty array when
        /// `count == 0`.
        fn _get_distribution_shares(
            self: @ComponentState<TContractState>, context_id: u64, count: u32,
        ) -> Array<u16> {
            EntryFeeStoreTrait::get_distribution_shares(self, context_id, count)
        }

        /// Read a single custom distribution share at a 1-indexed position.
        /// O(1) — only one packed `felt252` slot is read. Use this in claim
        /// paths instead of `_get_distribution_shares` when only one share
        /// is needed.
        fn _get_custom_share_at(
            self: @ComponentState<TContractState>, context_id: u64, position: u32,
        ) -> u16 {
            EntryFeeStoreTrait::get_custom_share_at(self, context_id, position)
        }

        /// Set entry fee or extension for a context.
        /// Asserts that no entry fee has been previously set for this context.
        /// - EntryFee::Config: stores entry fee config, returns Some(EntryFeeConfig)
        /// - EntryFee::Extension: sets extension config, returns None
        fn set_entry_fee(
            ref self: ComponentState<TContractState>, context_id: u64, entry_fee: EntryFee,
        ) -> Option<EntryFeeConfig> {
            // Assert entry fee has not already been set (either config or extension)
            assert!(
                !EntryFeeStoreTrait::is_entry_fee_set(@self, context_id),
                "EntryFee: Entry fee already set for context {}",
                context_id,
            );

            match entry_fee {
                EntryFee::Config(config) => {
                    EntryFeeStoreTrait::set_entry_fee_config(ref self, context_id, @config);
                    Option::Some(config)
                },
                EntryFee::Extension(ext) => {
                    assert!(!ext.address.is_zero(), "EntryFee: Extension address cannot be zero");
                    let src5 = ISRC5Dispatcher { contract_address: ext.address };
                    let display_address: felt252 = ext.address.into();
                    assert!(
                        src5.supports_interface(IENTRY_FEE_EXTENSION_ID),
                        "EntryFee: Extension {} does not support IEntryFeeExtension",
                        display_address,
                    );
                    self._set_extension(context_id, ext);
                    Option::None
                },
            }
        }

        /// Internal: store entry fee config data
        fn _set_entry_fee_config(
            ref self: ComponentState<TContractState>, context_id: u64, config: @EntryFeeConfig,
        ) {
            EntryFeeStoreTrait::set_entry_fee_config(ref self, context_id, config);
        }

        /// Internal: persist the extension address and forward the config
        /// to the extension contract. The config blob is NOT persisted here
        /// — the extension is the sole source of truth for its own config,
        /// and indexers wanting to recover it should read the original
        /// extension call (e.g. via the host's `TournamentCreated`-style
        /// event) or query the extension's own view methods.
        fn _set_extension(
            ref self: ComponentState<TContractState>, context_id: u64, ext: ExtensionConfig,
        ) {
            EntryFeeStoreTrait::store_extension_address(ref self, context_id, ext.address);

            let dispatcher = IEntryFeeExtensionDispatcher { contract_address: ext.address };
            dispatcher.set_entry_fee_config(context_id, ext.config);
        }

        /// Process entry fee deposit.
        /// - EntryFeeDeposit::Config: transfers ERC20 tokens from caller to contract
        /// - EntryFeeDeposit::Extension: calls pay_entry_fee on the extension with
        ///   caller-provided params
        fn deposit_entry_fee(
            ref self: ComponentState<TContractState>, context_id: u64, deposit: EntryFeeDeposit,
        ) {
            match deposit {
                EntryFeeDeposit::Config(config) => {
                    let erc20_dispatcher = IERC20Dispatcher {
                        contract_address: config.token_address,
                    };
                    assert!(
                        erc20_dispatcher
                            .transfer_from(
                                get_caller_address(), get_contract_address(), config.amount.into(),
                            ),
                        "EntryFee: ERC20 transfer_from failed",
                    );
                },
                EntryFeeDeposit::Extension(pay_params) => {
                    let extension_address = EntryFeeStoreTrait::get_extension(@self, context_id);
                    assert!(!extension_address.is_zero(), "EntryFee: No extension configured");
                    let dispatcher = IEntryFeeExtensionDispatcher {
                        contract_address: extension_address,
                    };
                    dispatcher.pay_entry_fee(context_id, pay_params);
                },
            }
        }

        /// Forward a claim call to the entry-fee extension configured for
        /// `context_id`. Reverts if no extension was configured (the
        /// built-in deposit/payout path is host-owned and does not flow
        /// through this method). `claim_params` is opaque — the extension
        /// deserializes whatever shape it expects.
        ///
        /// Hosts are responsible for any cross-cutting concerns
        /// (finalization checks, reentrancy guards, replay protection on
        /// the host side) before invoking this.
        /// Forward a payout to the entry-fee extension configured for
        /// `context_id`. The host (e.g. budokan) computes recipient and
        /// (optionally) the leaderboard position the claim corresponds
        /// to; the extension is just an asset manager that executes the
        /// transfer. Hosts are responsible for any cross-cutting concerns
        /// (finalization checks, recipient validation) before invoking.
        fn payout_entry_fee_extension(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            recipient: ContractAddress,
            position: Option<u32>,
            claim_params: Span<felt252>,
        ) {
            let extension_address = EntryFeeStoreTrait::get_extension(@self, context_id);
            assert!(!extension_address.is_zero(), "EntryFee: No extension configured");
            let dispatcher = IEntryFeeExtensionDispatcher { contract_address: extension_address };
            dispatcher.payout_entry_fee(context_id, recipient, position, claim_params);
        }

        /// Payout to a recipient
        fn payout(
            ref self: ComponentState<TContractState>,
            token_address: ContractAddress,
            recipient: ContractAddress,
            amount: u128,
        ) {
            if amount > 0 {
                let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
                assert!(
                    erc20_dispatcher.transfer(recipient, amount.into()),
                    "EntryFee: ERC20 transfer failed",
                );
            }
        }

        /// Check if a claim has been made
        fn is_claimed(
            self: @ComponentState<TContractState>, context_id: u64, claim_type: EntryFeeClaimType,
        ) -> bool {
            EntryFeeStoreTrait::is_claimed(self, context_id, claim_type)
        }

        /// Mark a claim as completed
        fn set_claimed(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            claim_type: EntryFeeClaimType,
        ) {
            EntryFeeStoreTrait::set_claimed(ref self, context_id, claim_type);
        }

        // --- Extension helpers ---

        /// Get extension address for a context (zero = no extension configured).
        fn get_extension_address(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> ContractAddress {
            EntryFeeStoreTrait::get_extension(self, context_id)
        }
    }

    #[generate_trait]
    pub impl EntryFeeInitializerImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of EntryFeeInitializerTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IENTRY_FEE_ID);
        }
    }
}
