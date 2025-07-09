use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use starknet::testing::{set_caller_address, set_block_timestamp, set_account_contract_address};
use snforge_std::{declare, ContractClassTrait, spy_events, EventSpyTrait, EventSpyAssertionsTrait, EventSpy};
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use game_components_token::structs::{TokenMetadata, Lifecycle};
use game_components_token::token::TokenComponent;
use game_components_metagame::extensions::context::structs::GameContextDetails;
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use core::serde::Serde;
use starknet::syscalls::call_contract_syscall;
use core::poseidon::poseidon_hash_span;

fn deploy_mock_token(game_address: Option<ContractAddress>) -> (IMinigameTokenDispatcher, IERC721Dispatcher) {
    let contract = declare("MockToken").unwrap();
    let (token_address, _) = contract.deploy(@array![
        'TestToken', 'TST', 'https://test.com/', 
        match game_address {
            Option::Some(addr) => addr.into(),
            Option::None => 0
        }
    ]).unwrap();
    
    (IMinigameTokenDispatcher { contract_address: token_address }, IERC721Dispatcher { contract_address: token_address })
}

fn deploy_mock_minigame() -> ContractAddress {
    let contract = declare("MockMinigame").unwrap();
    let (game_address, _) = contract.deploy(@array![]).unwrap();
    game_address
}

fn deploy_mock_settings() -> ContractAddress {
    let contract = declare("MockSettings").unwrap();
    let (settings_address, _) = contract.deploy(@array![]).unwrap();
    settings_address
}

fn deploy_mock_objectives() -> ContractAddress {
    let contract = declare("MockObjectives").unwrap();
    let (objectives_address, _) = contract.deploy(@array![]).unwrap();
    objectives_address
}

// UT-M-01: Minimal mint
#[test]
fn test_unit_mint_minimal() {
    let user1 = contract_address_const::<'user1'>();
    let (token, erc721) = deploy_mock_token(Option::None);
    
    set_caller_address(user1);
    let token_id = token.mint(
        Option::None,           // game_address
        Option::None,           // player_name
        Option::None,           // settings_id
        Option::None,           // start
        Option::None,           // end
        Option::None,           // objective_ids
        Option::None,           // context
        Option::None,           // client_url
        Option::None,           // renderer_address
        user1,                  // to
        false                   // soulbound
    );
    
    assert!(token_id == 1, "Expected token ID 1");
    assert!(erc721.owner_of(1) == user1, "Token not minted to user1");
}

// UT-M-02: Full featured mint
#[test]
fn test_unit_mint_full_featured() {
    let user1 = contract_address_const::<'user1'>();
    let game_address = deploy_mock_minigame();
    let (token, erc721) = deploy_mock_token(Option::Some(game_address));
    
    set_caller_address(user1);
    set_block_timestamp(1000);
    
    let token_id = token.mint(
        Option::Some(game_address),
        Option::Some("Player One"),
        Option::Some(1),
        Option::Some(1000),
        Option::Some(2000),
        Option::Some(array![1, 2, 3].span()),
        Option::Some(GameContextDetails { 
            metagame_id: 123, 
            tournament_id: 456, 
            event_id: 789, 
            event_type: "test"
        }),
        Option::Some("https://client.test"),
        Option::Some(contract_address_const::<'renderer'>()),
        user1,
        true
    );
    
    assert!(token_id == 1, "Expected token ID 1");
    assert!(erc721.owner_of(1) == user1, "Token not minted to user1");
    
    let metadata = token.token_metadata(1);
    assert!(metadata.settings_id == 1, "Settings ID mismatch");
    assert!(metadata.lifecycle.start == 1000, "Start time mismatch");
    assert!(metadata.lifecycle.end == 2000, "End time mismatch");
    assert!(metadata.soulbound == true, "Soulbound flag mismatch");
    assert!(metadata.has_context == true, "Context flag mismatch");
    assert!(metadata.objectives_count == 3, "Objectives count mismatch");
    
    assert!(token.player_name(1) == "Player One", "Player name mismatch");
}

// UT-M-03: Invalid game address
#[test]
#[should_panic(expected: 'Invalid game address')]
fn test_unit_mint_invalid_game_address() {
    let user1 = contract_address_const::<'user1'>();
    let invalid_game = contract_address_const::<'invalid_game'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    set_caller_address(user1);
    token.mint(
        Option::Some(invalid_game),
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
}

// UT-M-06: Start > end
#[test]
#[should_panic(expected: 'Invalid lifecycle')]
fn test_unit_mint_invalid_lifecycle() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    set_caller_address(user1);
    token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::Some(1000),
        Option::Some(100),  // end < start
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
}

