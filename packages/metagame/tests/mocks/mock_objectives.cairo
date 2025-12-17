use game_components_minigame::extensions::objectives::interface::{
    IMINIGAME_OBJECTIVES_ID, IMinigameObjectives, IMinigameObjectivesSVG,
};
use game_components_minigame::extensions::objectives::structs::GameObjective;
use openzeppelin_interfaces::introspection::ISRC5;

#[starknet::contract]
pub mod MockObjectives {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::*;

    #[storage]
    struct Storage {
        objectives_exists: Map<u32, bool>,
        token_objectives_completed: Map<(u64, u32), bool>,
        supports_objectives: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState, supports_objectives: bool) {
        self.supports_objectives.write(supports_objectives);
    }

    #[abi(embed_v0)]
    impl MinigameObjectivesImpl of IMinigameObjectives<ContractState> {
        fn objective_exists(self: @ContractState, objective_id: u32) -> bool {
            self.objectives_exists.read(objective_id)
        }

        fn completed_objective(self: @ContractState, token_id: u64, objective_id: u32) -> bool {
            self.token_objectives_completed.read((token_id, objective_id))
        }

        fn objectives(self: @ContractState, token_id: u64) -> Span<GameObjective> {
            // Return mock objectives for testing
            array![
                GameObjective { name: "Objective 1", value: "Complete level 1" },
                GameObjective { name: "Objective 2", value: "Collect 100 coins" },
                GameObjective { name: "Objective 3", value: "Defeat boss" },
            ]
                .span()
        }
    }

    #[abi(embed_v0)]
    impl MinigameObjectivesSVGImpl of IMinigameObjectivesSVG<ContractState> {
        fn objectives_svg(self: @ContractState, token_id: u64) -> ByteArray {
            "<svg>Test Objectives SVG</svg>"
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            if self.supports_objectives.read() {
                interface_id == IMINIGAME_OBJECTIVES_ID
                    || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
            } else {
                interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
            }
        }
    }

    // Helper functions for testing
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn add_objective(ref self: ContractState, objective_id: u32) {
            self.objectives_exists.write(objective_id, true);
        }

        fn set_objective_completed(
            ref self: ContractState, token_id: u64, objective_id: u32, completed: bool,
        ) {
            self.token_objectives_completed.write((token_id, objective_id), completed);
        }
    }
}
