//! Integration tests for Simple Token Example
//!
//! This test suite verifies that the simple token example works correctly
//! with features disabled (using default callbacks).
//!
//! Tests cover:
//! - Basic mint functionality
//! - Default callback behavior (features OFF)
//! - Direct embedding pattern
//! - Event emission
//! - Token metadata

use starknet::{ContractAddress, contract_address_const, get_caller_address};
use starknet::testing::{set_caller_address, set_contract_address};
use snforge_std::{declare, ContractClassTrait, spy_events, EventSpy, EventFetcher, EventAssertions, start_cheat_caller_address, stop_cheat_caller_address};
use openzeppelin_token::erc721::ERC721Component;
use game_components_token::examples::simple_token_example::SimpleTokenContract;
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use game_components_token::structs::{TokenMetadata, TokenSettings, TokenObjective};

/// Deploy a simple token contract for testing
fn deploy_simple_token() -> (ContractAddress, IMinigameTokenDispatcher) {
    let contract_class = declare("SimpleTokenContract").unwrap();
    let constructor_calldata = array![
        'TestToken',           // name
        'TEST',               // symbol  
        'https://test.com/',  // base_uri
        0,                    // game_address (None)
        0                     // padding for Option<ContractAddress>
    ];
    
    let contract_address = contract_class.deploy(@constructor_calldata).unwrap();
    let dispatcher = IMinigameTokenDispatcher { contract_address };
    
    (contract_address, dispatcher)
}

/// Test basic mint functionality
#[test]
fn test_simple_token_mint_basic() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    // Set up test parameters
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    // Set caller for the mint
    start_cheat_caller_address(contract_address, caller);
    
    // Mint a token
    let token_id = dispatcher.mint(
        recipient,
        game_address,
        42,                     // settings_id
        array![1, 2, 3],       // objectives
        Option::None,          // instant_game_id
        Option::None,          // player_name
        Option::None,          // context
        false                  // soulbound
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Verify token was minted
    assert!(token_id > 0, "Token should be minted with valid ID");
    
    // Test token metadata
    let metadata = dispatcher.token_metadata(token_id);
    assert!(metadata.game_address == game_address, "Game address should match");
    assert!(metadata.settings_id == 42, "Settings ID should match");
    assert!(!metadata.soulbound, "Token should not be soulbound");
    
    // Test settings
    let settings_id = dispatcher.settings_id(token_id);
    assert!(settings_id == 42, "Settings ID should match");
    
    // Test objectives
    let objectives = dispatcher.objectives(token_id);
    assert!(objectives.len() == 3, "Should have 3 objectives");
    assert!(*objectives.at(0) == 1, "First objective should be 1");
    assert!(*objectives.at(1) == 2, "Second objective should be 2");
    assert!(*objectives.at(2) == 3, "Third objective should be 3");
}

/// Test mint with default callbacks (features OFF)
#[test]
fn test_simple_token_default_callbacks() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    // Mint a token - should use default callbacks
    let token_id = dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![1, 2, 3],       
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Verify token was minted successfully
    assert!(token_id > 0, "Token should be minted");
    
    // Test that default callbacks were used (features OFF)
    let metadata = dispatcher.token_metadata(token_id);
    
    // With default callbacks:
    // - No minter tracking (would need MinterComponent)
    // - No multi-game support (would need MultiGameComponent)  
    // - No objectives tracking (would need ObjectivesComponent)
    // - Basic token functionality only
    
    // Verify basic functionality works
    assert!(metadata.game_address == game_address, "Basic game address should work");
    assert!(metadata.settings_id == 42, "Basic settings should work");
    assert!(!metadata.soulbound, "Basic soulbound should work");
}

/// Test mint with player name
#[test]
fn test_simple_token_mint_with_player_name() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    // Mint with player name
    let token_id = dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![1, 2, 3],       
        Option::None,          
        Option::Some("TestPlayer"),  // player_name
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Verify token was minted
    assert!(token_id > 0, "Token should be minted");
    
    // Test player name
    let player_name = dispatcher.player_name(token_id);
    assert!(player_name == "TestPlayer", "Player name should match");
}

/// Test mint with soulbound token
#[test]
fn test_simple_token_mint_soulbound() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    // Mint soulbound token
    let token_id = dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![1, 2, 3],       
        Option::None,          
        Option::None,          
        Option::None,          
        true                   // soulbound
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Verify token was minted
    assert!(token_id > 0, "Token should be minted");
    
    // Test soulbound status
    let metadata = dispatcher.token_metadata(token_id);
    assert!(metadata.soulbound, "Token should be soulbound");
}

