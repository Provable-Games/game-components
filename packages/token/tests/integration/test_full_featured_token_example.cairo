//! Integration tests for Full Featured Token Example
//!
//! This test suite verifies that the full featured token example works correctly
//! with all features enabled (using multiple component callbacks).
//!
//! Tests cover:
//! - Basic mint functionality
//! - Minter tracking functionality (ON)
//! - Multi-game support functionality (ON) 
//! - Objectives tracking functionality (ON)
//! - Integration between all features
//! - Direct embedding pattern
//! - Event emission
//! - Component orchestration

use starknet::{ContractAddress, contract_address_const, get_caller_address};
use starknet::testing::{set_caller_address, set_contract_address};
use snforge_std::{declare, ContractClassTrait, spy_events, EventSpy, EventFetcher, EventAssertions, start_cheat_caller_address, stop_cheat_caller_address};
use openzeppelin_token::erc721::ERC721Component;
use game_components_token::examples::full_featured_token_example::FullFeaturedTokenContract;
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use game_components_token::extensions::minter::interface::{IMinterTokenDispatcher, IMinterTokenDispatcherTrait};
use game_components_token::extensions::multi_game::interface::{IMultiGameTokenDispatcher, IMultiGameTokenDispatcherTrait};
use game_components_token::extensions::objectives::interface::{ITokenObjectivesDispatcher, ITokenObjectivesDispatcherTrait};
use game_components_token::structs::{TokenMetadata, TokenSettings, TokenObjective};

/// Deploy a full featured token contract for testing
fn deploy_full_featured_token() -> (
    ContractAddress, 
    IMinigameTokenDispatcher, 
    IMinterTokenDispatcher, 
    IMultiGameTokenDispatcher,
    ITokenObjectivesDispatcher
) {
    let contract_class = declare("FullFeaturedTokenContract").unwrap();
    let constructor_calldata = array![
        'FullToken',          // name
        'FULL',              // symbol  
        'https://full.com/', // base_uri
        0,                   // game_address (None)
        0                    // padding for Option<ContractAddress>
    ];
    
    let contract_address = contract_class.deploy(@constructor_calldata).unwrap();
    let token_dispatcher = IMinigameTokenDispatcher { contract_address };
    let minter_dispatcher = IMinterTokenDispatcher { contract_address };
    let multi_game_dispatcher = IMultiGameTokenDispatcher { contract_address };
    let objectives_dispatcher = ITokenObjectivesDispatcher { contract_address };
    
    (contract_address, token_dispatcher, minter_dispatcher, multi_game_dispatcher, objectives_dispatcher)
}

/// Test basic mint functionality with all features
#[test]
fn test_full_featured_token_mint_basic() {
    let (contract_address, token_dispatcher, minter_dispatcher, multi_game_dispatcher, objectives_dispatcher) = deploy_full_featured_token();
    
    // Set up test parameters
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    // Set caller for the mint
    start_cheat_caller_address(contract_address, caller);
    
    // Mint a token
    let token_id = token_dispatcher.mint(
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
    
    // Test basic token metadata
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.game_address == game_address, "Game address should match");
    assert!(metadata.settings_id == 42, "Settings ID should match");
    assert!(!metadata.soulbound, "Token should not be soulbound");
    
    // ✅ Test minter tracking functionality
    let minter_id = minter_dispatcher.minted_by(token_id);
    assert!(minter_id > 0, "Token should have a minter ID");
    
    let minter_address = minter_dispatcher.minter_address(minter_id);
    assert!(minter_address == caller, "Minter address should match caller");
    
    let minter_count = minter_dispatcher.minter_count();
    assert!(minter_count == 1, "Should have 1 registered minter");
    
    // ✅ Test multi-game functionality
    let game_id = multi_game_dispatcher.get_game_id_from_address(game_address);
    assert!(game_id > 0, "Game should be registered");
    
    let retrieved_game_address = multi_game_dispatcher.get_game_address_from_id(game_id);
    assert!(retrieved_game_address == game_address, "Game address should match");
    
    let game_count = multi_game_dispatcher.game_count();
    assert!(game_count == 1, "Should have 1 registered game");
    
    // ✅ Test objectives functionality
    let objective_count = objectives_dispatcher.get_objective_count(token_id);
    assert!(objective_count == 3, "Should have 3 objectives");
    
    // Check individual objectives
    let objective_0 = objectives_dispatcher.get_objective(token_id, 0);
    assert!(objective_0.id == 1, "First objective ID should be 1");
    assert!(!objective_0.completed, "First objective should not be completed");
    
    let objective_1 = objectives_dispatcher.get_objective(token_id, 1);
    assert!(objective_1.id == 2, "Second objective ID should be 2");
    
    let objective_2 = objectives_dispatcher.get_objective(token_id, 2);
    assert!(objective_2.id == 3, "Third objective ID should be 3");
}

