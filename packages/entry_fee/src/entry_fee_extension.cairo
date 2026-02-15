/// EntryFeeExtensionComponent provides extensible entry fee logic for any context.
/// This component allows external contracts to implement custom fee calculation,
/// deposit validation, and claim/refund lifecycle hooks.

#[starknet::component]
pub mod EntryFeeExtensionComponent {
    use game_components_interfaces::entry_fee_extension::{
        IENTRY_FEE_EXTENSION_ID, IEntryFeeExtension,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        owner_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    /// Internal trait that implementors must provide.
    /// This trait defines the fee logic that each extension implements.
    pub trait EntryFeeExtension<TContractState> {
        /// Calculate the actual fee amount for a player (allows dynamic pricing)
        fn calculate_fee(
            self: @TContractState,
            context_id: u64,
            base_amount: u128,
            player: ContractAddress,
            config: Span<felt252>,
        ) -> u128;

        /// Validate whether a deposit should be accepted
        fn validate_deposit(
            self: @TContractState,
            context_id: u64,
            player: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        ) -> bool;

        /// Called after a deposit is processed
        fn on_deposit(
            ref self: TContractState,
            context_id: u64,
            token_address: ContractAddress,
            amount: u128,
            player: ContractAddress,
            config: Span<felt252>,
        );

        /// Called when a claim is processed
        fn on_claim(
            ref self: TContractState,
            context_id: u64,
            claim_type: Span<felt252>,
            claimer: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        );

        /// Called when a refund is processed
        fn on_refund(
            ref self: TContractState,
            context_id: u64,
            recipient: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        );

        /// Add configuration for a context
        fn add_config(ref self: TContractState, context_id: u64, config: Span<felt252>);
    }

    #[embeddable_as(EntryFeeExtensionImpl)]
    impl EntryFeeExtensionComponentImpl<
        TContractState,
        +HasComponent<TContractState>,
        +EntryFeeExtension<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IEntryFeeExtension<ComponentState<TContractState>> {
        fn owner_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner_address.read()
        }

        fn calculate_fee(
            self: @ComponentState<TContractState>,
            context_id: u64,
            base_amount: u128,
            player: ContractAddress,
            config: Span<felt252>,
        ) -> u128 {
            let contract = self.get_contract();
            EntryFeeExtension::calculate_fee(contract, context_id, base_amount, player, config)
        }

        fn validate_deposit(
            self: @ComponentState<TContractState>,
            context_id: u64,
            player: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        ) -> bool {
            let contract = self.get_contract();
            EntryFeeExtension::validate_deposit(contract, context_id, player, amount, config)
        }

        fn on_deposit(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            token_address: ContractAddress,
            amount: u128,
            player: ContractAddress,
            config: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            EntryFeeExtension::on_deposit(
                ref contract, context_id, token_address, amount, player, config,
            );
        }

        fn on_claim(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            claim_type: Span<felt252>,
            claimer: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            EntryFeeExtension::on_claim(
                ref contract, context_id, claim_type, claimer, amount, config,
            );
        }

        fn on_refund(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            recipient: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            EntryFeeExtension::on_refund(ref contract, context_id, recipient, amount, config);
        }

        fn add_config(
            ref self: ComponentState<TContractState>, context_id: u64, config: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            EntryFeeExtension::add_config(ref contract, context_id, config);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, owner_address: ContractAddress) {
            self.owner_address.write(owner_address);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IENTRY_FEE_EXTENSION_ID);
        }

        fn get_owner_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner_address.read()
        }

        fn assert_only_owner(self: @ComponentState<TContractState>) {
            assert!(
                get_caller_address() == self.owner_address.read(),
                "Entry Fee Extension: Only owner can call",
            );
        }
    }
}
