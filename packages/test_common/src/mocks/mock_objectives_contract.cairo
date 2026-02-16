// Test-specific struct for objectives with additional fields
#[derive(Drop, Serde, starknet::Store)]
pub struct ObjectiveDetails {
    pub objective_id: u32,
    pub points: u32,
    pub name: ByteArray,
    pub description: ByteArray,
    pub is_completed: bool,
    pub is_required: bool,
}

#[starknet::interface]
pub trait IObjectivesSetter<TContractState> {
    fn create_objective(
        ref self: TContractState,
        game_id: u32,
        objective_id: u32,
        points: u32,
        name: ByteArray,
        description: ByteArray,
        is_required: bool,
    );
    fn complete_objective(ref self: TContractState, token_id: felt252, objective_id: u32);
    fn set_token_objective(ref self: TContractState, token_id: felt252, objective_id: u32);
    fn get_objective_id(self: @TContractState, token_id: felt252) -> u32;
}

#[starknet::contract]
pub mod MockObjectivesContract {
    use game_components_embeddable_game_standard::minigame::extensions::objectives::interface::{
        IMINIGAME_OBJECTIVES_ID, IMinigameObjectives, IMinigameObjectivesDetails,
        IMinigameObjectivesSVG,
    };
    use game_components_embeddable_game_standard::minigame::extensions::objectives::structs::{
        GameObjective, GameObjectiveDetails,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::ObjectiveDetails;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Storage for testing
        objective_exists: Map<u32, bool>,
        objective_details: Map<u32, ObjectiveDetails>,
        token_objectives: Map<(felt252, u32), bool>, // (token_id, objective_id) => completed
        token_objective_id: Map<felt252, u32>, // token_id => objective_id
        // Total number of objectives created
        total_objectives_count: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        ObjectiveCreated: ObjectiveCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct ObjectiveCreated {
        game_id: u32,
        objective_id: u32,
        points: u32,
        name: ByteArray,
        description: ByteArray,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Register SRC5 interface
        self.src5.register_interface(IMINIGAME_OBJECTIVES_ID);

        // Pre-populate some objectives for testing
        self.objective_exists.write(1, true);
        self
            .objective_details
            .write(
                1,
                ObjectiveDetails {
                    objective_id: 1,
                    points: 10,
                    name: "First Blood",
                    description: "Get the first kill",
                    is_completed: false,
                    is_required: true,
                },
            );

        self.objective_exists.write(2, true);
        self
            .objective_details
            .write(
                2,
                ObjectiveDetails {
                    objective_id: 2,
                    points: 20,
                    name: "Double Kill",
                    description: "Get two kills in a row",
                    is_completed: false,
                    is_required: true,
                },
            );

        self.objective_exists.write(3, true);
        self
            .objective_details
            .write(
                3,
                ObjectiveDetails {
                    objective_id: 3,
                    points: 50,
                    name: "Ace",
                    description: "Eliminate entire enemy team",
                    is_completed: false,
                    is_required: false,
                },
            );

        self.objective_exists.write(100, true);
        self
            .objective_details
            .write(
                100,
                ObjectiveDetails {
                    objective_id: 100,
                    points: 100,
                    name: "Perfectionist",
                    description: "Complete without taking damage",
                    is_completed: false,
                    is_required: false,
                },
            );

        // Set total objectives count (4 objectives: 1, 2, 3, 100)
        self.total_objectives_count.write(4);
    }

    // Objectives implementation
    #[abi(embed_v0)]
    impl ObjectivesImpl of IMinigameObjectives<ContractState> {
        fn objective_exists(self: @ContractState, objective_id: u32) -> bool {
            self.objective_exists.read(objective_id)
        }

        fn completed_objective(self: @ContractState, token_id: felt252, objective_id: u32) -> bool {
            self.token_objectives.read((token_id, objective_id))
        }

        fn objective_exists_batch(self: @ContractState, objective_ids: Span<u32>) -> Array<bool> {
            let mut results = array![];
            let mut index = 0;
            loop {
                if index >= objective_ids.len() {
                    break;
                }
                results.append(self.objective_exists(*objective_ids.at(index)));
                index += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl ObjectivesDetailsImpl of IMinigameObjectivesDetails<ContractState> {
        fn objectives_count(self: @ContractState) -> u32 {
            self.total_objectives_count.read()
        }

        fn objectives_details(self: @ContractState, objective_id: u32) -> GameObjectiveDetails {
            // Return mock objective details for the objective_id
            let obj = self.objective_details.read(objective_id);
            let objectives = array![
                GameObjective { name: "points", value: format!("{}", obj.points) },
                GameObjective {
                    name: "required", value: if obj.is_required {
                        "true"
                    } else {
                        "false"
                    },
                },
            ];

            GameObjectiveDetails {
                name: obj.name, description: obj.description, objectives: objectives.span(),
            }
        }

        fn objective_settings_id(self: @ContractState, objective_id: u32) -> u32 {
            0
        }

        fn objectives_details_batch(
            self: @ContractState, objective_ids: Span<u32>,
        ) -> Array<GameObjectiveDetails> {
            let mut results = array![];
            let mut index = 0;
            loop {
                if index >= objective_ids.len() {
                    break;
                }
                results.append(self.objectives_details(*objective_ids.at(index)));
                index += 1;
            }
            results
        }

        fn objective_settings_id_batch(
            self: @ContractState, objective_ids: Span<u32>,
        ) -> Array<u32> {
            let mut results = array![];
            let mut index = 0;
            loop {
                if index >= objective_ids.len() {
                    break;
                }
                results.append(self.objective_settings_id(*objective_ids.at(index)));
                index += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl ObjectivesSVGImpl of IMinigameObjectivesSVG<ContractState> {
        fn objectives_svg(self: @ContractState, objective_id: u32) -> ByteArray {
            format!("<svg><text>Objectives for objective {}</text></svg>", objective_id)
        }
    }

    // Helper functions for testing
    #[abi(embed_v0)]
    impl ObjectivesSetterImpl of super::IObjectivesSetter<ContractState> {
        fn create_objective(
            ref self: ContractState,
            game_id: u32,
            objective_id: u32,
            points: u32,
            name: ByteArray,
            description: ByteArray,
            is_required: bool,
        ) {
            assert!(!self.objective_exists.read(objective_id), "Objective already exists");

            self.objective_exists.write(objective_id, true);
            self
                .objective_details
                .write(
                    objective_id,
                    ObjectiveDetails {
                        objective_id,
                        points,
                        name: name.clone(),
                        description: description.clone(),
                        is_completed: false,
                        is_required,
                    },
                );

            // Emit event
            self
                .emit(
                    ObjectiveCreated {
                        game_id,
                        objective_id,
                        points,
                        name: name.clone(),
                        description: description.clone(),
                    },
                );
        }

        fn complete_objective(ref self: ContractState, token_id: felt252, objective_id: u32) {
            self.token_objectives.write((token_id, objective_id), true);
        }

        fn set_token_objective(ref self: ContractState, token_id: felt252, objective_id: u32) {
            self.token_objective_id.write(token_id, objective_id);
        }

        fn get_objective_id(self: @ContractState, token_id: felt252) -> u32 {
            self.token_objective_id.read(token_id)
        }
    }
}
