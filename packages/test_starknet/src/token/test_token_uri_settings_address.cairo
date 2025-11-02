use game_components_test_starknet::minigame::mocks::minigame_starknet_mock::{
    IMinigameStarknetMockDispatcherTrait, IMinigameStarknetMockInitDispatcherTrait,
};
use game_components_token::interface::IMinigameTokenMixinDispatcherTrait;
use openzeppelin_token::erc721::interface::{
    IERC721MetadataDispatcher, IERC721MetadataDispatcherTrait,
};

// setup helpers
use super::setup::{
    ALICE, OWNER, ZERO_ADDRESS, deploy_full_token_contract, deploy_minigame_registry_contract,
    deploy_mock_game,
};

// ================================================================================================
// TOKEN_URI TESTS - Settings Address Zero Check Fix
// ================================================================================================

/// Test that token_uri works correctly when settings_address is zero (the fix)
/// This test verifies the bug fix where we check if settings_address is zero
/// before attempting a contract call, preventing panics
#[test]
fn test_token_uri_with_zero_settings_address() {
    let registry = deploy_minigame_registry_contract();

    // Deploy mock game and initialize it with ZERO_ADDRESS for settings_address
    let (minigame_dispatcher, minigame_init_dispatcher, minigame_mock_dispatcher) =
        deploy_mock_game();

    // Deploy token contract with registry first (needed for game initialization)
    let (token_dispatcher, _erc721_dispatcher, _, token_address) = deploy_full_token_contract(
        Option::Some("TestToken"),
        Option::Some("TT"),
        Option::Some("https://test.com/"),
        Option::None, // royalty_receiver
        Option::Some(0), // royalty_fraction
        Option::Some(registry.contract_address),
        Option::None // event_relayer_address
    );

    // Initialize the mock game with zero settings_address to simulate the bug scenario
    // game will auto-register during initialization
    minigame_init_dispatcher
        .initializer(
            OWNER(), // game_creator
            "TestGame", // game_name
            "A test game", // game_description
            "Dev", // game_developer
            "Pub", // game_publisher
            "Action", // game_genre
            "", // game_image
            Option::None, // game_color
            Option::None, // client_url
            Option::None, // renderer_address (not needed for this test)
            Option::Some(ZERO_ADDRESS()), // settings_address - zero address
            Option::None, // objectives_address
            token_address // minigame_token_address
        );

    // Mint a token with the game
    let token_id = token_dispatcher
        .mint(
            Option::Some(minigame_dispatcher.contract_address),
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_ids
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            false // soulbound
        );

    // Set score for the token using end_game
    minigame_mock_dispatcher.end_game(token_id, 100);

    let erc721_metadata = IERC721MetadataDispatcher {
        contract_address: token_dispatcher.contract_address,
    };

    // Before the fix, this would attempt to call a contract at zero address and panic
    // After the fix, it should return default settings_details without panicking
    let token_uri = erc721_metadata.token_uri(token_id.into());

    // Verify that token_uri was generated successfully (non-empty)
    // The exact content depends on the implementation, but it should not be empty
    assert!(token_uri.len() > 0, "Token URI should not be empty");
}
