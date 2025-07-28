//
// Objectives Component
//
#[starknet::component]
pub mod ObjectivesComponent {
    use crate::extensions::objectives::interface::{IMinigameObjectives, IMINIGAME_OBJECTIVES_ID};
    use crate::extensions::objectives::libs;
    use starknet::{ContractAddress, get_contract_address, get_caller_address};

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;

    #[storage]
    pub struct Storage {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +IMinigameObjectives<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            self.register_objectives_interface();
        }

        fn get_objective_ids(
            self: @ComponentState<TContractState>,
            token_id: u64,
            minigame_token_address: ContractAddress,
        ) -> Span<u32> {
            libs::get_objective_ids(minigame_token_address, token_id)
        }

        fn register_objectives_interface(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_OBJECTIVES_ID);
        }

        fn create_objective(
            self: @ComponentState<TContractState>,
            objective_id: u32,
            name: ByteArray,
            value: ByteArray,
            minigame_token_address: ContractAddress,
        ) {
            libs::create_objective(
                minigame_token_address,
                get_contract_address(),
                get_caller_address(),
                objective_id,
                name,
                value,
            );
        }
    }
}
