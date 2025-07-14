// Tests to improve core_token coverage
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, cheat_caller_address, CheatSpan,
    start_cheat_block_timestamp, stop_cheat_block_timestamp, spy_events, EventSpyTrait,
};

use crate::interface::{IMinigameTokenMixinDispatcher, IMinigameTokenMixinDispatcherTrait};
use openzeppelin_token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use crate::tests::test_optimized_token_contract::{
    setup, setup_multi_game, ALICE, BOB, CHARLIE, OWNER, ZERO_ADDRESS, deploy_mock_game,
    deploy_basic_mock_game,
};
use crate::tests::mocks::mock_game::{IMockGameDispatcher, IMockGameDispatcherTrait};
use crate::examples::minigame_registry_contract::{
    IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
};
use game_components_test_starknet::minigame::mocks::minigame_starknet_mock::{
    IMinigameStarknetMockDispatcher, IMinigameStarknetMockDispatcherTrait,
};

#[test]
fn test_core_token_edge_case_minting() {
    let test_contracts = setup();

    // Test minting with max values
    let max_u64 = 18446744073709551615_u64;
    let max_u32 = 4294967295_u32;

    // This should work with max timestamps
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some("MaxPlayer"),
            Option::None,
            Option::Some(0),
            Option::Some(max_u64),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.lifecycle.end == max_u64, "Max end time should be set");
}

#[test]
fn test_core_token_batch_operations() {
    let test_contracts = setup();

    // Batch mint tokens
    let batch_size: u32 = 5;
    let mut token_ids: Array<u64> = array![];
    let mut i: u32 = 0;

    while i < batch_size {
        let token_id = test_contracts
            .test_token
            .mint(
                Option::Some(test_contracts.minigame.contract_address),
                Option::Some("BatchPlayer"),
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
        token_ids.append(token_id);
        i += 1;
    };

    // Verify sequential IDs
    let mut j = 0;
    while j < token_ids.len() - 1 {
        let current = *token_ids.at(j);
        let next = *token_ids.at(j + 1);
        assert!(next == current + 1, "Token IDs should be sequential");
        j += 1;
    };

    // Batch update games
    let mut k = 0;
    while k < token_ids.len() {
        let token_id = *token_ids.at(k);
        test_contracts.mock_minigame.end_game(token_id, 50 + k);
        test_contracts.test_token.update_game(token_id);
        k += 1;
    };
}

#[test]
fn test_core_token_game_registry_operations() {
    let test_contracts = setup_multi_game();

    // Test registry address view
    let registry_address = test_contracts.test_token.game_registry_address();
    assert!(
        registry_address == test_contracts.minigame_registry.contract_address,
        "Registry address should match",
    );

    // Test game count
    let game_count = test_contracts.minigame_registry.game_count();
    assert!(game_count >= 2, "Should have at least 2 games registered");

    // Test game address resolution for tokens
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
            ALICE(),
            false,
        );

    let game_address = test_contracts.test_token.game_address(token_id);
    assert!(game_address == test_contracts.minigame.contract_address, "Game address should match");
}

