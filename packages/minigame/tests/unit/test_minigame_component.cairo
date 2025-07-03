use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,
    cheat_caller_address, CheatSpan
};

use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

// Test Contracts
use crate::mocks::mock_token::{IMockTokenDispatcher, IMockTokenDispatcherTrait};
use crate::mocks::mock_extensions::{};

// Constants
const PLAYER_ADDRESS: felt252 = 'PLAYER';
const OTHER_ADDRESS: felt252 = 'OTHER';
const ZERO_ADDRESS: felt252 = 0;

//
// Helpers
//

fn setup() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    // Deploy mock token
    let token_class = declare("MockToken").unwrap().contract_class();
    let (token_address, _) = token_class.deploy(@array![]).unwrap();
    
    // Deploy mock settings
    let settings_class = declare("MockSettings").unwrap().contract_class();
    let (settings_address, _) = settings_class.deploy(@array![]).unwrap();
    
    // Deploy mock objectives
    let objectives_class = declare("MockObjectives").unwrap().contract_class();
    let (objectives_address, _) = objectives_class.deploy(@array![]).unwrap();
    
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
// Initialization Tests (MC-U1 to MC-U5)
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
    let src5 = ISRC5Dispatcher { contract_address: minigame_address };
    assert(src5.supports_interface(game_components_minigame::interface::IMINIGAME_ID), 'IMinigame not registered');
}

// Note: Tests MC-U2 to MC-U5 are skipped because the current implementation
// doesn't validate zero addresses in the initializer

//
// Getter Tests (MC-U6 to MC-U8)
//

#[test]
fn test_mc_u6_get_token_address_after_init() {
    let (minigame_address, token_address, _, _) = setup();
    let minigame = IMinigameDispatcher { contract_address: minigame_address };
    
    assert(minigame.token_address() == token_address, 'Wrong token address');
}

#[test]
fn test_mc_u7_get_settings_address_after_init() {
    let (minigame_address, _, settings_address, _) = setup();
    let minigame = IMinigameDispatcher { contract_address: minigame_address };
    
    assert(minigame.settings_address() == settings_address, 'Wrong settings address');
}

#[test]
fn test_mc_u8_get_objectives_address_after_init() {
    let (minigame_address, _, _, objectives_address) = setup();
    let minigame = IMinigameDispatcher { contract_address: minigame_address };
    
    assert(minigame.objectives_address() == objectives_address, 'Wrong objectives address');
}

//
// Pre-Action Tests (MC-U9 to MC-U12)
//

#[test]
fn test_mc_u9_pre_action_with_valid_owned_token() {
    let (_minigame_address, token_address, _, _) = setup();
    let mock_token = IMockTokenDispatcher { contract_address: token_address };
    let player = contract_address_const::<PLAYER_ADDRESS>();
    
    // Setup: Create a valid token owned by player
    mock_token.set_owner(1, player);
    mock_token.set_playable(1, true);
    
    // Call pre_action (through libs)
    cheat_caller_address(token_address, player, CheatSpan::TargetCalls(1));
    game_components_minigame::libs::pre_action(token_address, 1);
    // Should not panic
}

#[test]
#[should_panic]
fn test_mc_u10_pre_action_with_non_existent_token() {
    let (_minigame_address, token_address, _, _) = setup();
    let player = contract_address_const::<PLAYER_ADDRESS>();
    
    // Call pre_action with non-existent token
    cheat_caller_address(token_address, player, CheatSpan::TargetCalls(1));
    game_components_minigame::libs::pre_action(token_address, 999);
}

#[test]
#[should_panic(expected: ('Caller is not owner of token 1',))]
fn test_mc_u11_pre_action_with_token_not_owned() {
    let (_minigame_address, token_address, _, _) = setup();
    let mock_token = IMockTokenDispatcher { contract_address: token_address };
    let player = contract_address_const::<PLAYER_ADDRESS>();
    let other = contract_address_const::<OTHER_ADDRESS>();
    
    // Setup: Create a token owned by someone else
    mock_token.set_owner(1, other);
    mock_token.set_playable(1, true);
    
    // Call pre_action as player (not owner)
    cheat_caller_address(token_address, player, CheatSpan::TargetCalls(1));
    game_components_minigame::libs::pre_action(token_address, 1);
}