// UT-M-07: Past start time
#[test]
fn test_unit_mint_past_start_time() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    set_caller_address(user1);
    set_block_timestamp(2000);
    
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::Some(1000),  // past timestamp
        Option::Some(3000),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    assert!(token.is_playable(token_id), "Token should be immediately playable");
}

// UT-M-08: Future times
#[test]
fn test_unit_mint_future_times() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    set_caller_address(user1);
    set_block_timestamp(1000);
    
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::Some(2000),  // future start
        Option::Some(3000),  // future end
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    assert!(!token.is_playable(token_id), "Token should not yet be playable");
}

// UT-M-09: Max objectives (255)
#[test]
fn test_unit_mint_max_objectives() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    let mut objectives = array![];
    let mut i = 1_u32;
    loop {
        if i > 255 {
            break;
        }
        objectives.append(i);
        i += 1;
    };
    
    set_caller_address(user1);
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(objectives.span()),
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    let metadata = token.token_metadata(token_id);
    assert!(metadata.objectives_count == 255, "Should handle 255 objectives");
}

// UT-M-10: Over max objectives
#[test]
#[should_panic(expected: 'Too many objectives')]
fn test_unit_mint_over_max_objectives() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    let mut objectives = array![];
    let mut i = 1_u32;
    loop {
        if i > 256 {
            break;
        }
        objectives.append(i);
        i += 1;
    };
    
    set_caller_address(user1);
    token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(objectives.span()),
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
}

// UT-M-11: Soulbound flag
#[test]
fn test_unit_mint_soulbound() {
    let user1 = contract_address_const::<'user1'>();
    let user2 = contract_address_const::<'user2'>();
    let (token, erc721) = deploy_mock_token(Option::None);
    
    set_caller_address(user1);
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
        true  // soulbound
    );
    
    let metadata = token.token_metadata(token_id);
    assert!(metadata.soulbound == true, "Soulbound flag not set");
    
    // Test that transfer would fail (requires soulbound extension implementation)
    // This would need the soulbound extension to be active to test properly
}

// UT-M-12: Empty player name
#[test]
fn test_unit_mint_empty_player_name() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    set_caller_address(user1);
    let token_id = token.mint(
        Option::None,
        Option::Some(""),  // empty name
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
    
    assert!(token.player_name(token_id) == "", "Empty player name not stored");
}

// UT-M-13: Max length name
#[test]
fn test_unit_mint_max_length_name() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    // Create a 256 character name
    let long_name = "A very long player name that contains exactly 256 characters to test the maximum length handling of player names in the token contract. This name should be stored and retrieved correctly without any truncation or errors occurring during the mint process or subsequent queries. Total: 256!";
    
    set_caller_address(user1);
    let token_id = token.mint(
        Option::None,
        Option::Some(long_name),
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
    
    assert!(token.player_name(token_id) == long_name, "Long player name not stored correctly");
}

// UT-M-14: Sequential IDs
#[test]
fn test_unit_mint_sequential_ids() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    set_caller_address(user1);
    
    let token_id1 = token.mint(
        Option::None, Option::None, Option::None, Option::None, Option::None,
        Option::None, Option::None, Option::None, Option::None, user1, false
    );
    
    let token_id2 = token.mint(
        Option::None, Option::None, Option::None, Option::None, Option::None,
        Option::None, Option::None, Option::None, Option::None, user1, false
    );
    
    let token_id3 = token.mint(
        Option::None, Option::None, Option::None, Option::None, Option::None,
        Option::None, Option::None, Option::None, Option::None, user1, false
    );
    
    assert!(token_id1 == 1, "First token ID should be 1");
    assert!(token_id2 == 2, "Second token ID should be 2");
    assert!(token_id3 == 3, "Third token ID should be 3");
}

// Test event emissions
#[test]
fn test_unit_mint_events() {
    let user1 = contract_address_const::<'user1'>();
    let game_address = deploy_mock_minigame();
    let (token, _) = deploy_mock_token(Option::Some(game_address));
    
    let mut spy = spy_events();
    
    set_caller_address(user1);
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
    
    spy.assert_emitted(@array![
        (
            token.contract_address,
            TokenComponent::Event::TokenMinted(
                TokenComponent::TokenMinted {
                    token_id,
                    to: user1,
                    game_address
                }
            )
        )
    ]);
}

// =============================================================================
// UPDATE GAME TESTS
// =============================================================================

