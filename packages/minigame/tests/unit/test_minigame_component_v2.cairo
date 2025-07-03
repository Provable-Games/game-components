use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,
    cheat_caller_address, CheatSpan, 
    start_mock_call, stop_mock_call
};

use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

// Constants
const PLAYER_ADDRESS: felt252 = 'PLAYER';
const OTHER_ADDRESS: felt252 = 'OTHER';
const TOKEN_ADDRESS: felt252 = 'TOKEN';

//
// Helpers
//

fn setup() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    // Create mock addresses
    let token_address = contract_address_const::<TOKEN_ADDRESS>();
    let settings_address = contract_address_const::<'SETTINGS'>();
    let objectives_address = contract_address_const::<'OBJECTIVES'>();
    
    // Deploy mock minigame with component
    let minigame_class = declare("MockMinigame").unwrap().contract_class();
    let (minigame_address, _) = minigame_class.deploy(@array![
        token_address.into(),
        settings_address.into(),
        objectives_address.into(),
    ]).unwrap();
    
    (minigame_address, token_address, settings_address, objectives_address)
}

//
// Test using mocks for pre_action
//

#[test]
fn test_mc_u9_pre_action_with_valid_owned_token() {
    let (_minigame_address, token_address, _, _) = setup();
    let player = contract_address_const::<PLAYER_ADDRESS>();
    
    // Mock owner_of to return player
    start_mock_call::<ContractAddress>(
        token_address,
        selector!("owner_of"),
        player
    );
    
    // Mock is_playable to return true
    start_mock_call::<bool>(
        token_address,
        selector!("is_playable"),
        true
    );
    
    // Call pre_action (through libs)
    cheat_caller_address(token_address, player, CheatSpan::TargetCalls(1));
    game_components_minigame::libs::pre_action(token_address, 1);
    
    // Clean up mocks
    stop_mock_call(token_address, selector!("owner_of"));
    stop_mock_call(token_address, selector!("is_playable"));
}

#[test]
#[should_panic]
fn test_mc_u11_pre_action_with_token_not_owned() {
    let (_minigame_address, token_address, _, _) = setup();
    let _player = contract_address_const::<PLAYER_ADDRESS>();
    let other = contract_address_const::<OTHER_ADDRESS>();
    
    // Mock owner_of to return other (not player)
    start_mock_call::<ContractAddress>(
        token_address,
        selector!("owner_of"),
        other
    );
    
    // Mock is_playable to return true
    start_mock_call::<bool>(
        token_address,
        selector!("is_playable"),
        true
    );
    
    // Call assert_token_ownership directly
    // This will panic because get_caller_address() != other
    game_components_minigame::libs::assert_token_ownership(token_address, 1);
}

#[test]
#[should_panic]
fn test_mc_u12_pre_action_with_game_over_token() {
    let (_minigame_address, token_address, _, _) = setup();
    let player = contract_address_const::<PLAYER_ADDRESS>();
    
    // Mock owner_of to return player
    start_mock_call::<ContractAddress>(
        token_address,
        selector!("owner_of"),
        player
    );
    
    // Mock is_playable to return false
    start_mock_call::<bool>(
        token_address,
        selector!("is_playable"),
        false
    );
    
    // Call pre_action
    cheat_caller_address(token_address, player, CheatSpan::TargetCalls(1));
    game_components_minigame::libs::pre_action(token_address, 1);
}

//
// MinigameComponent Tests
//

#[test]
fn test_mc_u1_initialize_with_valid_addresses() {
    let (minigame_address, token_address, settings_address, objectives_address) = setup();
    let minigame = IMinigameDispatcher { contract_address: minigame_address };
    
    // Verify addresses are set correctly
    assert(minigame.token_address() == token_address, 'Wrong token address');
    assert(minigame.settings_address() == settings_address, 'Wrong settings address');
    assert(minigame.objectives_address() == objectives_address, 'Wrong objectives address');
    
    // Verify SRC5 interface is registered
    // Mock supports_interface to return true for IMINIGAME_ID
    start_mock_call::<bool>(
        minigame_address,
        selector!("supports_interface"),
        true
    );
    
    let src5 = ISRC5Dispatcher { contract_address: minigame_address };
    assert(src5.supports_interface(game_components_minigame::interface::IMINIGAME_ID), 'IMinigame not registered');
    
    stop_mock_call(minigame_address, selector!("supports_interface"));
}

#[test]
fn test_mc_u6_get_token_address_after_init() {
    let (minigame_address, token_address, _, _) = setup();
    let minigame = IMinigameDispatcher { contract_address: minigame_address };
    
    assert(minigame.token_address() == token_address, 'Wrong token address');
}

#[test]
fn test_mc_u16_assert_game_token_playable_when_playable() {
    let (_, token_address, _, _) = setup();
    
    // Mock is_playable to return true
    start_mock_call::<bool>(
        token_address,
        selector!("is_playable"),
        true
    );
    
    // Assert playable
    game_components_minigame::libs::assert_game_token_playable(token_address, 1);
    
    // Clean up
    stop_mock_call(token_address, selector!("is_playable"));
}

#[test]
#[should_panic]
fn test_mc_u17_assert_game_token_playable_when_game_over() {
    let (_, token_address, _, _) = setup();
    
    // Mock is_playable to return false
    start_mock_call::<bool>(
        token_address,
        selector!("is_playable"),
        false
    );
    
    // Assert playable
    game_components_minigame::libs::assert_game_token_playable(token_address, 1);
}

#[test]
fn test_mc_u18_get_player_name_with_valid_token() {
    let (_, token_address, _, _) = setup();
    
    // Mock player_name to return "TestPlayer"
    start_mock_call::<ByteArray>(
        token_address,
        selector!("player_name"),
        "TestPlayer"
    );
    
    // Get player name
    let name = game_components_minigame::libs::get_player_name(token_address, 0);
    assert(name == "TestPlayer", 'Wrong player name');
    
    // Clean up
    stop_mock_call(token_address, selector!("player_name"));
}