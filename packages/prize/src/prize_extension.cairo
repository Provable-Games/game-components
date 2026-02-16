/// PrizeExtensionComponent provides extensible prize logic for any context.
/// This component allows external contracts to implement custom prize addition
/// and claim hooks.

#[starknet::component]
pub mod PrizeExtensionComponent {
    use game_components_interfaces::prize_extension::{IPRIZE_EXTENSION_ID, IPrizeExtension};
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
    /// This trait defines the prize logic that each extension implements.
    pub trait PrizeExtension<TContractState> {
        /// Add a prize configuration for a context
        fn add_prize(ref self: TContractState, context_id: u64, config: Span<felt252>);

        /// Claim a prize for a context
        fn claim_prize(ref self: TContractState, context_id: u64, claim_params: Span<felt252>);
    }

    #[embeddable_as(PrizeExtensionImpl)]
    impl PrizeExtensionComponentImpl<
        TContractState,
        +HasComponent<TContractState>,
        +PrizeExtension<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IPrizeExtension<ComponentState<TContractState>> {
        fn owner_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner_address.read()
        }

        fn add_prize(
            ref self: ComponentState<TContractState>, context_id: u64, config: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            PrizeExtension::add_prize(ref contract, context_id, config);
        }

        fn claim_prize(
            ref self: ComponentState<TContractState>, context_id: u64, claim_params: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            PrizeExtension::claim_prize(ref contract, context_id, claim_params);
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
            src5_component.register_interface(IPRIZE_EXTENSION_ID);
        }

        fn get_owner_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner_address.read()
        }

        fn assert_only_owner(self: @ComponentState<TContractState>) {
            assert!(
                get_caller_address() == self.owner_address.read(),
                "Prize Extension: Only owner can call",
            );
        }
    }
}