// Helper to setup a token ready for update_game tests
fn setup_playable_token() -> (IMinigameTokenDispatcher, ContractAddress, u64) {
    let user1 = contract_address_const::<'user1'>();
    let game_address = deploy_mock_minigame();
    let (token, _) = deploy_mock_token(Option::Some(game_address));
    
    set_caller_address(user1);
    set_block_timestamp(1000);
    
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::Some(500),   // past start time
        Option::Some(2000),  // future end time
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    (token, game_address, token_id)
}

// UT-U-01: Happy path update
#[test]
fn test_unit_update_game_happy_path() {
    let user1 = contract_address_const::<'user1'>();
    let (token, game_address, token_id) = setup_playable_token();
    
    // Set some game state
    let mock_game_dispatcher = IMockMinigameDispatcher { contract_address: game_address };
    mock_game_dispatcher.set_score(token_id, 100);
    
    set_caller_address(user1);
    let mut spy = spy_events();
    
    token.update_game(token_id);
    
    // Verify events
    spy.assert_emitted(@array![
        (
            token.contract_address,
            TokenComponent::Event::ScoreUpdate(
                TokenComponent::ScoreUpdate {
                    token_id,
                    score: 100
                }
            )
        ),
        (
            token.contract_address,
            TokenComponent::Event::MetadataUpdate(
                TokenComponent::MetadataUpdate {
                    token_id
                }
            )
        )
    ]);
}

// UT-U-02: Non-owner update
#[test]
#[should_panic(expected: 'Caller is not owner of token')]
fn test_unit_update_game_non_owner() {
    let user2 = contract_address_const::<'user2'>();
    let (token, _, token_id) = setup_playable_token();
    
    set_caller_address(user2);
    token.update_game(token_id);
}

// UT-U-03: Expired token
#[test]
#[should_panic(expected: 'Token 1 is not playable')]
fn test_unit_update_game_expired_token() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _, token_id) = setup_playable_token();
    
    set_caller_address(user1);
    set_block_timestamp(2001); // Past end time
    
    token.update_game(token_id);
}

// UT-U-04: Not started token
#[test]
#[should_panic(expected: 'Token 1 is not playable')]
fn test_unit_update_game_not_started() {
    let user1 = contract_address_const::<'user1'>();
    let game_address = deploy_mock_minigame();
    let (token, _) = deploy_mock_token(Option::Some(game_address));
    
    set_caller_address(user1);
    set_block_timestamp(1000);
    
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::Some(2000),  // future start
        Option::Some(3000),  // future end
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    set_block_timestamp(1500); // Before start time
    token.update_game(token_id);
}

// UT-U-05: Game over token
#[test]
#[should_panic(expected: 'Token 1 is not playable')]
fn test_unit_update_game_already_over() {
    let user1 = contract_address_const::<'user1'>();
    let (token, game_address, token_id) = setup_playable_token();
    
    // Set game over
    let mock_game_dispatcher = IMockMinigameDispatcher { contract_address: game_address };
    mock_game_dispatcher.set_game_over(token_id, true);
    
    set_caller_address(user1);
    token.update_game(token_id); // First update marks game as over
    
    // Try to update again
    token.update_game(token_id); // Should panic
}

// UT-U-06: Score increase
#[test]
fn test_unit_update_game_score_increase() {
    let user1 = contract_address_const::<'user1'>();
    let (token, game_address, token_id) = setup_playable_token();
    
    let mock_game_dispatcher = IMockMinigameDispatcher { contract_address: game_address };
    
    set_caller_address(user1);
    
    // Initial update
    mock_game_dispatcher.set_score(token_id, 10);
    token.update_game(token_id);
    
    // Update with higher score
    mock_game_dispatcher.set_score(token_id, 50);
    let mut spy = spy_events();
    token.update_game(token_id);
    
    spy.assert_emitted(@array![
        (
            token.contract_address,
            TokenComponent::Event::ScoreUpdate(
                TokenComponent::ScoreUpdate {
                    token_id,
                    score: 50
                }
            )
        )
    ]);
}

// UT-U-07: Game over trigger
#[test]
fn test_unit_update_game_over_trigger() {
    let user1 = contract_address_const::<'user1'>();
    let (token, game_address, token_id) = setup_playable_token();
    
    let mock_game_dispatcher = IMockMinigameDispatcher { contract_address: game_address };
    mock_game_dispatcher.set_score(token_id, 100);
    mock_game_dispatcher.set_game_over(token_id, true);
    
    set_caller_address(user1);
    token.update_game(token_id);
    
    let metadata = token.token_metadata(token_id);
    assert!(metadata.game_over == true, "Game over not set in metadata");
    assert!(!token.is_playable(token_id), "Token should not be playable after game over");
}

