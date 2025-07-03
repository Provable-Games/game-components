use starknet::ContractAddress;
use game_components_minigame::extensions::objectives::interface::{IMinigameObjectives, IMinigameObjectivesSVG};
use game_components_minigame::extensions::objectives::structs::GameObjective;
use snforge_std::{start_mock_call, stop_mock_call, mock_call};

#[derive(Drop, Copy)]
pub struct MockObjectivesContract {
    pub contract_address: ContractAddress,
}

pub impl MockObjectivesContractImpl of MockObjectivesContractTrait {
    fn new(address: ContractAddress) -> MockObjectivesContract {
        MockObjectivesContract {
            contract_address: address,
        }
    }

    // IMinigameObjectives interface mocks
    fn mock_objective_exists(self: @MockObjectivesContract, objective_id: u32, exists: bool) {
        let selector = selector!("objective_exists");
        let mut calldata = array![];
        objective_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, exists);
    }

    fn mock_completed_objective(self: @MockObjectivesContract, token_id: u64, objective_id: u32, completed: bool) {
        let selector = selector!("completed_objective");
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        objective_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, completed);
    }

    fn mock_objectives(self: @MockObjectivesContract, token_id: u64, objectives: Span<GameObjective>) {
        let selector = selector!("objectives");
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, objectives);
    }

    // IMinigameObjectivesSVG interface mocks
    fn mock_objectives_svg(self: @MockObjectivesContract, token_id: u64, svg: ByteArray) {
        let selector = selector!("objectives_svg");
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, svg);
    }

    // Stop specific mock
    fn stop_objective_exists_mock(self: @MockObjectivesContract) {
        stop_mock_call(*self.contract_address, selector!("objective_exists"));
    }

    // Stop all mocks
    fn stop_all_mocks(self: @MockObjectivesContract) {
        stop_mock_call(*self.contract_address, selector!("objective_exists"));
        stop_mock_call(*self.contract_address, selector!("completed_objective"));
        stop_mock_call(*self.contract_address, selector!("objectives"));
        stop_mock_call(*self.contract_address, selector!("objectives_svg"));
    }

    // Helper to mock multiple objectives existence at once
    fn mock_objectives_exist(self: @MockObjectivesContract, objective_ids: Span<u32>, exists: bool) {
        let mut i = 0;
        loop {
            if i == objective_ids.len() {
                break;
            }
            self.mock_objective_exists(*objective_ids.at(i), exists);
            i += 1;
        };
    }

    // Helper to mock multiple objective completions at once
    fn mock_objective_completions(
        self: @MockObjectivesContract, 
        token_id: u64, 
        objective_ids: Span<u32>, 
        completed: Span<bool>
    ) {
        assert!(objective_ids.len() == completed.len(), "Mismatched array lengths");
        let mut i = 0;
        loop {
            if i == objective_ids.len() {
                break;
            }
            self.mock_completed_objective(token_id, *objective_ids.at(i), *completed.at(i));
            i += 1;
        };
    }
}

pub trait MockObjectivesContractTrait {
    fn new(address: ContractAddress) -> MockObjectivesContract;
    
    // IMinigameObjectives interface mocks
    fn mock_objective_exists(self: @MockObjectivesContract, objective_id: u32, exists: bool);
    fn mock_completed_objective(self: @MockObjectivesContract, token_id: u64, objective_id: u32, completed: bool);
    fn mock_objectives(self: @MockObjectivesContract, token_id: u64, objectives: Span<GameObjective>);
    
    // IMinigameObjectivesSVG interface mocks
    fn mock_objectives_svg(self: @MockObjectivesContract, token_id: u64, svg: ByteArray);
    
    // Control methods
    fn stop_objective_exists_mock(self: @MockObjectivesContract);
    fn stop_all_mocks(self: @MockObjectivesContract);
    
    // Helper methods
    fn mock_objectives_exist(self: @MockObjectivesContract, objective_ids: Span<u32>, exists: bool);
    fn mock_objective_completions(
        self: @MockObjectivesContract, 
        token_id: u64, 
        objective_ids: Span<u32>, 
        completed: Span<bool>
    );
}

// Helper function to create default game objectives
pub fn create_default_objectives(objective_ids: Span<u32>) -> Array<GameObjective> {
    let mut objectives = array![];
    let mut i = 0;
    loop {
        if i == objective_ids.len() {
            break;
        }
        let id = *objective_ids.at(i);
        objectives.append(GameObjective {
            name: format!("Objective {}", id),
            value: format!("Complete task {}", id)
        });
        i += 1;
    };
    objectives
}

// Helper function to setup a mock objectives contract with common defaults
pub fn setup_mock_objectives() -> MockObjectivesContract {
    let address = starknet::contract_address_const::<'OBJECTIVES'>();
    let mock = MockObjectivesContractImpl::new(address);
    
    // Mock some default objectives (1, 2, 3)
    let default_ids = array![1_u32, 2_u32, 3_u32].span();
    mock.mock_objectives_exist(default_ids, true);
    
    // Mock that objectives are not completed by default
    mock.mock_completed_objective(1, 1, false);
    mock.mock_completed_objective(1, 2, false);
    mock.mock_completed_objective(1, 3, false);
    
    mock
}