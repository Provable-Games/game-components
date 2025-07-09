#[starknet::contract]
pub mod MockObjectives {
    use game_components_minigame::extensions::objectives::interface::{IMinigameObjectives, IMINIGAME_OBJECTIVES_ID};
    use game_components_minigame::extensions::objectives::structs::Objective;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use openzeppelin_introspection::src5::{SRC5Component, SRC5Component::InternalTrait};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        objectives: Map<u32, Objective>,
        objectives_count: u32,
        token_objectives: Map<(u64, u32), bool>, // (token_id, objective_id) -> completed
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.src5.register_interface(IMINIGAME_OBJECTIVES_ID);
        // Pre-populate some test objectives
        self.objectives.write(1, Objective { 
            is_valid: true, 
            target: 100, 
            points: 10, 
            operator: 1 
        });
        self.objectives.write(2, Objective { 
            is_valid: true, 
            target: 200, 
            points: 20, 
            operator: 2 
        });
        self.objectives.write(3, Objective { 
            is_valid: true, 
            target: 300, 
            points: 30, 
            operator: 1 
        });
        self.objectives_count.write(3);
    }

    #[abi(embed_v0)]
    impl MinigameObjectivesImpl of IMinigameObjectives<ContractState> {
        fn objective(self: @ContractState, id: u32) -> Objective {
            self.objectives.read(id)
        }

        fn count(self: @ContractState) -> u32 {
            self.objectives_count.read()
        }

        fn is_complete(self: @ContractState, token_id: u64, objective_id: u32) -> bool {
            self.token_objectives.read((token_id, objective_id))
        }
    }

    #[external(v0)]
    fn add_objective(ref self: ContractState, id: u32, objective: Objective) {
        self.objectives.write(id, objective);
        if id > self.objectives_count.read() {
            self.objectives_count.write(id);
        }
    }

    #[external(v0)]
    fn set_objective_complete(ref self: ContractState, token_id: u64, objective_id: u32, complete: bool) {
        self.token_objectives.write((token_id, objective_id), complete);
    }
}