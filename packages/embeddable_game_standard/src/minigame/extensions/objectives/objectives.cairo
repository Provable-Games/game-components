//
// Objectives Component
//
#[starknet::component]
pub mod ObjectivesComponent {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::minigame::extensions::objectives::interface::{
        IMINIGAME_OBJECTIVES_ID, IMinigameObjectives,
    };
    use crate::minigame::extensions::objectives::libs;
    use crate::minigame::extensions::objectives::structs::GameObjectiveDetails;

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

        fn register_objectives_interface(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_OBJECTIVES_ID);
        }

        fn create_objective(
            self: @ComponentState<TContractState>,
            objective_id: u32,
            settings_id: u32,
            objective_details: GameObjectiveDetails,
            minigame_token_address: ContractAddress,
        ) {
            libs::create_objective(
                minigame_token_address,
                get_contract_address(),
                get_caller_address(),
                objective_id,
                settings_id,
                objective_details,
            );
        }
    }
}
