#[starknet::component]
pub mod ObjectivesComponent {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    // use crate::token::TokenComponent;
    use crate::core::traits::OptionalObjectives;
    use crate::extensions::objectives::interface::{
        IMinigameTokenObjectives, TokenObjective, IMINIGAME_TOKEN_OBJECTIVES_ID,
    };
    use crate::examples::minigame_registry_contract::{
        IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
    };
    use crate::core::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
    use game_components_minigame::extensions::objectives::structs::GameObjective;
    use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
    use game_components_minigame::extensions::objectives::interface::{
        IMINIGAME_OBJECTIVES_ID, IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait,
    };
    use game_components_utils::json::create_objectives_json;
    use crate::libs::objectives_logic;

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

    use crate::interface::{ITokenEventRelayerDispatcher, ITokenEventRelayerDispatcherTrait};

    #[storage]
    pub struct Storage {
        token_objectives: Map<u64, Map<u32, TokenObjective>>,
        token_objectives_count: Map<u64, u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ObjectiveSet: ObjectiveSet,
        ObjectiveCompleted: ObjectiveCompleted,
        ObjectiveCreated: ObjectiveCreated,
        AllObjectivesCompleted: AllObjectivesCompleted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ObjectiveSet {
        token_id: u64,
        objective_id: u32,
        game_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ObjectiveCompleted {
        token_id: u64,
        objective_id: u32,
        completion_timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ObjectiveCreated {
        pub game_address: ContractAddress,
        pub objective_id: u32,
        pub objective_data: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AllObjectivesCompleted {
        pub token_id: u64,
    }

    #[embeddable_as(ObjectivesImpl)]
    pub impl Objectives<
        TContractState,
        +HasComponent<TContractState>, // impl Token: TokenComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameTokenObjectives<ComponentState<TContractState>> {
        fn objectives(
            self: @ComponentState<TContractState>, token_id: u64,
        ) -> Array<TokenObjective> {
            let mut objectives = ArrayTrait::new();
            let count = self.token_objectives_count.entry(token_id).read();

            let mut i = 0;
            while i < count {
                let objective = self.token_objectives.entry(token_id).entry(i).read();
                objectives.append(objective);
                i += 1;
            };

            objectives
        }

        fn objective_ids(self: @ComponentState<TContractState>, token_id: u64) -> Span<u32> {
            let count = self.token_objectives_count.entry(token_id).read();
            let mut objective_ids = ArrayTrait::new();

            let mut i = 0;
            while i < count {
                let objective = self.token_objectives.entry(token_id).entry(i).read();
                objective_ids.append(objective.objective_id);
                i += 1;
            };

            objective_ids.span()
        }

        fn all_objectives_completed(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            // Inline the get_objectives_array logic
            let total_count = self.token_objectives_count.entry(token_id).read();
            let mut objectives = array![];
            let mut index = 0;

            while index < total_count {
                let objective = self.token_objectives.entry(token_id).entry(index).read();
                objectives.append(objective);
                index += 1;
            };

            objectives_logic::are_all_objectives_completed(objectives.span())
        }

        fn create_objective(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            creator_address: ContractAddress,
            objective_id: u32,
            objective_data: GameObjective,
        ) {
            // Check caller is objectives address
            let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
            let objectives_address = minigame_dispatcher.objectives_address();
            let objectives_address_display: felt252 = objectives_address.into();
            assert!(
                objectives_address == get_caller_address(),
                "MinigameTokenObjectives: Objectives address {} not registered by caller",
                objectives_address_display,
            );

            // Check game address is supported
            let minigame_token_dispatcher = IMinigameTokenDispatcher {
                contract_address: get_contract_address(),
            };
            let is_single_game = game_address == minigame_token_dispatcher.game_address();
            let game_registry_address = minigame_token_dispatcher.game_registry_address();
            let game_registry_dispatcher = IMinigameRegistryDispatcher {
                contract_address: game_registry_address,
            };
            let game_id = game_registry_dispatcher.game_id_from_address(game_address);
            let is_multi_game = game_id != 0;
            let game_address_display: felt252 = game_address.into();
            assert!(
                is_single_game || is_multi_game,
                "MinigameTokenObjectives: Game address {} not supported",
                game_address_display,
            );

            let objective_data_json = create_objectives_json(array![objective_data].span());
            self
                .emit(
                    ObjectiveCreated {
                        game_address, objective_id, objective_data: objective_data_json.clone(),
                    },
                );
            let event_relayer_address = minigame_token_dispatcher.event_relayer_address();
            if !event_relayer_address.is_zero() {
                let event_relayer_dispatcher = ITokenEventRelayerDispatcher {
                    contract_address: event_relayer_address,
                };
                event_relayer_dispatcher
                    .emit_objective_created(
                        game_address, creator_address, objective_id, objective_data_json.clone(),
                    );
            }
        }
    }

    // Implementation of the OptionalObjectives trait for integration with CoreTokenComponent
    pub impl ObjectivesOptionalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of OptionalObjectives<TContractState> {
        fn validate_objectives(
            self: @TContractState, game_address: ContractAddress, objective_ids: Span<u32>,
        ) -> (u32, Span<u32>) {
            let objectives_component = HasComponent::get_component(self);
            let mut src5_component = get_dep_component!(objectives_component, SRC5);
            let supports_objectives = src5_component
                .supports_interface(IMINIGAME_TOKEN_OBJECTIVES_ID);
            assert!(
                supports_objectives,
                "MinigameToken: Contract does not support IMinigameTokenObjectives",
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
                    "CoreToken: Objectives contract does not support IMinigameObjectives interface",
                );

                // Validate all objectives exist
                let objectives_dispatcher = IMinigameObjectivesDispatcher {
                    contract_address: objectives_address,
                };
                let mut index = 0;
                loop {
                    if index >= objective_ids.len() {
                        break;
                    }
                    let objective_id = *objective_ids.at(index);
                    assert!(
                        objectives_dispatcher.objective_exists(objective_id),
                        "MinigameTokenObjectives: Objective ID does not exist",
                    );
                    index += 1;
                }
            }

            (objective_ids.len().try_into().unwrap(), objective_ids)
        }

        fn set_token_objectives(
            ref self: TContractState,
            token_id: u64,
            objective_ids: Span<u32>,
            event_relayer: Option<ITokenEventRelayerDispatcher>,
        ) {
            let mut component = HasComponent::get_component_mut(ref self);
            let mut i = 0;
            while i < objective_ids.len() {
                let objective_id = *objective_ids.at(i);
                let _objective = TokenObjective { objective_id, completed: false };

                component.token_objectives.entry(token_id).entry(i).write(_objective);

                component
                    .emit(
                        ObjectiveSet {
                            token_id,
                            objective_id,
                            game_address: starknet::contract_address_const::<0>(),
                        },
                    );

                if let Option::Some(event_relayer) = event_relayer {
                    event_relayer.emit_objective_update(token_id, objective_id, false);
                }

                i += 1;
            };

            component.token_objectives_count.entry(token_id).write(objective_ids.len());
        }

        fn update_objectives(
            ref self: TContractState,
            token_id: u64,
            game_address: ContractAddress,
            objectives_count: u32,
            event_relayer: Option<ITokenEventRelayerDispatcher>,
        ) -> bool {
            let mut component = HasComponent::get_component_mut(ref self);
            let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
            let objectives_address = minigame_dispatcher.objectives_address();
            let game_objectives_dispatcher = IMinigameObjectivesDispatcher {
                contract_address: objectives_address,
            };
            let total_count = objectives_count;
            let mut index = 0;
            let mut completed_count = 0;

            while index < total_count {
                let objective: TokenObjective = component
                    .token_objectives
                    .entry(token_id)
                    .entry(index)
                    .read();
                let is_objective_completed = game_objectives_dispatcher
                    .completed_objective(token_id, objective.objective_id);
                if is_objective_completed && !objective.completed {
                    component
                        .token_objectives
                        .entry(token_id)
                        .entry(index)
                        .write(
                            TokenObjective {
                                objective_id: objective.objective_id, completed: true,
                            },
                        );
                    component
                        .emit(
                            ObjectiveCompleted {
                                token_id,
                                objective_id: objective.objective_id,
                                completion_timestamp: get_block_timestamp(),
                            },
                        );

                    if let Option::Some(event_relayer) = event_relayer {
                        event_relayer.emit_objective_update(token_id, objective.objective_id, true);
                    }

                    completed_count += 1;
                }
                index += 1;
            };
            completed_count == total_count
        }

        fn are_objectives_completed(self: @TContractState, token_id: u64) -> bool {
            let component = HasComponent::get_component(self);
            let objectives = component.get_objectives_array(token_id);
            objectives_logic::are_all_objectives_completed(objectives.span())
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

        fn set_objective(
            ref self: ComponentState<TContractState>,
            token_id: u64,
            objective_index: u32,
            objective: TokenObjective,
        ) {
            self.token_objectives.entry(token_id).entry(objective_index).write(objective);
        }

        fn get_objectives_array(
            self: @ComponentState<TContractState>, token_id: u64,
        ) -> Array<TokenObjective> {
            let total_count = self.token_objectives_count.entry(token_id).read();
            let mut objectives = array![];
            let mut index = 0;

            while index < total_count {
                let objective = self.token_objectives.entry(token_id).entry(index).read();
                objectives.append(objective);
                index += 1;
            };

            objectives
        }
    }
}