#[test]
fn test_core_token_update_edge_cases() {
    let test_contracts = setup();
    let (_, mock_game) = deploy_basic_mock_game();

    // Deploy token with mock game
    let token_contract = declare("OptimizedTokenContract").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "UpdateTest";
    let symbol: ByteArray = "UT";
    let base_uri: ByteArray = "";

    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    base_uri.serialize(ref constructor_calldata);
    constructor_calldata.append(0); // Some(game_address)
    constructor_calldata.append(mock_game.contract_address.into());
    constructor_calldata.append(1); // None for registry

    let (token_address, _) = token_contract.deploy(@constructor_calldata).unwrap();
    let token_dispatcher = IMinigameTokenMixinDispatcher { contract_address: token_address };

    // Mint token
    let token_id = token_dispatcher
        .mint(
            Option::None,
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

    // Update with no changes
    token_dispatcher.update_game(token_id);
    let metadata1 = token_dispatcher.token_metadata(token_id);

    // Update again with no changes (idempotent)
    token_dispatcher.update_game(token_id);
    let metadata2 = token_dispatcher.token_metadata(token_id);

    // Metadata should be identical
    assert!(metadata1.game_over == metadata2.game_over, "Game over should not change");
    assert!(
        metadata1.completed_all_objectives == metadata2.completed_all_objectives,
        "Objectives should not change",
    );
}

#[test]
fn test_core_token_lifecycle_validation() {
    let test_contracts = setup();

    // Test various lifecycle combinations
    let current_time = 1000_u64;
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, current_time);

    // Valid lifecycle
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::Some(current_time),
            Option::Some(current_time + 1000),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // Zero end time (no expiry)
    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::Some(current_time),
            Option::Some(0),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
        );

    // Both zero (always playable)
    let token_id3 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::Some(0),
            Option::Some(0),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            CHARLIE(),
            false,
        );

    // Verify playability
    assert!(test_contracts.test_token.is_playable(token_id1), "Token 1 should be playable");
    assert!(test_contracts.test_token.is_playable(token_id2), "Token 2 should be playable");
    assert!(test_contracts.test_token.is_playable(token_id3), "Token 3 should be playable");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_core_token_blank_token_operations() {
    let test_contracts = setup();

    // Mint completely blank token
    let blank_token_id = test_contracts
        .test_token
        .mint(
            Option::None, // No game
            Option::None, // No player name
            Option::None, // No settings
            Option::None, // No start
            Option::None, // No end
            Option::None, // No objectives
            Option::None, // No context
            Option::None, // No client URL
            Option::None, // No renderer
            ALICE(),
            false,
        );

    // Set metadata on blank token
    test_contracts
        .test_token
        .set_token_metadata(
            blank_token_id,
            test_contracts.minigame.contract_address,
            Option::Some("UpdatedPlayer"),
            Option::Some(42),
            Option::Some(2000),
            Option::Some(3000),
            Option::Some(array![1, 2].span()),
            Option::None,
        );

    // Verify metadata was set
    let metadata = test_contracts.test_token.token_metadata(blank_token_id);
    assert!(metadata.settings_id == 42, "Settings should be set");
    assert!(metadata.lifecycle.start == 2000, "Start should be set");
    assert!(metadata.lifecycle.end == 3000, "End should be set");
    assert!(metadata.objectives_count == 2, "Should have 2 objectives");

    // Verify view functions
    assert!(
        test_contracts.test_token.player_name(blank_token_id) == "UpdatedPlayer",
        "Player name should be set",
    );
    assert!(
        test_contracts.test_token.settings_id(blank_token_id) == 42, "Settings ID should be set",
    );
    assert!(
        test_contracts.test_token.objectives_count(blank_token_id) == 2,
        "Objectives count should be 2",
    );
}

#[test]
fn test_core_token_event_emissions() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Mint token to trigger events
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some("EventPlayer"),
            Option::Some(10),
            Option::Some(1000),
            Option::Some(2000),
            Option::Some(array![1, 2, 3].span()),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            true // soulbound
        );

    // Get events
    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit events");

    // Update game to trigger more events
    test_contracts.mock_minigame.end_game(token_id, 100);
    test_contracts.test_token.update_game(token_id);

    // Check for update events
    let events_after = spy.get_events();
    assert!(
        events_after.events.len() > events.events.len(), "Should emit more events after update",
    );
}

#[test]
fn test_core_token_minter_edge_cases() {
    let test_contracts = setup();

    // Test minter operations with edge addresses
    let edge_addresses = array![
        contract_address_const::<0x1>(),
        contract_address_const::<
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        >(),
    ];

    let mut i = 0;
    while i < edge_addresses.len() {
        let address = *edge_addresses.at(i);

        cheat_caller_address(
            test_contracts.test_token.contract_address, address, CheatSpan::TargetCalls(1),
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
                address,
                false,
            );

        // Verify minter is tracked
        assert!(
            test_contracts.test_token.minter_exists(address),
            "Edge address should be tracked as minter",
        );

        let minter_id = test_contracts.test_token.minted_by(token_id);
        assert!(minter_id > 0, "Should have valid minter ID");

        let retrieved_address = test_contracts.test_token.get_minter_address(minter_id);
        assert!(retrieved_address == address, "Retrieved address should match");

        i += 1;
    };
}
