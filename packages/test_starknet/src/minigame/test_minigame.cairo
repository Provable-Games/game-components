use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use super::mocks::minigame_starknet_mock::{
    IMinigameStarknetMockDispatcher, IMinigameStarknetMockDispatcherTrait,
    IMinigameStarknetMockInitDispatcher, IMinigameStarknetMockInitDispatcherTrait,
};
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;

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

fn deploy_minigame_starknet_mock() -> ContractAddress {
    let contract = declare("minigame_starknet_mock").unwrap().contract_class();

    // Deploy with empty constructor calldata since the contract doesn't have a constructor
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    // Initialize the contract using the initializer function
    let initializer = IMinigameStarknetMockInitDispatcher { contract_address };
    initializer
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
            Option::Some(contract_address), // settings_address (self-reference for mock)
            Option::Some(contract_address), // objectives_address (self-reference for mock)
            contract_address_const::<TOKEN_ADDRESS>() // token_address
        );

    contract_address
}

#[test]
fn test_mint_basic() {
    let contract_address = deploy_minigame_starknet_mock();
    let mock = IMinigameStarknetMockDispatcher { contract_address };
    let player_addr = contract_address_const::<PLAYER_ADDRESS>();

    let token_id = mock
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
