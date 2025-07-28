// Tests for example contracts to improve coverage
use starknet::{contract_address_const};
use snforge_std::{
    cheat_caller_address, CheatSpan, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};

use game_components_token::interface::{IMinigameTokenMixinDispatcherTrait};
use crate::token::setup::{
    setup, deploy_mock_game, deploy_basic_mock_game, deploy_optimized_token_with_game, ALICE, BOB,
    CHARLIE,
};
use crate::token::mocks::mock_game::{IMockGameDispatcherTrait};
use game_components_test_starknet::metagame::mocks::metagame_starknet_mock::{
    IMetagameStarknetMockDispatcherTrait,
};
use game_components_test_starknet::minigame::mocks::minigame_starknet_mock::{
    IMinigameStarknetMockInitDispatcherTrait,
};
use game_components_token::examples::minigame_registry_contract::{IMinigameRegistryDispatcherTrait};

// Test optimized token contract specific features
#[test]
fn test_optimized_contract_with_renderer() {
    let test_contracts = setup();
    let renderer_address = contract_address_const::<'RENDERER'>();

    // Mint token with custom renderer
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some("RendererPlayer"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(renderer_address),
            ALICE(),
            false,
        );

    // Verify renderer is set
    assert!(
        test_contracts.test_token.renderer_address(token_id) == renderer_address,
        "Renderer should be set",
    );
    assert!(test_contracts.test_token.has_custom_renderer(token_id), "Should have custom renderer");
}

#[test]
fn test_optimized_contract_lifecycle_edge_cases() {
    let test_contracts = setup();

    // Test with lifecycle exactly at current time
    let current_time = 1000_u64;
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, current_time);

    // Mint token that starts now and ends now (instant expiry)
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::Some(current_time),
            Option::Some(current_time),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // Should not be playable (end time equals current time)
    assert!(!test_contracts.test_token.is_playable(token_id), "Token should not be playable");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_optimized_contract_context_operations() {
    let test_contracts = setup();

    // Mint through metagame to test context
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some("ContextPlayer"),
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_ids
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            false,
        );

    // Verify token exists and has context flag
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.has_context, "Token should have context");
}

#[test]
fn test_optimized_contract_multi_minter_scenario() {
    let test_contracts = setup();

    // Multiple users mint in sequence
    let minters = array![ALICE(), BOB(), CHARLIE()];
    let mut token_ids: Array<u64> = array![];

    let mut i = 0;
    while i < minters.len() {
        let minter = *minters.at(i);
        cheat_caller_address(
            test_contracts.test_token.contract_address, minter, CheatSpan::TargetCalls(1),
        );

        let token_id = test_contracts
            .test_token
            .mint(
                Option::Some(test_contracts.minigame.contract_address),
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                minter,
                false,
            );

        token_ids.append(token_id);
        i += 1;
    };

    // Verify all minters are tracked
    assert!(test_contracts.test_token.total_minters() >= 3, "Should have at least 3 minters");

    // Verify each token has correct minter
    let mut j = 0;
    while j < token_ids.len() {
        let token_id = *token_ids.at(j);
        let minter_id = test_contracts.test_token.minted_by(token_id);
        assert!(minter_id > 0, "Should have valid minter ID");

        // Verify minter lookup
        let minter_address = test_contracts.test_token.get_minter_address(minter_id);
        assert!(minter_address == *minters.at(j), "Minter address should match");
        j += 1;
    };
}

#[test]
fn test_optimized_contract_game_integration() {
    let (_, mock_game) = deploy_basic_mock_game();

    // Deploy token with mock game
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(mock_game.contract_address);

    // Mint and play
    let token_id = token_dispatcher
        .mint(
            Option::None,
            Option::Some("GamePlayer"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // Update game state
    mock_game.set_score(token_id, 100);
    token_dispatcher.update_game(token_id);

    // Verify state updated
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(!metadata.game_over, "Game should not be over");

    // End game
    mock_game.set_game_over(token_id, true);
    token_dispatcher.update_game(token_id);

    // Verify game over
    let metadata_after = token_dispatcher.token_metadata(token_id);
    assert!(metadata_after.game_over, "Game should be over");
}

#[test]
fn test_registry_contract_game_management() {
    let test_contracts = setup();

    // Register additional games
    let (game2, game2_init, _) = deploy_mock_game();
    let (game3, game3_init, _) = deploy_mock_game();

    game2_init
        .initializer(
            ALICE(),
            "Game2",
            "Second Game",
            "Dev2",
            "Pub2",
            "Action",
            "image2.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            test_contracts.test_token.contract_address,
        );

    game3_init
        .initializer(
            BOB(),
            "Game3",
            "Third Game",
            "Dev3",
            "Pub3",
            "Puzzle",
            "image3.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            test_contracts.test_token.contract_address,
        );

    // Verify games are registered
    assert!(
        test_contracts.minigame_registry.is_game_registered(game2.contract_address),
        "Game2 should be registered",
    );
    assert!(
        test_contracts.minigame_registry.is_game_registered(game3.contract_address),
        "Game3 should be registered",
    );

    // Get game IDs
    let game2_id = test_contracts.minigame_registry.game_id_from_address(game2.contract_address);
    let game3_id = test_contracts.minigame_registry.game_id_from_address(game3.contract_address);

    // Verify game metadata
    let game2_meta = test_contracts.minigame_registry.game_metadata(game2_id);
    assert!(game2_meta.name == "Game2", "Game2 name should match");

    let game3_meta = test_contracts.minigame_registry.game_metadata(game3_id);
    assert!(game3_meta.name == "Game3", "Game3 name should match");

    // Mint tokens for different games
    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(game2.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    let token_id3 = test_contracts
        .test_token
        .mint(
            Option::Some(game3.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
        );

    // Verify tokens have correct game IDs
    let metadata2 = test_contracts.test_token.token_metadata(token_id2);
    let metadata3 = test_contracts.test_token.token_metadata(token_id3);

    assert!(metadata2.game_id == game2_id.into(), "Token2 should have game2 ID");
    assert!(metadata3.game_id == game3_id.into(), "Token3 should have game3 ID");
}