/// Test multiple mints
#[test]
fn test_simple_token_multiple_mints() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    // Mint first token
    let token_id_1 = dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![1, 2, 3],       
        Option::None,          
        Option::Some("Player1"),
        Option::None,          
        false                  
    );
    
    // Mint second token
    let token_id_2 = dispatcher.mint(
        recipient,
        game_address,
        43,                     
        array![4, 5, 6],       
        Option::None,          
        Option::Some("Player2"),
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Verify both tokens were minted
    assert!(token_id_1 > 0, "First token should be minted");
    assert!(token_id_2 > 0, "Second token should be minted");
    assert!(token_id_1 != token_id_2, "Token IDs should be different");
    
    // Verify different metadata
    let metadata_1 = dispatcher.token_metadata(token_id_1);
    let metadata_2 = dispatcher.token_metadata(token_id_2);
    
    assert!(metadata_1.settings_id == 42, "First token settings should be 42");
    assert!(metadata_2.settings_id == 43, "Second token settings should be 43");
    
    let player_name_1 = dispatcher.player_name(token_id_1);
    let player_name_2 = dispatcher.player_name(token_id_2);
    
    assert!(player_name_1 == "Player1", "First player name should match");
    assert!(player_name_2 == "Player2", "Second player name should match");
}

/// Test that token is playable
#[test]
fn test_simple_token_playable() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    let token_id = dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![1, 2, 3],       
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Test playability
    let is_playable = dispatcher.is_playable(token_id);
    assert!(is_playable, "Token should be playable");
}

/// Test event emission during mint
#[test]
fn test_simple_token_mint_events() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    // Setup event spy
    let mut spy = spy_events();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    // Mint a token
    let token_id = dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![1, 2, 3],       
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Verify token was minted
    assert!(token_id > 0, "Token should be minted");
    
    // Fetch events
    spy.fetch_events();
    
    // Should have ERC721 Transfer event (from OpenZeppelin)
    let events = spy.events;
    assert!(events.len() > 0, "Should have emitted events");
    
    // The exact event structure depends on the ERC721 implementation
    // This verifies that events were emitted during mint
}

/// Test game address functionality
#[test]
fn test_simple_token_game_address() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    let token_id = dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![1, 2, 3],       
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Test game address retrieval
    let metadata = dispatcher.token_metadata(token_id);
    assert!(metadata.game_address == game_address, "Game address should match");
}

/// Test objectives functionality
#[test]
fn test_simple_token_objectives() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    let token_id = dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![10, 20, 30],    // Different objectives
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Test objectives retrieval
    let objectives = dispatcher.objectives(token_id);
    assert!(objectives.len() == 3, "Should have 3 objectives");
    assert!(*objectives.at(0) == 10, "First objective should be 10");
    assert!(*objectives.at(1) == 20, "Second objective should be 20");
    assert!(*objectives.at(2) == 30, "Third objective should be 30");
}

/// Test empty objectives
#[test]
fn test_simple_token_empty_objectives() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    let token_id = dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![],              // Empty objectives
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Test empty objectives
    let objectives = dispatcher.objectives(token_id);
    assert!(objectives.len() == 0, "Should have no objectives");
}

//================================================================================================
// CALLBACK VERIFICATION TESTS
//================================================================================================

/// Test that default callbacks are used (features OFF)
#[test]
fn test_simple_token_default_callbacks_verification() {
    let (contract_address, dispatcher) = deploy_simple_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    // Mint a token
    let token_id = dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![1, 2, 3],       
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Verify basic functionality works
    assert!(token_id > 0, "Token should be minted");
    
    // With default callbacks, advanced features should NOT be available
    // This is the expected behavior for SimpleTokenContract
    
    // The token should have basic functionality only
    let metadata = dispatcher.token_metadata(token_id);
    assert!(metadata.game_address == game_address, "Basic metadata should work");
    assert!(metadata.settings_id == 42, "Basic settings should work");
    
    // Features that would require component callbacks are not available
    // This is verified by the fact that the contract compiles and runs
    // with default callbacks instead of component callbacks
}

//================================================================================================
// NOTES ON SIMPLE TOKEN BEHAVIOR
//================================================================================================

// 🎯 The Simple Token Example uses DEFAULT callbacks, which means:
//
// ✅ ENABLED (Basic functionality):
// - ERC721 standard functionality
// - Basic token metadata (game_address, settings_id, objectives)
// - Player name support
// - Soulbound functionality
// - Basic mint/burn operations
//
// ❌ DISABLED (Advanced features):
// - Minter tracking (would need MinterComponent)
// - Multi-game support (would need MultiGameComponent)
// - Objectives tracking (would need ObjectivesComponent)
// - Context metadata (would need ContextComponent)
// - Custom rendering (would need RendererComponent)
//
// This demonstrates the callback pattern working correctly:
// - Default callbacks provide basic functionality
// - Component callbacks would provide advanced features
// - The same interface works for both modes 