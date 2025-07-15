use game_components_minigame::extensions::objectives::interface::{
    IMinigameObjectives, IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait,
    IMinigameObjectivesSVG, IMinigameObjectivesSVGDispatcher, IMinigameObjectivesSVGDispatcherTrait,
    IMINIGAME_OBJECTIVES_ID,
};
use game_components_minigame::extensions::objectives::structs::GameObjective;
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::{contract_address_const, get_caller_address};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use core::to_byte_array::FormatAsByteArray;

// Test-specific struct for objectives with additional fields
#[derive(Drop, Serde)]
pub struct ObjectiveDetails {
    pub objective_id: u32,
    pub points: u32,
    pub name: ByteArray,
    pub description: ByteArray,
    pub is_completed: bool,
    pub is_required: bool,
}

// Test contract that implements Objectives interfaces
#[starknet::contract]
mod MockObjectivesContract {
    use game_components_minigame::extensions::objectives::interface::{
        IMinigameObjectives, IMinigameObjectivesSVG, IMINIGAME_OBJECTIVES_ID,
    };
    use game_components_minigame::extensions::objectives::structs::GameObjective;
    use super::ObjectiveDetails;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::interface::ISRC5;
    use starknet::ContractAddress;
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
        self._create_objective(1, 10, "First Blood", "Get the first kill", true);
        self._create_objective(2, 20, "Double Kill", "Get two kills in a row", true);
        self._create_objective(3, 50, "Ace", "Eliminate entire enemy team", false);
        self._create_objective(100, 100, "Perfectionist", "Complete without taking damage", false);
    }

    fn _create_objective(
        ref self: ContractState,
        objective_id: u32,
        points: u32,
        name: ByteArray,
        description: ByteArray,
        is_required: bool,
    ) {
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

        fn objectives(self: @ContractState, token_id: u64) -> Span<GameObjective> {
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
        self._create_objective(objective_id, points, name, description, is_required);

        // Emit event
        self.emit(ObjectiveCreated { game_id, objective_id, points, name, description });
    }

    #[abi(embed_v0)]
    fn complete_objective(ref self: ContractState, token_id: u64, objective_id: u32) {
        self.token_objectives.write((token_id, objective_id), true);
    }

    #[abi(embed_v0)]
    fn get_objective_ids(self: @ContractState, token_id: u64) -> Span<u32> {
        // Return IDs of objectives for this token
        array![1_u32, 2_u32, 3_u32].span()
    }
}

// Test OBJ-U-01: Initialize objectives component
#[test]
fn test_initialize_objectives_component() {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    // Verify SRC5 interface is registered
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(
        src5_dispatcher.supports_interface(IMINIGAME_OBJECTIVES_ID),
        "Should support IMinigameObjectives",
    );
    assert!(
        src5_dispatcher.supports_interface(openzeppelin_introspection::interface::ISRC5_ID),
        "Should support ISRC5",
    );
}

// Test OBJ-U-02: Check objective_exists for valid ID
#[test]
fn test_objective_exists_valid_id() {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    assert!(objectives_dispatcher.objective_exists(1), "Objective 1 should exist");
    assert!(objectives_dispatcher.objective_exists(2), "Objective 2 should exist");
    assert!(objectives_dispatcher.objective_exists(3), "Objective 3 should exist");
    assert!(objectives_dispatcher.objective_exists(100), "Objective 100 should exist");
}

// Test OBJ-U-03: Check objective_exists for invalid ID
#[test]
fn test_objective_exists_invalid_id() {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    assert!(!objectives_dispatcher.objective_exists(999), "Objective 999 should not exist");
    assert!(!objectives_dispatcher.objective_exists(0), "Objective 0 should not exist");
    assert!(!objectives_dispatcher.objective_exists(50), "Objective 50 should not exist");
}

// Test OBJ-U-04: Check completed_objective
#[test]
fn test_completed_objective() {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Initially not completed
    assert!(!objectives_dispatcher.completed_objective(1, 1), "Should not be completed initially");

    // Complete the objective
    setter.complete_objective(1, 1);

    // Now should be completed
    assert!(objectives_dispatcher.completed_objective(1, 1), "Should be completed after marking");

    // Other objectives should still be incomplete
    assert!(
        !objectives_dispatcher.completed_objective(1, 2), "Objective 2 should not be completed",
    );
}

// Test OBJ-U-05: Get objectives for token
#[test]
fn test_get_objectives_for_token() {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Complete some objectives
    setter.complete_objective(10, 1);
    setter.complete_objective(10, 3);

    // Get objectives
    let objectives = objectives_dispatcher.objectives(10);

    assert!(objectives.len() == 3, "Should have 3 objectives");

    // Check first objective
    let obj1 = *objectives.at(0);
    assert!(obj1.name == "First Blood", "First objective name mismatch");
    assert!(obj1.value == "completed", "First objective should be completed");

    // Check second objective
    let obj2 = *objectives.at(1);
    assert!(obj2.name == "Double Kill", "Second objective name mismatch");
    assert!(obj2.value == "pending", "Second objective should not be completed");

    // Check third objective
    let obj3 = *objectives.at(2);
    assert!(obj3.name == "Ace", "Third objective name mismatch");
    assert!(obj3.value == "completed", "Third objective should be completed");
}

// Test OBJ-U-06: Create objective with valid data
#[test]
fn test_create_objective_valid_data() {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Create new objective
    setter
        .create_objective(
            1, // game_id
            200, // objective_id
            75, // points
            "Speed Run",
            "Complete level in under 60 seconds",
            false // not required
        );

    // Verify objective was created
    assert!(objectives_dispatcher.objective_exists(200), "New objective should exist");
}

// Test OBJ-U-07: Create duplicate objective ID
#[test]
#[should_panic(expected: ('Objective already exists',))]
fn test_create_duplicate_objective() {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let setter = IObjectivesSetterDispatcher { contract_address };

    // Try to create objective with existing ID
    setter
        .create_objective(
            1, // game_id
            1, // objective_id (already exists)
            50,
            "Duplicate",
            "This should fail",
            true,
        );
}

// Test OBJ-U-08: Get_objective_ids from token
#[test]
fn test_get_objective_ids() {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let setter = IObjectivesSetterDispatcher { contract_address };
    let objective_ids = setter.get_objective_ids(1);

    assert!(objective_ids.len() == 3, "Should have 3 objective IDs");
    assert!(*objective_ids.at(0) == 1, "First ID should be 1");
    assert!(*objective_ids.at(1) == 2, "Second ID should be 2");
    assert!(*objective_ids.at(2) == 3, "Third ID should be 3");
}

// Test OBJ-U-09: Objectives with 0 points
#[test]
fn test_objective_with_zero_points() {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Create objective with 0 points
    setter
        .create_objective(
            1, 300, 0, // 0 points
            "Participation Trophy", "Just for showing up", false,
        );

    assert!(objectives_dispatcher.objective_exists(300), "Zero-point objective should exist");
}

// Test OBJ-U-10: Objectives_svg implementation
#[test]
fn test_objectives_svg() {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let objectives_svg_dispatcher = IMinigameObjectivesSVGDispatcher { contract_address };

    let svg = objectives_svg_dispatcher.objectives_svg(42);
    assert!(svg == "<svg><text>Objectives for token 42</text></svg>", "SVG content mismatch");
}

// Helper interface for testing
#[starknet::interface]
trait IObjectivesSetter<TContractState> {
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