// UT-U-10: Non-existent token
#[test]
#[should_panic(expected: 'Token id 999 not minted')]
fn test_unit_update_game_non_existent_token() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _, _) = setup_playable_token();
    
    set_caller_address(user1);
    token.update_game(999);
}

// Interface for mock minigame contract
#[starknet::interface]
trait IMockMinigame<TContractState> {
    fn set_score(ref self: TContractState, token_id: u64, score: u64);
    fn set_game_over(ref self: TContractState, token_id: u64, game_over: bool);
}

#[derive(Copy, Drop, Serde)]
struct IMockMinigameDispatcher {
    contract_address: ContractAddress,
}

impl IMockMinigameDispatcherImpl of IMockMinigameDispatcherTrait {
    fn set_score(self: IMockMinigameDispatcher, token_id: u64, score: u64) {
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        score.serialize(ref calldata);
        starknet::syscalls::call_contract_syscall(
            self.contract_address,
            selector!("set_score"),
            calldata.span()
        ).unwrap();
    }
    
    fn set_game_over(self: IMockMinigameDispatcher, token_id: u64, game_over: bool) {
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        game_over.serialize(ref calldata);
        starknet::syscalls::call_contract_syscall(
            self.contract_address,
            selector!("set_game_over"),
            calldata.span()
        ).unwrap();
    }
}

// =============================================================================
// QUERY TESTS
// =============================================================================

// UT-Q-01: Valid token metadata
#[test]
fn test_unit_query_valid_token_metadata() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _, token_id) = setup_playable_token();
    
    let metadata = token.token_metadata(token_id);
    assert!(metadata.lifecycle.start == 500, "Start time mismatch");
    assert!(metadata.lifecycle.end == 2000, "End time mismatch");
    assert!(metadata.game_over == false, "Game over should be false");
    assert!(metadata.soulbound == false, "Soulbound should be false");
}

// UT-Q-02: Invalid token ID
#[test]
#[should_panic(expected: 'Token not found')]
fn test_unit_query_invalid_token_id() {
    let (token, _, _) = setup_playable_token();
    token.token_metadata(999);
}

// UT-Q-03: Token ID 0
#[test]
#[should_panic(expected: 'Invalid ID')]
fn test_unit_query_token_id_zero() {
    let (token, _, _) = setup_playable_token();
    token.token_metadata(0);
}

// UT-Q-04: Playability check
#[test]
fn test_unit_query_playability_various_states() {
    let user1 = contract_address_const::<'user1'>();
    let game_address = deploy_mock_minigame();
    let (token, _) = deploy_mock_token(Option::Some(game_address));
    
    set_caller_address(user1);
    set_block_timestamp(1000);
    
    // Active token
    let active_token = token.mint(
        Option::None, Option::None, Option::None,
        Option::Some(500), Option::Some(2000),
        Option::None, Option::None, Option::None, Option::None,
        user1, false
    );
    assert!(token.is_playable(active_token), "Active token should be playable");
    
    // Not started token
    let not_started = token.mint(
        Option::None, Option::None, Option::None,
        Option::Some(2000), Option::Some(3000),
        Option::None, Option::None, Option::None, Option::None,
        user1, false
    );
    assert!(!token.is_playable(not_started), "Not started token should not be playable");
    
    // Expired token
    let expired = token.mint(
        Option::None, Option::None, Option::None,
        Option::Some(100), Option::Some(500),
        Option::None, Option::None, Option::None, Option::None,
        user1, false
    );
    assert!(!token.is_playable(expired), "Expired token should not be playable");
    
    // No lifecycle bounds
    let no_bounds = token.mint(
        Option::None, Option::None, Option::None,
        Option::None, Option::None,
        Option::None, Option::None, Option::None, Option::None,
        user1, false
    );
    assert!(token.is_playable(no_bounds), "Token with no bounds should be playable");
}

// UT-Q-05: Settings ID query
#[test]
fn test_unit_query_settings_id() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    set_caller_address(user1);
    let token_id = token.mint(
        Option::None, Option::None,
        Option::Some(42),  // settings_id
        Option::None, Option::None,
        Option::None, Option::None, Option::None, Option::None,
        user1, false
    );
    
    assert!(token.settings_id(token_id) == 42, "Settings ID mismatch");
}

// UT-Q-06: Player name query
#[test]
fn test_unit_query_player_name() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_mock_token(Option::None);
    
    set_caller_address(user1);
    let token_id = token.mint(
        Option::None,
        Option::Some("Test Player"),
        Option::None, Option::None, Option::None,
        Option::None, Option::None, Option::None, Option::None,
        user1, false
    );
    
    assert!(token.player_name(token_id) == "Test Player", "Player name mismatch");
}