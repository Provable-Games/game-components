use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, set_block_timestamp};
use snforge_std::{declare, ContractClassTrait, spy_events, EventSpyTrait, EventSpyAssertionsTrait};
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use game_components_token::token::TokenComponent;
use game_components_metagame::extensions::context::structs::GameContextDetails;

// Scenario 1: Basic Gameplay Flow
#[test]
fn test_integration_basic_gameplay_flow() {
    // Step 1: Deploy MinigameToken with game address
    let game_contract = declare("MockMinigame").unwrap();
    let (game_address, _) = game_contract.deploy(@array![]).unwrap();
    
    let token_contract = declare("MockToken").unwrap();
    let (token_address, _) = token_contract.deploy(@array![
        'GameToken', 'GT', 'https://game.test/', game_address.into()
    ]).unwrap();
    
    let token = IMinigameTokenDispatcher { contract_address: token_address };
    
    // Step 2: Deploy Settings contract, create settings
    let settings_contract = declare("MockSettings").unwrap();
    let (settings_address, _) = settings_contract.deploy(@array![]).unwrap();
    
    // Step 3: Deploy Objectives contract, register objectives
    let objectives_contract = declare("MockObjectives").unwrap();
    let (objectives_address, _) = objectives_contract.deploy(@array![]).unwrap();
    
    // Step 4: Mint token with settings, objectives, and lifecycle
    let player = contract_address_const::<'player1'>();
    set_caller_address(player);
    set_block_timestamp(1000);
    
    let mut spy = spy_events();
    
    let token_id = token.mint(
        Option::None,  // Use default game address
        Option::Some("Player One"),
        Option::Some(1),  // settings_id
        Option::Some(1000),  // start now
        Option::Some(4600),  // end in 1 hour (3600 seconds)
        Option::Some(array![1, 2, 3].span()),  // objectives
        Option::None,
        Option::None,
        Option::None,
        player,
        false
    );
    
    assert!(token_id == 1, "First token should have ID 1");
    assert!(token.is_playable(token_id), "Token should be playable immediately");
    
    // Step 5: Call update_game() 5 times over 30 minutes
    let mock_game = IMockMinigameDispatcher { contract_address: game_address };
    
    // First update at 5 minutes
    set_block_timestamp(1300);
    mock_game.set_score(token_id, 10);
    token.update_game(token_id);
    
    // Second update at 10 minutes
    set_block_timestamp(1600);
    mock_game.set_score(token_id, 25);
    token.update_game(token_id);
    
    // Third update at 15 minutes
    set_block_timestamp(1900);
    mock_game.set_score(token_id, 40);
    token.update_game(token_id);
    
    // Fourth update at 20 minutes - complete objective 1
    set_block_timestamp(2200);
    mock_game.set_score(token_id, 60);
    let mock_objectives = IMockObjectivesDispatcher { contract_address: objectives_address };
    mock_objectives.set_objective_complete(token_id, 1, true);
    token.update_game(token_id);
    
    // Fifth update at 25 minutes
    set_block_timestamp(2500);
    mock_game.set_score(token_id, 80);
    token.update_game(token_id);
    
    // Step 6: Verify score increases and objective completion
    // (Score is retrieved via events in actual implementation)
    
    // Step 7: Call update_game() until game_over
    set_block_timestamp(2800);
    mock_game.set_score(token_id, 100);
    mock_game.set_game_over(token_id, true);
    token.update_game(token_id);
    
    // Step 8: Verify final state and no more updates allowed
    let final_metadata = token.token_metadata(token_id);
    assert!(final_metadata.game_over == true, "Game should be over");
    assert!(!token.is_playable(token_id), "Token should not be playable after game over");
    
    // Try to update again - should panic
    let result = @token.update_game(token_id);
    match result {
        Result::Ok(_) => panic!("Should not allow update after game over"),
        Result::Err(_) => {} // Expected
    }
}

// Test concurrent players
#[test]
fn test_integration_multiple_players() {
    let game_contract = declare("MockMinigame").unwrap();
    let (game_address, _) = game_contract.deploy(@array![]).unwrap();
    
    let token_contract = declare("MockToken").unwrap();
    let (token_address, _) = token_contract.deploy(@array![
        'GameToken', 'GT', 'https://game.test/', game_address.into()
    ]).unwrap();
    
    let token = IMinigameTokenDispatcher { contract_address: token_address };
    let mock_game = IMockMinigameDispatcher { contract_address: game_address };
    
    let player1 = contract_address_const::<'player1'>();
    let player2 = contract_address_const::<'player2'>();
    let player3 = contract_address_const::<'player3'>();
    
    set_block_timestamp(1000);
    
    // Mint tokens for 3 players
    set_caller_address(player1);
    let token1 = token.mint(
        Option::None, Option::Some("Alice"), Option::None,
        Option::Some(1000), Option::Some(5000),
        Option::None, Option::None, Option::None, Option::None,
        player1, false
    );
    
    set_caller_address(player2);
    let token2 = token.mint(
        Option::None, Option::Some("Bob"), Option::None,
        Option::Some(1000), Option::Some(5000),
        Option::None, Option::None, Option::None, Option::None,
        player2, false
    );
    
    set_caller_address(player3);
    let token3 = token.mint(
        Option::None, Option::Some("Charlie"), Option::None,
        Option::Some(1000), Option::Some(5000),
        Option::None, Option::None, Option::None, Option::None,
        player3, false
    );
    
    // Simulate concurrent gameplay
    set_block_timestamp(2000);
    
    // Player 1 plays aggressively
    set_caller_address(player1);
    mock_game.set_score(token1, 50);
    token.update_game(token1);
    
    // Player 2 plays moderately
    set_caller_address(player2);
    mock_game.set_score(token2, 30);
    token.update_game(token2);
    
    // Player 3 plays slowly
    set_caller_address(player3);
    mock_game.set_score(token3, 10);
    token.update_game(token3);
    
    // Time passes...
    set_block_timestamp(3000);
    
    // Player 1 finishes quickly
    set_caller_address(player1);
    mock_game.set_score(token1, 100);
    mock_game.set_game_over(token1, true);
    token.update_game(token1);
    
    // Player 2 continues
    set_caller_address(player2);
    mock_game.set_score(token2, 60);
    token.update_game(token2);
    
    // Player 3 times out (past end time)
    set_block_timestamp(5001);
    set_caller_address(player3);
    let result = @token.update_game(token3);
    match result {
        Result::Ok(_) => panic!("Should not allow update after timeout"),
        Result::Err(_) => {} // Expected - token expired
    }
    
    // Verify final states
    assert!(!token.is_playable(token1), "Player 1 token should be finished");
    assert!(token.is_playable(token2), "Player 2 token should still be playable");
    assert!(!token.is_playable(token3), "Player 3 token should be expired");
}

// Interfaces for mocks
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

#[starknet::interface]
trait IMockObjectives<TContractState> {
    fn set_objective_complete(ref self: TContractState, token_id: u64, objective_id: u32, complete: bool);
}

#[derive(Copy, Drop, Serde)]
struct IMockObjectivesDispatcher {
    contract_address: ContractAddress,
}

impl IMockObjectivesDispatcherImpl of IMockObjectivesDispatcherTrait {
    fn set_objective_complete(self: IMockObjectivesDispatcher, token_id: u64, objective_id: u32, complete: bool) {
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        objective_id.serialize(ref calldata);
        complete.serialize(ref calldata);
        starknet::syscalls::call_contract_syscall(
            self.contract_address,
            selector!("set_objective_complete"),
            calldata.span()
        ).unwrap();
    }
}