
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
    fn complete_objective(ref self: TContractState, token_id: u64, objective_id: u32);
    fn get_objective_ids(self: @TContractState, token_id: u64) -> Span<u32>;
}

#[starknet::contract]
pub mod MockObjectivesContract {
    use game_components_minigame::extensions::objectives::interface::{
        IMinigameObjectives, IMinigameObjectivesDetails, IMinigameObjectivesSVG,
        IMINIGAME_OBJECTIVES_ID,
    };
    use game_components_minigame::extensions::objectives::structs::GameObjective;
    use super::ObjectiveDetails;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

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
        token_objectives: Map<(u64, u32), bool> // (token_id, objective_id) => completed
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
    }

    // Objectives implementation
    #[abi(embed_v0)]
    impl ObjectivesImpl of IMinigameObjectives<ContractState> {
        fn objective_exists(self: @ContractState, objective_id: u32) -> bool {
            self.objective_exists.read(objective_id)
        }

        fn completed_objective(self: @ContractState, token_id: u64, objective_id: u32) -> bool {
            self.token_objectives.read((token_id, objective_id))
        }
    }

    #[abi(embed_v0)]
    impl ObjectivesDetailsImpl of IMinigameObjectivesDetails<ContractState> {
        fn objectives_details(self: @ContractState, token_id: u64) -> Span<GameObjective> {
            // Return mock objectives for the token
            let mut objectives_list = array![];

            // Add some default objectives - convert from ObjectiveDetails to GameObjective
            let obj1 = self.objective_details.read(1);
            if self.completed_objective(token_id, 1) {
                objectives_list
                    .append(GameObjective { name: obj1.name.clone(), value: "completed" });
            } else {
                objectives_list.append(GameObjective { name: obj1.name.clone(), value: "pending" });
            }

            let obj2 = self.objective_details.read(2);
            if self.completed_objective(token_id, 2) {
                objectives_list
                    .append(GameObjective { name: obj2.name.clone(), value: "completed" });
            } else {
                objectives_list.append(GameObjective { name: obj2.name.clone(), value: "pending" });
            }

            let obj3 = self.objective_details.read(3);
            if self.completed_objective(token_id, 3) {
                objectives_list
                    .append(GameObjective { name: obj3.name.clone(), value: "completed" });
            } else {
                objectives_list.append(GameObjective { name: obj3.name.clone(), value: "pending" });
            }

            objectives_list.span()
        }
    }

    #[abi(embed_v0)]
    impl ObjectivesSVGImpl of IMinigameObjectivesSVG<ContractState> {
        fn objectives_svg(self: @ContractState, token_id: u64) -> ByteArray {
            format!("<svg><text>Objectives for token {}</text></svg>", token_id)
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

        fn complete_objective(ref self: ContractState, token_id: u64, objective_id: u32) {
            self.token_objectives.write((token_id, objective_id), true);
        }

        fn get_objective_ids(self: @ContractState, token_id: u64) -> Span<u32> {
            // Return IDs of objectives for this token
            array![1_u32, 2_u32, 3_u32].span()
        }
    }
}
