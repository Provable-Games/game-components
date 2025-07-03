use starknet::ContractAddress;
use crate::common::constants;
use crate::common::helpers;
use crate::common::mocks::mock_token::MockMinigameTokenTrait;

// Interface for calling test functions
#[starknet::interface]
trait IMockMetagameTest<TContractState> {
    fn test_assert_game_registered(ref self: TContractState, game_address: ContractAddress);
}

// REG-01: Check registered game
#[test]
fn test_check_registered_game() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    // Setup mock token to return true for is_game_registered
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Should not revert
    test_contract.test_assert_game_registered(game_address);
    
    // Clean up mock
    mock_token.stop_mock(selector!("is_game_registered"));
}

// REG-02: Check unregistered game
#[test]
#[should_panic(expected: ('Game is not registered', ))]
fn test_check_unregistered_game() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    // Setup mock token to return false for is_game_registered
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, false);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Should revert with "Game is not registered"
    test_contract.test_assert_game_registered(game_address);
}

// REG-03: Check zero address game
#[test]
#[should_panic(expected: ('Game is not registered', ))]
fn test_check_zero_address_game() {
    let token_address = constants::TOKEN_ADDRESS();
    let zero_address = constants::ZERO_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    // Setup mock token to return false for zero address
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(zero_address, false);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Should revert
    test_contract.test_assert_game_registered(zero_address);
}

// REG-04: Check with invalid world (simulated by checking multiple addresses)
#[test]
fn test_game_registration_multiple_addresses() {
    let token_address = constants::TOKEN_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    // Register multiple games
    let game1 = constants::GAME_ADDRESS();
    let game2 = constants::ALICE();
    let game3 = constants::BOB();
    
    mock_token.mock_is_game_registered(game1, true);
    mock_token.mock_is_game_registered(game2, true);
    mock_token.mock_is_game_registered(game3, false);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Registered games should pass
    test_contract.test_assert_game_registered(game1);
    test_contract.test_assert_game_registered(game2);
    
    // Clean up specific mocks
    mock_token.stop_mock(selector!("is_game_registered"));
}

// Additional test: Verify single-use mock behavior
#[test]
fn test_game_registration_mock_once() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    // Mock only once
    mock_token.mock_is_game_registered_once(game_address, true);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // First call should succeed
    test_contract.test_assert_game_registered(game_address);
    
    // Second call would fail if we tried (mock exhausted)
    // This demonstrates the mock_once functionality
}

// Test edge case addresses
#[test]
#[should_panic(expected: ('Game is not registered', ))]
fn test_game_registration_edge_addresses() {
    let token_address = constants::TOKEN_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Test with maximum value address
    let max_address: ContractAddress = starknet::contract_address_const::<0x7ffffffffffffffffffffffffffffff>();
    mock_token.mock_is_game_registered(max_address, false);
    
    // Should panic since not registered
    test_contract.test_assert_game_registered(max_address);
}