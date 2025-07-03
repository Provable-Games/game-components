use starknet::ContractAddress;
use game_components_minigame::interface::{
    IMinigame, IMinigameTokenData, IMinigameDetails, IMinigameDetailsSVG, IMinigameTokenUri
};
use game_components_minigame::structs::GameDetail;
use snforge_std::{start_mock_call, stop_mock_call, mock_call};

#[derive(Drop, Copy)]
pub struct MockMinigameContract {
    pub contract_address: ContractAddress,
    pub token_address: ContractAddress,
    pub settings_address: ContractAddress,
    pub objectives_address: ContractAddress,
}

pub impl MockMinigameContractImpl of MockMinigameContractTrait {
    fn new(
        address: ContractAddress,
        token_address: ContractAddress,
        settings_address: ContractAddress,
        objectives_address: ContractAddress
    ) -> MockMinigameContract {
        let mock = MockMinigameContract {
            contract_address: address,
            token_address,
            settings_address,
            objectives_address,
        };
        
        // Setup default mocks for IMinigame interface
        mock.mock_token_address(token_address);
        mock.mock_settings_address(settings_address);
        mock.mock_objectives_address(objectives_address);
        
        mock
    }

    // IMinigame interface mocks
    fn mock_token_address(self: @MockMinigameContract, address: ContractAddress) {
        let selector = selector!("token_address");
        start_mock_call(*self.contract_address, selector, address);
    }

    fn mock_settings_address(self: @MockMinigameContract, address: ContractAddress) {
        let selector = selector!("settings_address");
        start_mock_call(*self.contract_address, selector, address);
    }

    fn mock_objectives_address(self: @MockMinigameContract, address: ContractAddress) {
        let selector = selector!("objectives_address");
        start_mock_call(*self.contract_address, selector, address);
    }

    // IMinigameTokenData interface mocks
    fn mock_score(self: @MockMinigameContract, token_id: u64, score: u32) {
        let selector = selector!("score");
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, score);
    }

    fn mock_game_over(self: @MockMinigameContract, token_id: u64, game_over: bool) {
        let selector = selector!("game_over");
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, game_over);
    }

    // IMinigameDetails interface mocks
    fn mock_token_description(self: @MockMinigameContract, token_id: u64, description: ByteArray) {
        let selector = selector!("token_description");
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, description);
    }

    fn mock_game_details(self: @MockMinigameContract, token_id: u64, details: Span<GameDetail>) {
        let selector = selector!("game_details");
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, details);
    }

    // IMinigameDetailsSVG interface mocks
    fn mock_game_details_svg(self: @MockMinigameContract, token_id: u64, svg: ByteArray) {
        let selector = selector!("game_details_svg");
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, svg);
    }

    // IMinigameTokenUri interface mocks
    fn mock_token_uri(self: @MockMinigameContract, token_id: u256, uri: ByteArray) {
        let selector = selector!("token_uri");
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, uri);
    }

    // Stop specific mock - note: selector must be known at compile time
    fn stop_token_address_mock(self: @MockMinigameContract) {
        stop_mock_call(*self.contract_address, selector!("token_address"));
    }

    // Stop all mocks
    fn stop_all_mocks(self: @MockMinigameContract) {
        stop_mock_call(*self.contract_address, selector!("token_address"));
        stop_mock_call(*self.contract_address, selector!("settings_address"));
        stop_mock_call(*self.contract_address, selector!("objectives_address"));
        stop_mock_call(*self.contract_address, selector!("score"));
        stop_mock_call(*self.contract_address, selector!("game_over"));
        stop_mock_call(*self.contract_address, selector!("token_description"));
        stop_mock_call(*self.contract_address, selector!("game_details"));
        stop_mock_call(*self.contract_address, selector!("game_details_svg"));
        stop_mock_call(*self.contract_address, selector!("token_uri"));
    }
}

pub trait MockMinigameContractTrait {
    fn new(
        address: ContractAddress,
        token_address: ContractAddress,
        settings_address: ContractAddress,
        objectives_address: ContractAddress
    ) -> MockMinigameContract;
    
    // IMinigame interface mocks
    fn mock_token_address(self: @MockMinigameContract, address: ContractAddress);
    fn mock_settings_address(self: @MockMinigameContract, address: ContractAddress);
    fn mock_objectives_address(self: @MockMinigameContract, address: ContractAddress);
    
    // IMinigameTokenData interface mocks
    fn mock_score(self: @MockMinigameContract, token_id: u64, score: u32);
    fn mock_game_over(self: @MockMinigameContract, token_id: u64, game_over: bool);
    
    // IMinigameDetails interface mocks
    fn mock_token_description(self: @MockMinigameContract, token_id: u64, description: ByteArray);
    fn mock_game_details(self: @MockMinigameContract, token_id: u64, details: Span<GameDetail>);
    
    // IMinigameDetailsSVG interface mocks
    fn mock_game_details_svg(self: @MockMinigameContract, token_id: u64, svg: ByteArray);
    
    // IMinigameTokenUri interface mocks
    fn mock_token_uri(self: @MockMinigameContract, token_id: u256, uri: ByteArray);
    
    // Control methods
    fn stop_token_address_mock(self: @MockMinigameContract);
    fn stop_all_mocks(self: @MockMinigameContract);
}

// Helper function to create a mock minigame with interface support
pub fn setup_mock_minigame() -> (MockMinigameContract, ContractAddress, ContractAddress, ContractAddress) {
    let game_address = starknet::contract_address_const::<'GAME'>();
    let token_address = starknet::contract_address_const::<'TOKEN'>();
    let settings_address = starknet::contract_address_const::<'SETTINGS'>();
    let objectives_address = starknet::contract_address_const::<'OBJECTIVES'>();
    
    // Mock SRC5 supports_interface for IMinigame
    let iminigame_id = 0x02c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499704;
    start_mock_call(game_address, selector!("supports_interface"), true);
    
    let mock = MockMinigameContractImpl::new(
        game_address,
        token_address,
        settings_address,
        objectives_address
    );
    
    (mock, token_address, settings_address, objectives_address)
}