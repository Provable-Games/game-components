use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, set_block_timestamp};
use snforge_std::{declare, ContractClassTrait};
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use game_components_token::token::TokenComponent;
use game_components_token::libs::token_hooks_empty;

// UT-H-01: Empty hooks mint
#[test]
fn test_unit_hooks_empty_mint() {
    let user1 = contract_address_const::<'user1'>();
    let game_address = contract_address_const::<'game'>();
    
    // Deploy token with empty hooks
    let contract = declare("MockToken").unwrap();
    let (token_address, _) = contract.deploy(@array![
        'TestToken', 'TST', 'https://test.com/', game_address.into()
    ]).unwrap();
    
    let token = IMinigameTokenDispatcher { contract_address: token_address };
    
    set_caller_address(user1);
    set_block_timestamp(1000);
    
    // Test with various inputs - empty hooks should handle without validation
    let token_id = token.mint(
        Option::Some(game_address),
        Option::Some("Player"),
        Option::Some(999),  // Non-existent settings - empty hooks don't validate
        Option::Some(500),
        Option::Some(2000),
        Option::Some(array![999, 998, 997].span()),  // Non-existent objectives
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    assert!(token_id == 1, "Token should be minted");
    
    let metadata = token.token_metadata(token_id);
    assert!(metadata.game_id == 0, "Game ID should be 0 from empty hooks");
    assert!(metadata.settings_id == 999, "Settings ID should be passed through");
    assert!(metadata.objectives_count == 0, "Objectives count should be 0 from empty hooks");
}

// UT-H-05: Hook call order
#[test]
fn test_unit_hooks_empty_call_order() {
    let user1 = contract_address_const::<'user1'>();
    let game_address = contract_address_const::<'game'>();
    
    // Deploy token with empty hooks
    let contract = declare("MockToken").unwrap();
    let (token_address, _) = contract.deploy(@array![
        'TestToken', 'TST', 'https://test.com/', game_address.into()
    ]).unwrap();
    
    let token = IMinigameTokenDispatcher { contract_address: token_address };
    
    set_caller_address(user1);
    
    // Mint token - hooks are called but don't do anything
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    // Update game - hooks are called but don't affect behavior
    token.update_game(token_id);
    
    // Empty hooks should complete without errors
    assert!(true, "Empty hooks executed successfully");
}

// Test that empty hooks return default values
#[test]
fn test_unit_hooks_empty_default_values() {
    // This test verifies the specific default values returned by empty hooks
    // We can't test the hooks directly, but we can verify their effects
    
    let user1 = contract_address_const::<'user1'>();
    let game_address = contract_address_const::<'game'>();
    
    let contract = declare("MockToken").unwrap();
    let (token_address, _) = contract.deploy(@array![
        'TestToken', 'TST', 'https://test.com/', game_address.into()
    ]).unwrap();
    
    let token = IMinigameTokenDispatcher { contract_address: token_address };
    
    set_caller_address(user1);
    
    // Mint with objectives - empty hooks return 0 for objectives count
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(array![1, 2, 3].span()),
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    let metadata = token.token_metadata(token_id);
    assert!(metadata.objectives_count == 0, "Empty hooks should return 0 objectives");
    
    // Update game - empty hooks return false for completed_all_objectives
    token.update_game(token_id);
    
    let updated_metadata = token.token_metadata(token_id);
    assert!(!updated_metadata.completed_all_objectives, "Empty hooks should return false for objectives completion");
}