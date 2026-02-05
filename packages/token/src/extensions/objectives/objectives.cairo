#[starknet::component]
pub mod ObjectivesComponent {
    use core::num::traits::Zero;
    use game_components_minigame::extensions::objectives::interface::{
        IMINIGAME_OBJECTIVES_ID, IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait,
    };
    use game_components_minigame::extensions::objectives::structs::{
        GameObjective, GameObjectiveDetails,
    };
    use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::core::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
    use crate::core::traits::OptionalObjectives;
    use crate::extensions::objectives::interface::{
        IMINIGAME_TOKEN_OBJECTIVES_ID, IMinigameTokenObjectives,
    };
    use crate::interface::{IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait};

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ObjectiveCreated: ObjectiveCreated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ObjectiveCreated {
        #[key]
        pub game_address: ContractAddress,
        #[key]
        pub objective_id: u32,
        pub creator_address: ContractAddress,
        pub name: ByteArray,
        pub description: ByteArray,
        pub objectives: Span<GameObjective>,
    }

    #[embeddable_as(ObjectivesImpl)]
    pub impl Objectives<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IMinigameTokenObjectives<ComponentState<TContractState>> {
        fn create_objective(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            creator_address: ContractAddress,
            objective_id: u32,
            objective_details: GameObjectiveDetails,
        ) {
            // Check caller is objectives address
            let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
            let objectives_address = minigame_dispatcher.objectives_address();
            let objectives_address_display: felt252 = objectives_address.into();
            let caller = get_caller_address();
            assert!(
                objectives_address == caller,
                "MinigameTokenObjectives: Objectives address {} not registered by caller",
                objectives_address_display,
            );

            // Check game address is supported
            let minigame_token_dispatcher = IMinigameTokenDispatcher {
                contract_address: get_contract_address(),
            };
            let is_single_game = game_address == minigame_token_dispatcher.game_address();
            let mut is_multi_game = false;
            let game_registry_address = minigame_token_dispatcher.game_registry_address();
            if !game_registry_address.is_zero() {
                let game_registry_dispatcher = IMinigameRegistryDispatcher {
                    contract_address: game_registry_address,
                };
                let game_id = game_registry_dispatcher.game_id_from_address(game_address);
                is_multi_game = game_id != 0;
            }
            let game_address_display: felt252 = game_address.into();
            assert!(
                is_single_game || is_multi_game,
                "MinigameTokenObjectives: Game address {} not supported",
                game_address_display,
            );

            // Emit native event with struct fields directly
            self
                .emit(
                    ObjectiveCreated {
                        game_address,
                        objective_id,
                        creator_address,
                        name: objective_details.name,
                        description: objective_details.description,
                        objectives: objective_details.objectives,
                    },
                );
        }
    }

    // Implementation of the OptionalObjectives trait for integration with CoreTokenComponent
    pub impl ObjectivesOptionalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of OptionalObjectives<TContractState> {
        fn validate_objective(
            self: @TContractState, game_address: ContractAddress, objective_id: u32,
        ) {
            let objectives_component = HasComponent::get_component(self);
            let mut src5_component = get_dep_component!(objectives_component, SRC5);
            let supports_objectives = src5_component
                .supports_interface(IMINIGAME_TOKEN_OBJECTIVES_ID);
            assert!(
                supports_objectives,
                "MinigameTokenObjectives: Contract does not support objectives",
            );

            // Get objectives address from game
            let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
            let objectives_address = minigame_dispatcher.objectives_address();

            if !objectives_address.is_zero() {
                // Validate objectives contract supports interface
                let objectives_src5_dispatcher = ISRC5Dispatcher {
                    contract_address: objectives_address,
                };
                assert!(
                    objectives_src5_dispatcher.supports_interface(IMINIGAME_OBJECTIVES_ID),
                    "MinigameTokenObjectives: Objectives contract does not support IMinigameObjectives interface",
                );

                // Validate objective exists
                let objectives_dispatcher = IMinigameObjectivesDispatcher {
                    contract_address: objectives_address,
                };
                assert!(
                    objectives_dispatcher.objective_exists(objective_id),
                    "MinigameTokenObjectives: Objective ID {} does not exist",
                    objective_id,
                );
            }
        }

        fn is_objective_completed(
            self: @TContractState,
            game_address: ContractAddress,
            token_id: felt252,
            objective_id: u32,
        ) -> bool {
            // Get objectives address from game
            let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
            let objectives_address = minigame_dispatcher.objectives_address();

            if objectives_address.is_zero() {
                return false;
            }

            // Call back to minigame objectives to check completion
            let objectives_dispatcher = IMinigameObjectivesDispatcher {
                contract_address: objectives_address,
            };
            objectives_dispatcher.completed_objective(token_id, objective_id)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_TOKEN_OBJECTIVES_ID);
        }
    }
}
