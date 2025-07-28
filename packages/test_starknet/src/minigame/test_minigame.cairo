use starknet::{ContractAddress, contract_address_const};
use super::mocks::minigame_starknet_mock::{
    IMinigameStarknetMockDispatcherTrait, IMinigameStarknetMockInitDispatcherTrait,
};
use crate::token::setup::{deploy_mock_game, deploy_optimized_token_with_game};

// Test constants
const GAME_CREATOR: felt252 = 'creator';
pub fn GAME_NAME() -> ByteArray {
    "TestGame"
}
pub fn GAME_DEVELOPER() -> ByteArray {
    "developer"
}
pub fn GAME_PUBLISHER() -> ByteArray {
    "publisher"
}
pub fn GAME_GENRE() -> ByteArray {
    "strategy"
}
const GAME_NAMESPACE: felt252 = 'test_namespace';
const PLAYER_NAME: felt252 = 'player1';
const PLAYER_ADDRESS: felt252 = 'player_addr';
const TOKEN_ADDRESS: felt252 = 'token_addr';

#[test]
fn test_mint_basic() {
    // Deploy mock game first
    let (minigame_dispatcher, minigame_init_dispatcher, mock_dispatcher) = deploy_mock_game();

    // Deploy token contract with the game address
    let (_token_dispatcher, _, _, token_address) = deploy_optimized_token_with_game(
        minigame_dispatcher.contract_address,
    );

    // Initialize minigame with token address
    minigame_init_dispatcher
        .initializer(
            contract_address_const::<GAME_CREATOR>(), // game_creator
            GAME_NAME(), // game_name
            "Test Game Description", // game_description
            GAME_DEVELOPER(), // game_developer
            GAME_PUBLISHER(), // game_publisher
            GAME_GENRE(), // game_genre
            "https://example.com/image.png", // game_image
            Option::<ByteArray>::None, // game_color
            Option::<ByteArray>::None, // client_url
            Option::<ContractAddress>::None, // renderer_address
            Option::Some(
                minigame_dispatcher.contract_address,
            ), // settings_address (self-reference for mock)
            Option::Some(
                minigame_dispatcher.contract_address,
            ), // objectives_address (self-reference for mock)
            token_address // token_address
        );

    let player_addr = contract_address_const::<PLAYER_ADDRESS>();

    let token_id = mock_dispatcher
        .mint(
            Option::Some(PLAYER_NAME),
            Option::None, // no settings
            Option::None, // no start time
            Option::None, // no end time
            Option::None, // no objectives
            Option::None, // no context
            Option::None, // no client_url
            Option::None, // no renderer_address
            player_addr,
            false // not soulbound
        );

    assert!(token_id > 0, "Token ID should be greater than 0");
}
