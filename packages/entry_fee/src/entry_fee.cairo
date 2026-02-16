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
    use game_components_interfaces::entry_fee_extension::{
        IENTRY_FEE_EXTENSION_ID, IEntryFeeExtensionDispatcher, IEntryFeeExtensionDispatcherTrait,
    };
    use game_components_interfaces::extension::ExtensionConfig;
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::models::{
        AdditionalShare, EntryFee, EntryFeeClaimType, EntryFeeConfig, EntryFeeData,
        EntryFeeDataStorePacking, EntryFeeDeposit, PackedAdditionalShares,
        PackedAdditionalSharesImpl, PackedAdditionalSharesTrait, SHARES_PER_SLOT,
        StoredAdditionalShare,
    };

    #[storage]
    pub struct Storage {
        /// Entry fee token address keyed by context_id
        EntryFee_token: Map<u64, ContractAddress>,
        /// Packed entry fee data keyed by context_id
        /// Contains: amount, game_creator_share, refund_share, game_creator_claimed,
        /// additional_count
        EntryFee_data: Map<u64, EntryFeeData>,
        /// Additional share recipients per context: (context_id, index) -> recipient
        /// Recipients must be stored separately as ContractAddress is 251 bits
        EntryFee_additional_recipient: Map<(u64, u8), ContractAddress>,
        /// Packed additional shares per context: (context_id, slot_index) -> PackedAdditionalShares
        /// Each slot packs up to 16 shares (15 bits each = 240 bits per felt252)
        /// slot_index = share_index / 16
        EntryFee_additional_shares_packed: Map<(u64, u8), PackedAdditionalShares>,
        /// Refund claimed: (context_id, token_id) -> claimed
        EntryFee_refund_claimed: Map<(u64, u64), bool>,
        /// Extension address for extension-enhanced entry fees
        EntryFee_extension_address: Map<u64, ContractAddress>,
        /// Extension config data (stored as Vec)
        EntryFee_extension_config: Map<u64, Vec<felt252>>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(EntryFeeImpl)]
    impl EntryFeeComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IEntryFee<ComponentState<TContractState>> {
        fn get_entry_fee(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Option<EntryFeeConfig> {
            self._get_entry_fee(context_id)
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
            let token_address = self.EntryFee_token.entry(context_id).read();

            // If token address is zero, no entry fee is set
            if token_address.is_zero() {
                return Option::None;
            }

            let data = self.EntryFee_data.entry(context_id).read();
            let additional_shares = self._get_additional_shares(context_id);

            // Convert stored shares back to Option<u16>
            // 0 means None
            let game_creator_share = if data.game_creator_share == 0 {
                Option::None
            } else {
                Option::Some(data.game_creator_share)
            };

            let refund_share = if data.refund_share == 0 {
                Option::None
            } else {
                Option::Some(data.refund_share)
            };

            Option::Some(
                EntryFeeConfig {
                    token_address,
                    amount: data.amount,
                    game_creator_share,
                    refund_share,
                    additional_shares,
                },
            )
        }

        /// Get additional shares for a context
        /// Uses packed storage: reads 1 slot per 16 shares instead of 1 slot per share
        fn _get_additional_shares(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Span<AdditionalShare> {
            let data = self.EntryFee_data.entry(context_id).read();
            let count = data.additional_count;
            if count == 0 {
                return array![].span();
            }

            let mut shares: Array<AdditionalShare> = ArrayTrait::new();
            let mut current_slot: u8 = 0;
            let mut packed_shares: PackedAdditionalShares = PackedAdditionalSharesImpl::new();

            let mut i: u8 = 0;
            while i < count {
                let slot_index: u8 = i / SHARES_PER_SLOT;
                let index_in_slot: u8 = i % SHARES_PER_SLOT;

                // Load new slot if needed
                if slot_index != current_slot || i == 0 {
                    packed_shares = self
                        .EntryFee_additional_shares_packed
                        .entry((context_id, slot_index))
                        .read();
                    current_slot = slot_index;
                }

                let recipient = self.EntryFee_additional_recipient.entry((context_id, i)).read();
                let stored = packed_shares.get_share(index_in_slot);
                shares.append(AdditionalShare { recipient, share_bps: stored.share_bps });
                i += 1;
            }

            shares.span()
        }

        /// Set entry fee or extension for a context.
        /// Asserts that no entry fee has been previously set for this context.
        /// - EntryFee::Config: stores entry fee config, returns Some(EntryFeeConfig)
        /// - EntryFee::Extension: sets extension config, returns None
        fn set_entry_fee(
            ref self: ComponentState<TContractState>, context_id: u64, entry_fee: EntryFee,
        ) -> Option<EntryFeeConfig> {
            // Assert entry fee has not already been set (either config or extension)
            let token = self.EntryFee_token.entry(context_id).read();
            let ext = self.EntryFee_extension_address.entry(context_id).read();
            assert!(
                token.is_zero() && ext.is_zero(),
                "EntryFee: Entry fee already set for context {}",
                context_id,
            );

            match entry_fee {
                EntryFee::Config(config) => {
                    self._set_entry_fee_config(context_id, @config);
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
            // Store token address
            self.EntryFee_token.entry(context_id).write(*config.token_address);

            // Convert Option<u16> to stored values
            let game_creator_share: u16 = match config.game_creator_share {
                Option::Some(share) => *share,
                Option::None => 0,
            };

            let refund_share: u16 = match config.refund_share {
                Option::Some(share) => *share,
                Option::None => 0,
            };

            // Get additional shares count
            let additional_shares = *config.additional_shares;
            let additional_count: u8 = additional_shares.len().try_into().unwrap();

            // Store packed data (game_creator_claimed starts as false)
            let data = EntryFeeData {
                amount: *config.amount,
                game_creator_share,
                refund_share,
                game_creator_claimed: false,
                additional_count,
            };
            self.EntryFee_data.entry(context_id).write(data);

            // Store additional shares using packed storage
            let mut current_slot: u8 = 0;
            let mut packed_shares: PackedAdditionalShares = PackedAdditionalSharesImpl::new();

            let mut i: u32 = 0;
            while i < additional_shares.len() {
                let idx: u8 = i.try_into().unwrap();
                let slot_index: u8 = idx / SHARES_PER_SLOT;
                let index_in_slot: u8 = idx % SHARES_PER_SLOT;

                // If we moved to a new slot, write the previous one and start fresh
                if slot_index != current_slot && i > 0 {
                    self
                        .EntryFee_additional_shares_packed
                        .entry((context_id, current_slot))
                        .write(packed_shares);
                    packed_shares = PackedAdditionalSharesImpl::new();
                    current_slot = slot_index;
                }

                let share = *additional_shares.at(i);
                // Store recipient separately (ContractAddress is 251 bits, can't pack)
                self.EntryFee_additional_recipient.entry((context_id, idx)).write(share.recipient);
                // Pack share data into current slot
                let stored = StoredAdditionalShare { share_bps: share.share_bps, claimed: false };
                packed_shares.set_share(index_in_slot, stored);
                i += 1;
            }

            // Write the last slot if we have any shares
            if additional_count > 0 {
                self
                    .EntryFee_additional_shares_packed
                    .entry((context_id, current_slot))
                    .write(packed_shares);
            }
        }

        /// Internal: store extension config and notify extension contract
        fn _set_extension(
            ref self: ComponentState<TContractState>, context_id: u64, ext: ExtensionConfig,
        ) {
            self.EntryFee_extension_address.entry(context_id).write(ext.address);
            self.write_extension_config(context_id, ext.config);

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
                    erc20_dispatcher
                        .transfer_from(
                            get_caller_address(), get_contract_address(), config.amount.into(),
                        );
                },
                EntryFeeDeposit::Extension(pay_params) => {
                    let extension_address = self
                        .EntryFee_extension_address
                        .entry(context_id)
                        .read();
                    assert!(!extension_address.is_zero(), "EntryFee: No extension configured");
                    let dispatcher = IEntryFeeExtensionDispatcher {
                        contract_address: extension_address,
                    };
                    dispatcher.pay_entry_fee(context_id, pay_params);
                },
            }
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
                erc20_dispatcher.transfer(recipient, amount.into());
            }
        }

        /// Check if a claim has been made
        fn is_claimed(
            self: @ComponentState<TContractState>, context_id: u64, claim_type: EntryFeeClaimType,
        ) -> bool {
            match claim_type {
                EntryFeeClaimType::GameCreator => {
                    let data = self.EntryFee_data.entry(context_id).read();
                    data.game_creator_claimed
                },
                EntryFeeClaimType::Refund(token_id) => {
                    self.EntryFee_refund_claimed.entry((context_id, token_id)).read()
                },
                EntryFeeClaimType::AdditionalShare(index) => {
                    let slot_index: u8 = index / SHARES_PER_SLOT;
                    let index_in_slot: u8 = index % SHARES_PER_SLOT;
                    let packed = self
                        .EntryFee_additional_shares_packed
                        .entry((context_id, slot_index))
                        .read();
                    let stored = packed.get_share(index_in_slot);
                    stored.claimed
                },
            }
        }

        /// Mark a claim as completed
        fn set_claimed(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            claim_type: EntryFeeClaimType,
        ) {
            match claim_type {
                EntryFeeClaimType::GameCreator => {
                    // Read current data, update game_creator_claimed, write back
                    let mut data = self.EntryFee_data.entry(context_id).read();
                    data.game_creator_claimed = true;
                    self.EntryFee_data.entry(context_id).write(data);
                },
                EntryFeeClaimType::Refund(token_id) => {
                    self.EntryFee_refund_claimed.entry((context_id, token_id)).write(true);
                },
                EntryFeeClaimType::AdditionalShare(index) => {
                    // Read packed slot, update the specific share's claimed bit, write back
                    let slot_index: u8 = index / SHARES_PER_SLOT;
                    let index_in_slot: u8 = index % SHARES_PER_SLOT;
                    let mut packed = self
                        .EntryFee_additional_shares_packed
                        .entry((context_id, slot_index))
                        .read();
                    let mut stored = packed.get_share(index_in_slot);
                    stored.claimed = true;
                    packed.set_share(index_in_slot, stored);
                    self
                        .EntryFee_additional_shares_packed
                        .entry((context_id, slot_index))
                        .write(packed);
                },
            }
        }

        // --- Extension helpers ---

        /// Read extension config for a context
        fn read_extension_config(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Span<felt252> {
            let vec = self.EntryFee_extension_config.entry(context_id);
            let mut arr = ArrayTrait::new();
            let len = vec.len();
            let mut i: u64 = 0;
            loop {
                if i >= len {
                    break;
                }
                arr.append(vec.at(i).read());
                i += 1;
            }
            arr.span()
        }

        /// Write extension config for a context
        fn write_extension_config(
            ref self: ComponentState<TContractState>, context_id: u64, config: Span<felt252>,
        ) {
            let mut vec = self.EntryFee_extension_config.entry(context_id);
            let mut i: u32 = 0;
            loop {
                if i >= config.len() {
                    break;
                }
                vec.push(*config.at(i));
                i += 1;
            };
        }

        /// Get extension address for a context
        fn get_extension_address(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> ContractAddress {
            self.EntryFee_extension_address.entry(context_id).read()
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