/// Test all features working together
#[test]
fn test_full_featured_token_all_features_integration() {
    let (contract_address, token_dispatcher, minter_dispatcher, multi_game_dispatcher, objectives_dispatcher) = deploy_full_featured_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address_1 = contract_address_const::<0x456>();
    let game_address_2 = contract_address_const::<0x789>();
    let caller = contract_address_const::<0xabc>();
    
    start_cheat_caller_address(contract_address, caller);
    
    // Mint first token with game 1
    let token_id_1 = token_dispatcher.mint(
        recipient,
        game_address_1,
        42,                     
        array![1, 2, 3],       
        Option::None,          
        Option::Some("Player1"),
        Option::None,          
        false                  
    );
    
    // Mint second token with game 2
    let token_id_2 = token_dispatcher.mint(
        recipient,
        game_address_2,
        43,                     
        array![4, 5],          
        Option::None,          
        Option::Some("Player2"),
        Option::None,          
        true                   // soulbound
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Verify both tokens were minted
    assert!(token_id_1 > 0, "First token should be minted");
    assert!(token_id_2 > 0, "Second token should be minted");
    assert!(token_id_1 != token_id_2, "Token IDs should be different");
    
    // ✅ Test minter tracking for both tokens
    let minter_id_1 = minter_dispatcher.minted_by(token_id_1);
    let minter_id_2 = minter_dispatcher.minted_by(token_id_2);
    
    // Same caller should have same minter ID
    assert!(minter_id_1 == minter_id_2, "Same caller should have same minter ID");
    assert!(minter_id_1 == 1, "Should be first minter");
    
    let minter_count = minter_dispatcher.minter_count();
    assert!(minter_count == 1, "Should have 1 minter total");
    
    // ✅ Test multi-game functionality for both games
    let game_id_1 = multi_game_dispatcher.get_game_id_from_address(game_address_1);
    let game_id_2 = multi_game_dispatcher.get_game_id_from_address(game_address_2);
    
    assert!(game_id_1 > 0, "First game should be registered");
    assert!(game_id_2 > 0, "Second game should be registered");
    assert!(game_id_1 != game_id_2, "Games should have different IDs");
    
    let game_count = multi_game_dispatcher.game_count();
    assert!(game_count == 2, "Should have 2 registered games");
    
    // ✅ Test objectives for both tokens
    let objective_count_1 = objectives_dispatcher.get_objective_count(token_id_1);
    let objective_count_2 = objectives_dispatcher.get_objective_count(token_id_2);
    
    assert!(objective_count_1 == 3, "First token should have 3 objectives");
    assert!(objective_count_2 == 2, "Second token should have 2 objectives");
    
    // Test basic token metadata differences
    let metadata_1 = token_dispatcher.token_metadata(token_id_1);
    let metadata_2 = token_dispatcher.token_metadata(token_id_2);
    
    assert!(metadata_1.game_address == game_address_1, "First token game address");
    assert!(metadata_2.game_address == game_address_2, "Second token game address");
    assert!(!metadata_1.soulbound, "First token should not be soulbound");
    assert!(metadata_2.soulbound, "Second token should be soulbound");
    
    let player_name_1 = token_dispatcher.player_name(token_id_1);
    let player_name_2 = token_dispatcher.player_name(token_id_2);
    
    assert!(player_name_1 == "Player1", "First player name should match");
    assert!(player_name_2 == "Player2", "Second player name should match");
}

/// Test objectives completion functionality
#[test]
fn test_full_featured_token_objectives_completion() {
    let (contract_address, token_dispatcher, minter_dispatcher, multi_game_dispatcher, objectives_dispatcher) = deploy_full_featured_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    let token_id = token_dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![10, 20, 30],    
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Initially, no objectives should be completed
    let objective_0 = objectives_dispatcher.get_objective(token_id, 0);
    let objective_1 = objectives_dispatcher.get_objective(token_id, 1);
    let objective_2 = objectives_dispatcher.get_objective(token_id, 2);
    
    assert!(!objective_0.completed, "Objective 0 should not be completed initially");
    assert!(!objective_1.completed, "Objective 1 should not be completed initially");
    assert!(!objective_2.completed, "Objective 2 should not be completed initially");
    
    // Complete first objective
    start_cheat_caller_address(contract_address, caller);
    objectives_dispatcher.complete_objective(token_id, 0);
    stop_cheat_caller_address(contract_address);
    
    // Check that first objective is completed, others are not
    let objective_0_after = objectives_dispatcher.get_objective(token_id, 0);
    let objective_1_after = objectives_dispatcher.get_objective(token_id, 1);
    let objective_2_after = objectives_dispatcher.get_objective(token_id, 2);
    
    assert!(objective_0_after.completed, "Objective 0 should be completed");
    assert!(!objective_1_after.completed, "Objective 1 should not be completed");
    assert!(!objective_2_after.completed, "Objective 2 should not be completed");
    
    // Complete second objective
    start_cheat_caller_address(contract_address, caller);
    objectives_dispatcher.complete_objective(token_id, 1);
    stop_cheat_caller_address(contract_address);
    
    // Check completion status
    let completed_count = objectives_dispatcher.get_completed_objectives_count(token_id);
    assert!(completed_count == 2, "Should have 2 completed objectives");
}

/// Test multi-game functionality with game metadata
#[test]
fn test_full_featured_token_multi_game_metadata() {
    let (contract_address, token_dispatcher, minter_dispatcher, multi_game_dispatcher, objectives_dispatcher) = deploy_full_featured_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address_1 = contract_address_const::<0x456>();
    let game_address_2 = contract_address_const::<0x789>();
    let caller = contract_address_const::<0xabc>();
    
    start_cheat_caller_address(contract_address, caller);
    
    // Mint tokens with different games
    let token_id_1 = token_dispatcher.mint(
        recipient,
        game_address_1,
        42,                     
        array![1, 2],          
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    let token_id_2 = token_dispatcher.mint(
        recipient,
        game_address_2,
        43,                     
        array![3, 4, 5],       
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Test game metadata
    let game_id_1 = multi_game_dispatcher.get_game_id_from_address(game_address_1);
    let game_id_2 = multi_game_dispatcher.get_game_id_from_address(game_address_2);
    
    let game_metadata_1 = multi_game_dispatcher.get_game_metadata(game_id_1);
    let game_metadata_2 = multi_game_dispatcher.get_game_metadata(game_id_2);
    
    assert!(game_metadata_1.game_address == game_address_1, "Game 1 address should match");
    assert!(game_metadata_2.game_address == game_address_2, "Game 2 address should match");
    
    // Test bidirectional mapping
    let retrieved_address_1 = multi_game_dispatcher.get_game_address_from_id(game_id_1);
    let retrieved_address_2 = multi_game_dispatcher.get_game_address_from_id(game_id_2);
    
    assert!(retrieved_address_1 == game_address_1, "Retrieved address 1 should match");
    assert!(retrieved_address_2 == game_address_2, "Retrieved address 2 should match");
}

/// Test all features with events
#[test]
fn test_full_featured_token_all_features_events() {
    let (contract_address, token_dispatcher, minter_dispatcher, multi_game_dispatcher, objectives_dispatcher) = deploy_full_featured_token();
    
    // Setup event spy
    let mut spy = spy_events();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    // Mint a token
    let token_id = token_dispatcher.mint(
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
    
    // Should have events from all components
    let events = spy.events;
    assert!(events.len() > 0, "Should have emitted events");
    
    // Events should include:
    // - ERC721 Transfer event
    // - Minter registration events
    // - Multi-game registration events  
    // - Objectives setup events
    // The exact structure depends on component implementations
}

/// Test complex objectives workflow
#[test]
fn test_full_featured_token_complex_objectives() {
    let (contract_address, token_dispatcher, minter_dispatcher, multi_game_dispatcher, objectives_dispatcher) = deploy_full_featured_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    let token_id = token_dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![100, 200, 300, 400, 500],  // 5 objectives
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Verify all objectives are set up
    let objective_count = objectives_dispatcher.get_objective_count(token_id);
    assert!(objective_count == 5, "Should have 5 objectives");
    
    // Test each objective
    let mut i = 0;
    while i < 5 {
        let objective = objectives_dispatcher.get_objective(token_id, i);
        let expected_id = (i + 1) * 100;  // 100, 200, 300, 400, 500
        assert!(objective.id == expected_id, "Objective ID should match expected");
        assert!(!objective.completed, "Objective should not be completed initially");
        i += 1;
    };
    
    // Complete objectives in different order
    start_cheat_caller_address(contract_address, caller);
    objectives_dispatcher.complete_objective(token_id, 2); // Complete 3rd objective
    objectives_dispatcher.complete_objective(token_id, 0); // Complete 1st objective
    objectives_dispatcher.complete_objective(token_id, 4); // Complete 5th objective
    stop_cheat_caller_address(contract_address);
    
    // Check completion status
    let completed_count = objectives_dispatcher.get_completed_objectives_count(token_id);
    assert!(completed_count == 3, "Should have 3 completed objectives");
    
    // Check specific completions
    let objective_0 = objectives_dispatcher.get_objective(token_id, 0);
    let objective_1 = objectives_dispatcher.get_objective(token_id, 1);
    let objective_2 = objectives_dispatcher.get_objective(token_id, 2);
    let objective_3 = objectives_dispatcher.get_objective(token_id, 3);
    let objective_4 = objectives_dispatcher.get_objective(token_id, 4);
    
    assert!(objective_0.completed, "Objective 0 should be completed");
    assert!(!objective_1.completed, "Objective 1 should not be completed");
    assert!(objective_2.completed, "Objective 2 should be completed");
    assert!(!objective_3.completed, "Objective 3 should not be completed");
    assert!(objective_4.completed, "Objective 4 should be completed");
}

/// Test initialization of all components
#[test]
fn test_full_featured_token_initialization() {
    let (contract_address, token_dispatcher, minter_dispatcher, multi_game_dispatcher, objectives_dispatcher) = deploy_full_featured_token();
    
    // Test initial states
    let initial_minter_count = minter_dispatcher.minter_count();
    assert!(initial_minter_count == 0, "Initial minter count should be 0");
    
    let initial_game_count = multi_game_dispatcher.game_count();
    assert!(initial_game_count == 0, "Initial game count should be 0");
    
    // All components should be properly initialized and ready for use
}

/// Test feature interactions and edge cases
#[test]
fn test_full_featured_token_feature_interactions() {
    let (contract_address, token_dispatcher, minter_dispatcher, multi_game_dispatcher, objectives_dispatcher) = deploy_full_featured_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller1 = contract_address_const::<0x789>();
    let caller2 = contract_address_const::<0xabc>();
    
    // Test with different callers and same game
    start_cheat_caller_address(contract_address, caller1);
    
    let token_id_1 = token_dispatcher.mint(
        recipient,
        game_address,
        42,                     
        array![1, 2],          
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, caller2);
    
    let token_id_2 = token_dispatcher.mint(
        recipient,
        game_address,  // Same game address
        43,                     
        array![3, 4, 5],       
        Option::None,          
        Option::None,          
        Option::None,          
        false                  
    );
    
    stop_cheat_caller_address(contract_address);
    
    // Test minter tracking with different callers
    let minter_id_1 = minter_dispatcher.minted_by(token_id_1);
    let minter_id_2 = minter_dispatcher.minted_by(token_id_2);
    
    assert!(minter_id_1 != minter_id_2, "Different callers should have different minter IDs");
    assert!(minter_dispatcher.minter_count() == 2, "Should have 2 different minters");
    
    // Test game tracking with same game
    let game_id_1 = multi_game_dispatcher.get_game_id_from_address(game_address);
    let game_id_2 = multi_game_dispatcher.get_game_id_from_address(game_address);
    
    assert!(game_id_1 == game_id_2, "Same game address should have same ID");
    assert!(multi_game_dispatcher.game_count() == 1, "Should have only 1 game registered");
    
    // Test objectives tracking for different tokens
    let objective_count_1 = objectives_dispatcher.get_objective_count(token_id_1);
    let objective_count_2 = objectives_dispatcher.get_objective_count(token_id_2);
    
    assert!(objective_count_1 == 2, "First token should have 2 objectives");
    assert!(objective_count_2 == 3, "Second token should have 3 objectives");
    
    // Complete objectives on both tokens
    start_cheat_caller_address(contract_address, caller1);
    objectives_dispatcher.complete_objective(token_id_1, 0);
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, caller2);
    objectives_dispatcher.complete_objective(token_id_2, 1);
    stop_cheat_caller_address(contract_address);
    
    // Check independent completion tracking
    let completed_1 = objectives_dispatcher.get_completed_objectives_count(token_id_1);
    let completed_2 = objectives_dispatcher.get_completed_objectives_count(token_id_2);
    
    assert!(completed_1 == 1, "First token should have 1 completed objective");
    assert!(completed_2 == 1, "Second token should have 1 completed objective");
}

//================================================================================================
// COMPREHENSIVE FEATURE VERIFICATION TESTS
//================================================================================================

/// Test that all component callbacks are enabled
#[test]
fn test_full_featured_token_all_callbacks_enabled() {
    let (contract_address, token_dispatcher, minter_dispatcher, multi_game_dispatcher, objectives_dispatcher) = deploy_full_featured_token();
    
    let recipient = contract_address_const::<0x123>();
    let game_address = contract_address_const::<0x456>();
    let caller = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, caller);
    
    let token_id = token_dispatcher.mint(
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
    
    // ✅ Verify ALL features are enabled through component callbacks
    
    // Basic token functionality
    assert!(token_id > 0, "Basic mint should work");
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.game_address == game_address, "Basic metadata should work");
    
    // Minter callback enabled
    let minter_id = minter_dispatcher.minted_by(token_id);
    assert!(minter_id > 0, "Minter callback should be enabled");
    
    // Multi-game callback enabled
    let game_id = multi_game_dispatcher.get_game_id_from_address(game_address);
    assert!(game_id > 0, "Multi-game callback should be enabled");
    
    // Objectives callback enabled
    let objective_count = objectives_dispatcher.get_objective_count(token_id);
    assert!(objective_count == 3, "Objectives callback should be enabled");
    
    // This demonstrates that ALL component callbacks are working:
    // - MinterCallback uses MinterComponent
    // - MultiGameCallback uses MultiGameComponent  
    // - ObjectivesCallback uses ObjectivesComponent
    // - All features are fully functional simultaneously
}

//================================================================================================
// NOTES ON FULL FEATURED TOKEN BEHAVIOR
//================================================================================================

// 🎯 The Full Featured Token Example demonstrates MAXIMUM feature enablement:
//
// ✅ ENABLED (via component callbacks):
// - Minter tracking (uses MinterComponent)
//   - Track who minted each token
//   - Bidirectional minter registry
//   - Minter events
//
// - Multi-game support (uses MultiGameComponent)
//   - Register and track multiple games
//   - Bidirectional game address/ID mapping
//   - Game metadata and events
//
// - Objectives tracking (uses ObjectivesComponent)
//   - Set up token objectives during mint
//   - Track completion status
//   - Complete objectives individually
//   - Count completed objectives
//
// ✅ ENABLED (basic functionality):
// - ERC721 standard functionality
// - Basic token metadata (game_address, settings_id, objectives)
// - Player name support
// - Soulbound functionality
// - Basic mint/burn operations
//
// ❌ STILL DISABLED (uses default callbacks):
// - Context metadata (would need ContextComponent)
// - Custom rendering (would need RendererComponent)
// - Soulbound restrictions (uses default soulbound callback)
//
// This demonstrates the full power of the callback pattern:
// - Multiple component callbacks can work together
// - Each feature is independently functional
// - Features can interact and complement each other
// - Still maintains clean separation of concerns
// - Same interface supports maximum functionality
//
// This is the most comprehensive example showing how the callback pattern
// scales to support multiple advanced features simultaneously while
// maintaining code clarity and component modularity.
//
// This is the most comprehensive example showing how the callback pattern
// scales to support multiple advanced features simultaneously while
// maintaining code clarity and component modularity. 