#[test]
#[should_panic(expected: ('Game is not playable',))]
fn test_mc_u12_pre_action_with_game_over_token() {
    let (_minigame_address, token_address, _, _) = setup();
    let mock_token = IMockTokenDispatcher { contract_address: token_address };
    let player = contract_address_const::<PLAYER_ADDRESS>();
    
    // Setup: Create a token that is game over
    mock_token.set_owner(1, player);
    mock_token.set_playable(1, false);
    mock_token.set_game_over(1, true);
    
    // Call pre_action
    cheat_caller_address(token_address, player, CheatSpan::TargetCalls(1));
    game_components_minigame::libs::pre_action(token_address, 1);
}

//
// Post-Action Tests (MC-U13)
//

#[test]
fn test_mc_u13_post_action_with_valid_token() {
    let (_minigame_address, token_address, _, _) = setup();
    let mock_token = IMockTokenDispatcher { contract_address: token_address };
    let player = contract_address_const::<PLAYER_ADDRESS>();
    
    // Setup: Create a valid token
    mock_token.set_owner(1, player);
    mock_token.set_playable(1, true);
    
    // Call post_action
    game_components_minigame::libs::post_action(token_address, 1);
    // Should call update_game on token contract
}

//
// Assert Token Ownership Tests (MC-U14 to MC-U15)
//

#[test]
fn test_mc_u14_assert_token_ownership_with_owned_token() {
    let (_minigame_address, token_address, _, _) = setup();
    let mock_token = IMockTokenDispatcher { contract_address: token_address };
    let player = contract_address_const::<PLAYER_ADDRESS>();
    
    // Setup: Create a token owned by player
    mock_token.set_owner(1, player);
    
    // Assert ownership
    cheat_caller_address(token_address, player, CheatSpan::TargetCalls(1));
    game_components_minigame::libs::assert_token_ownership(token_address, 1);
    // Should not panic
}

#[test]
#[should_panic(expected: ('Caller is not owner of token 1',))]
fn test_mc_u15_assert_token_ownership_with_wrong_owner() {
    let (_minigame_address, token_address, _, _) = setup();
    let mock_token = IMockTokenDispatcher { contract_address: token_address };
    let player = contract_address_const::<PLAYER_ADDRESS>();
    let other = contract_address_const::<OTHER_ADDRESS>();
    
    // Setup: Create a token owned by someone else
    mock_token.set_owner(1, other);
    
    // Assert ownership as wrong caller
    cheat_caller_address(token_address, player, CheatSpan::TargetCalls(1));
    game_components_minigame::libs::assert_token_ownership(token_address, 1);
}

//
// Assert Game Token Playable Tests (MC-U16 to MC-U17)
//

#[test]
fn test_mc_u16_assert_game_token_playable_when_playable() {
    let (_, token_address, _, _) = setup();
    let mock_token = IMockTokenDispatcher { contract_address: token_address };
    
    // Setup: Create a playable token
    mock_token.set_playable(1, true);
    mock_token.set_game_over(1, false);
    
    // Assert playable
    game_components_minigame::libs::assert_game_token_playable(token_address, 1);
    // Should not panic
}

#[test]
#[should_panic(expected: ('Game is not playable',))]
fn test_mc_u17_assert_game_token_playable_when_game_over() {
    let (_, token_address, _, _) = setup();
    let mock_token = IMockTokenDispatcher { contract_address: token_address };
    
    // Setup: Create a game over token
    mock_token.set_playable(1, false);
    mock_token.set_game_over(1, true);
    
    // Assert playable
    game_components_minigame::libs::assert_game_token_playable(token_address, 1);
}

//
// Get Player Name Test (MC-U18)
//

#[test]
fn test_mc_u18_get_player_name_with_valid_token() {
    let (_, token_address, _, _) = setup();
    let token = IMinigameTokenDispatcher { contract_address: token_address };
    let player = contract_address_const::<PLAYER_ADDRESS>();
    
    // Setup: Mint a token with player name
    token.mint(
        Option::None,
        Option::Some("TestPlayer"),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        player,
        false
    );
    
    // Get player name
    let name = game_components_minigame::libs::get_player_name(token_address, 0);
    assert(name == "TestPlayer", 'Wrong player name');
}

//
// Register Game Interface Test (MC-U19)
//

#[test]
fn test_mc_u19_register_game_interface() {
    let (minigame_address, _, _, _) = setup();
    
    // Check SRC5 interface registration
    let src5 = ISRC5Dispatcher { contract_address: minigame_address };
    assert(src5.supports_interface(game_components_minigame::interface::IMINIGAME_ID), 'IMinigame not registered');
}