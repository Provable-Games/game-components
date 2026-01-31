use starknet::ContractAddress;

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
use openzeppelin_interfaces::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use snforge_std::{
    CheatSpan, cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use crate::interface::{IMinigameTokenMixinDispatcher, IMinigameTokenMixinDispatcherTrait};
use crate::structs::PlayerNameUpdate;
use super::mocks::mock_game::IMockGameDispatcherTrait;

// Import setup helpers
use super::setup::{
    ALICE, BOB, CURRENT_TIME, FUTURE_TIME, OWNER, deploy_basic_mock_game,
    deploy_minimal_optimized_contract,
};

// Deploy helper
fn deploy_minimal_token() -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ContractAddress) {
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let game_addr = minigame_dispatcher.contract_address;
    let (token, erc721) = deploy_minimal_optimized_contract(
        "MinimalToken",
        "MIN",
        "https://minimal.test/",
        Option::Some(game_addr),
        Option::Some(game_addr),
    );
    (token, erc721, game_addr)
}

#[test]
fn test_minimal_contract_deployment() {
    let (token_dispatcher, _erc721_dispatcher, _game_addr) = deploy_minimal_token();

    // Verify basic token interface is working
    // Note: The minimal contract may not expose all metadata functions
    // Let's just verify the contract was deployed correctly
    assert!(token_dispatcher.contract_address != addr(0), "Contract should be deployed");
}

#[test]
fn test_minimal_contract_minting() {
    let (token_dispatcher, erc721_dispatcher, game_addr) = deploy_minimal_token();

    // Mint a token with minimal parameters
    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    // Verify token was minted
    assert!(token_id != 0, "Token ID should be nonzero");
    assert!(
        erc721_dispatcher.owner_of(token_id.into()) == ALICE(), "Token should be owned by ALICE",
    );
    assert!(erc721_dispatcher.balance_of(ALICE()) == 1, "Balance should be 1");
}

#[test]
fn test_minimal_contract_minter_tracking() {
    let (token_dispatcher, _, game_addr) = deploy_minimal_token();

    // Mint tokens from different addresses
    cheat_caller_address(token_dispatcher.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    let token_id1 = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    cheat_caller_address(token_dispatcher.contract_address, BOB(), CheatSpan::TargetCalls(1));
    let token_id2 = token_dispatcher
        .mint(
            game_addr,
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
            false,
            1,
            0,
        );

    // Verify minter tracking
    assert!(token_dispatcher.minter_exists(ALICE()), "ALICE should be a minter");
    assert!(token_dispatcher.minter_exists(BOB()), "BOB should be a minter");
    assert!(token_dispatcher.total_minters() >= 2, "Should have at least 2 minters");

    // Verify minted_by
    let minter_id1 = token_dispatcher.minted_by(token_id1);
    let minter_id2 = token_dispatcher.minted_by(token_id2);
    assert!(minter_id1 != minter_id2, "Different minters should have different IDs");
}

#[test]
fn test_minimal_contract_transfers() {
    let (token_dispatcher, erc721_dispatcher, game_addr) = deploy_minimal_token();

    // Mint a token
    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    // Transfer token
    cheat_caller_address(token_dispatcher.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721_dispatcher.transfer_from(ALICE(), BOB(), token_id.into());

    // Verify transfer
    assert!(erc721_dispatcher.owner_of(token_id.into()) == BOB(), "Token should be owned by BOB");
    assert!(erc721_dispatcher.balance_of(ALICE()) == 0, "ALICE balance should be 0");
    assert!(erc721_dispatcher.balance_of(BOB()) == 1, "BOB balance should be 1");
}


#[test]
fn test_minimal_contract_token_metadata() {
    let (token_dispatcher, _, game_addr) = deploy_minimal_token();

    // Mint a token
    let token_id = token_dispatcher
        .mint(
            game_addr,
            Option::Some('MinimalPlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Check metadata
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.minted_by > 0, "Should have minter ID");
    assert!(metadata.game_id == 0, "No game ID in minimal contract");
    assert!(!metadata.soulbound, "Should not be soulbound");

    // Check player name
    assert!(token_dispatcher.player_name(token_id) == 'MinimalPlayer', "Player name should be set");
}

// ============================================================================
// Deploy helper using MockGame (supports SRC5/IMinigame)
// ============================================================================

fn deploy_minimal_token_with_mock_game() -> (
    IMinigameTokenMixinDispatcher,
    ERC721ABIDispatcher,
    super::mocks::mock_game::IMockGameDispatcher,
    ContractAddress,
) {
    let (minigame_dispatcher, mock_game) = deploy_basic_mock_game();
    let game_addr = minigame_dispatcher.contract_address;
    let (token_dispatcher, erc721_dispatcher) = deploy_minimal_optimized_contract(
        "MinimalToken",
        "MIN",
        "https://minimal.test/",
        Option::Some(game_addr),
        Option::Some(OWNER()),
    );
    (token_dispatcher, erc721_dispatcher, mock_game, game_addr)
}

// ============================================================================
// BATCH VIEW TESTS FOR MINIMAL CONTRACT
// ============================================================================

#[test]
fn test_minimal_is_playable_batch() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.is_playable_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0), "Token should be playable");
}

#[test]
fn test_minimal_settings_id_batch() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.settings_id_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
}

#[test]
fn test_minimal_player_name_batch() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
            Option::Some('BatchMin'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.player_name_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) == 'BatchMin', "Player name should match");
}

#[test]
fn test_minimal_objective_id_batch() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.objective_id_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
}

#[test]
fn test_minimal_minted_by_batch() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.minted_by_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) != 0, "Minted by should be non-zero");
}

