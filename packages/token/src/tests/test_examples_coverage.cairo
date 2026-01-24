// Tests for example contracts to improve coverage
use starknet::ContractAddress;

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
use snforge_std::{
    CheatSpan, cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use crate::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::metagame_starknet_mock::IMetagameStarknetMockDispatcherTrait;
use super::mocks::mock_game::IMockGameDispatcherTrait;
use super::setup::{
    ALICE, BOB, CHARLIE, deploy_basic_mock_game, deploy_optimized_token_with_game, setup,
};

// Test optimized token contract specific features
#[test]
fn test_optimized_contract_with_renderer() {
    let test_contracts = setup();
    let renderer_address = addr('RENDERER');

    // Mint token with custom renderer
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('RendererPlayer'),
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
            Option::Some('ContextPlayer'),
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_id
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
    }

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
            Option::Some('GamePlayer'),
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
