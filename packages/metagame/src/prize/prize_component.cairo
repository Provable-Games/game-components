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
    use interfaces::extension::ExtensionConfig;
    use interfaces::prize_extension::{
        IPRIZE_EXTENSION_ID, IPrizeExtensionDispatcher, IPrizeExtensionDispatcherTrait,
    };
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::prize::prize::prize::hash_prize_type;
    use crate::prize::prize_store::{PrizeStoreImpl, PrizeStoreTrait};
    use crate::prize::store::Store;
    use crate::prize::structs::{
        CustomShares, Prize, PrizeConfig, PrizeData, PrizeType, StoredPrize, TokenTypeData,
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
        /// Extension address keyed by (context_id, prize_id)
        Prize_extension_address: Map<(u64, u64), ContractAddress>,
        /// Extension config data keyed by (context_id, prize_id)
        Prize_extension_config: Map<(u64, u64), Vec<felt252>>,
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

        fn get_extension_config_len(
            self: @ComponentState<TContractState>, context_id: u64, prize_id: u64,
        ) -> u64 {
            self.Prize_extension_config.entry((context_id, prize_id)).len()
        }

        fn get_extension_config_at(
            self: @ComponentState<TContractState>, context_id: u64, prize_id: u64, index: u64,
        ) -> felt252 {
            self.Prize_extension_config.entry((context_id, prize_id)).at(index).read()
        }

        fn push_extension_config(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            value: felt252,
        ) {
            self.Prize_extension_config.entry((context_id, prize_id)).push(value);
        }
    }

    #[embeddable_as(PrizeImpl)]
    impl PrizeComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IPrize<ComponentState<TContractState>> {
        fn get_prize(self: @ComponentState<TContractState>, prize_id: u64) -> PrizeData {
            PrizeStoreTrait::get_prize(self, prize_id)
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
        /// Get a prize by its ID
        /// The PrizeData struct is unpacked from storage and the id field is set
        fn _get_prize(self: @ComponentState<TContractState>, prize_id: u64) -> PrizeData {
            PrizeStoreTrait::get_prize(self, prize_id)
        }

        /// Get custom shares for a prize (used for Custom distribution)
        /// Uses packed storage: reads 1 slot per 15 shares instead of 1 slot per share
        fn _get_custom_shares(self: @ComponentState<TContractState>, prize_id: u64) -> Array<u16> {
            PrizeStoreTrait::get_custom_shares(self, prize_id)
        }

        /// Store a prize (converts to StoredPrize for storage)
        fn set_prize(ref self: ComponentState<TContractState>, prize_id: u64, prize: PrizeData) {
            PrizeStoreTrait::set_prize(ref self, prize_id, prize);
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
        /// - Prize::Config: deposits tokens, stores prize data
        /// - Prize::Extension: increments prize count and delegates to extension
        fn add_prize(
            ref self: ComponentState<TContractState>, context_id: u64, prize: Prize,
        ) -> u64 {
            match prize {
                Prize::Config(config) => { self._add_prize_config(context_id, config) },
                Prize::Extension(ext) => {
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

        /// Internal: deposit tokens, store prize data, return prize_id
        fn _add_prize_config(
            ref self: ComponentState<TContractState>, context_id: u64, config: PrizeConfig,
        ) -> u64 {
            let token_address = config.token_address;
            let token_type = config.token_type;

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

            // Create the prize data (StorePacking handles the packing in storage)
            let sponsor = get_caller_address();
            let prize_data = PrizeData {
                id, context_id, token_address, token_type, sponsor_address: sponsor,
            };

            // Store the prize data
            PrizeStoreTrait::set_prize(ref self, id, prize_data);

            id
        }

        /// Internal: store extension config and notify extension contract
        fn _set_extension(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            ext: ExtensionConfig,
        ) {
            Store::set_extension_address(ref self, context_id, prize_id, ext.address);
            PrizeStoreTrait::write_extension_config(ref self, context_id, prize_id, ext.config);

            let dispatcher = IPrizeExtensionDispatcher { contract_address: ext.address };
            dispatcher.add_prize(context_id, prize_id, ext.config);
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
            let prize = PrizeStoreTrait::get_prize(@self, prize_id);
            let erc20 = IERC20Dispatcher { contract_address: prize.token_address };
            assert!(
                erc20.transfer(prize.sponsor_address, amount.into()),
                "Prize: ERC20 refund transfer failed",
            );
        }

        /// Refund ERC721 prize to the original sponsor
        fn refund_prize_erc721(
            ref self: ComponentState<TContractState>, prize_id: u64, token_id: u128,
        ) {
            let prize = PrizeStoreTrait::get_prize(@self, prize_id);
            let erc721 = IERC721Dispatcher { contract_address: prize.token_address };
            erc721.transfer_from(get_contract_address(), prize.sponsor_address, token_id.into());
        }

        // --- Extension helpers ---

        /// Read extension config for a context and prize
        fn read_extension_config(
            self: @ComponentState<TContractState>, context_id: u64, prize_id: u64,
        ) -> Span<felt252> {
            PrizeStoreTrait::read_extension_config(self, context_id, prize_id)
        }

        /// Write extension config for a context and prize
        fn write_extension_config(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            config: Span<felt252>,
        ) {
            PrizeStoreTrait::write_extension_config(ref self, context_id, prize_id, config);
        }

        /// Get extension address for a context and prize
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