#[test]
fn test_minimal_is_soulbound_batch() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            true, // soulbound
            false,
            0,
            0,
        );

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.is_soulbound_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0), "Token should be soulbound");
}

#[test]
fn test_minimal_renderer_address_batch() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.renderer_address_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
}

#[test]
fn test_minimal_token_game_address_batch() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.token_game_address_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
}

// ============================================================================
// PLAYER NAME VIEW (line 147)
// ============================================================================

#[test]
fn test_minimal_player_name_view() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
            Option::Some('MinView'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let name = token_dispatcher.player_name(token_id);
    assert!(name == 'MinView', "Player name should match");
}

// ============================================================================
// RENDERER ADDRESS (lines 180, 182) - single game mode fallback
// ============================================================================

#[test]
fn test_minimal_renderer_address_single_game() {
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let game_addr = minigame_dispatcher.contract_address;
    let (token_dispatcher, _) = deploy_minimal_optimized_contract(
        "MinimalToken",
        "MIN",
        "https://minimal.test/",
        Option::Some(game_addr),
        Option::Some(OWNER()),
    );

    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    // renderer_address in single-game mode with NoOpRenderer returns game_address
    let renderer = token_dispatcher.renderer_address(token_id);
    assert!(
        renderer == minigame_dispatcher.contract_address,
        "Renderer should fallback to game address",
    );
}

// ============================================================================
// UPDATE GAME (lines 610, 614, 615)
// ============================================================================

#[test]
fn test_minimal_update_game() {
    let (token_dispatcher, _, mock_game, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    mock_game.set_score(token_id, 100);
    mock_game.set_game_over(token_id, true);

    token_dispatcher.update_game(token_id);

    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.game_over, "Game should be over");
}

#[test]
fn test_minimal_update_game_batch() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    let token_ids: Array<felt252> = array![token_id];
    token_dispatcher.update_game_batch(token_ids.span());
}

// ============================================================================
// UPDATE PLAYER NAME (lines 725-734, 761-762, 1090)
// ============================================================================

#[test]
fn test_minimal_update_player_name() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
            Option::Some('OrigMin'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    cheat_caller_address(token_dispatcher.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    token_dispatcher.update_player_name(token_id, 'NewMin');

    assert!(token_dispatcher.player_name(token_id) == 'NewMin', "Name should be updated");
}

#[test]
fn test_minimal_update_player_name_batch() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id1 = token_dispatcher
        .mint(
            game_addr,
            Option::Some('Old1'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let token_id2 = token_dispatcher
        .mint(
            game_addr,
            Option::Some('Old2'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            1,
            0,
        );

    cheat_caller_address(token_dispatcher.contract_address, ALICE(), CheatSpan::TargetCalls(2));
    let updates: Array<PlayerNameUpdate> = array![
        PlayerNameUpdate { token_id: token_id1, name: 'NewBatch1' },
        PlayerNameUpdate { token_id: token_id2, name: 'NewBatch2' },
    ];
    token_dispatcher.update_player_name_batch(updates.span());

    assert!(token_dispatcher.player_name(token_id1) == 'NewBatch1', "Name 1 should be updated");
    assert!(token_dispatcher.player_name(token_id2) == 'NewBatch2', "Name 2 should be updated");
}

// ============================================================================
// MINT with future start (lines 856, 859)
// ============================================================================

#[test]
fn test_minimal_mint_with_future_start() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    start_cheat_block_timestamp(token_dispatcher.contract_address, CURRENT_TIME);

    let token_id = token_dispatcher
        .mint(
            game_addr,
            Option::None,
            Option::None,
            Option::Some(FUTURE_TIME),
            Option::Some(FUTURE_TIME + 5000),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(!token_dispatcher.is_playable(token_id), "Should not be playable before start");

    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.lifecycle.start == FUTURE_TIME, "Start should be future");

    stop_cheat_block_timestamp(token_dispatcher.contract_address);
}

// ============================================================================
// MINT game token with player name + client url (lines 941, 947)
// ============================================================================

#[test]
fn test_minimal_mint_game_token_with_player_name_and_url() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
            Option::Some('NamedMin'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some("https://min.game.com"),
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let name = token_dispatcher.player_name(token_id);
    assert!(name == 'NamedMin', "Player name should be set");
}

// ============================================================================
// INITIALIZER (lines 791-831) - verified through constructor
// ============================================================================

#[test]
fn test_minimal_initializer_stores_game_address() {
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, erc721_dispatcher) = deploy_minimal_optimized_contract(
        "MinimalToken",
        "MIN",
        "https://minimal.test/",
        Option::Some(minigame_dispatcher.contract_address),
        Option::Some(OWNER()),
    );

    // Verify game_address is set
    let game_addr = token_dispatcher.game_address();
    assert!(game_addr == minigame_dispatcher.contract_address, "Game address should be set");

    // Verify token 0 exists (minted to creator in initializer)
    let owner_of_zero = erc721_dispatcher.owner_of(0);
    assert!(owner_of_zero == OWNER(), "Token 0 should be owned by creator");
}

// ============================================================================
// VALIDATE_AND_PROCESS_GAME_ADDRESS (lines 1029-1032) and
// RESOLVE_GAME_ADDRESS (lines 1056, 1060)
// ============================================================================

#[test]
fn test_minimal_token_game_address() {
    let (token_dispatcher, _, _, game_addr) = deploy_minimal_token_with_mock_game();

    let token_id = token_dispatcher
        .mint(
            game_addr,
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
            false,
            0,
            0,
        );

    // token_game_address calls resolve_game_address (line 1056, 1060)
    let game_addr = token_dispatcher.token_game_address(token_id);
    let stored_game_addr = token_dispatcher.game_address();
    assert!(game_addr == stored_game_addr, "Game address should match stored address");
}
