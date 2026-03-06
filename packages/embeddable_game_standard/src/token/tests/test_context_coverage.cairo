// Tests for context extension coverage
use starknet::ContractAddress;

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
use snforge_std::{EventSpyTrait, spy_events};
use crate::token::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::metagame_mock::IMetagameMockDispatcherTrait;
use super::setup::{ALICE, BOB, setup};

#[test]
fn test_context_extension_operations() {
    let test_contracts = setup();

    // Mint a token without context first
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Player1'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None, // No context
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Check metadata - should not have context
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(!metadata.has_context, "Token minted without context should not have context flag");
}

#[test]
fn test_context_through_metagame() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Mint through metagame which supports context
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('ContextualPlayer'),
            Option::None, // No settings_id
            Option::Some(1000), // start
            Option::Some(2000), // end
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

    // Verify token was minted with context support
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.has_context, "Token minted through metagame should have context");

    // Check events
    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit events");
}

#[test]
fn test_multiple_context_mints() {
    let test_contracts = setup();

    // Mint multiple tokens through metagame
    let players = array![('Alice', ALICE()), ('Bob', BOB())];

    let mut token_ids: Array<felt252> = array![];
    let mut i = 0;

    while i < players.len() {
        let (name, address) = players.at(i);

        let token_id = test_contracts
            .metagame_mock
            .mint_game(
                Option::Some(test_contracts.minigame.contract_address),
                Option::Some(name.clone()),
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                *address,
                false,
                false,
                i.try_into().unwrap(),
                0,
            );

        token_ids.append(token_id);
        i += 1;
    }

    // Verify all tokens have context
    let mut j = 0;
    while j < token_ids.len() {
        let token_id = *token_ids.at(j);
        let metadata = test_contracts.test_token.token_metadata(token_id);
        assert!(metadata.has_context, "All metagame minted tokens should have context");
        j += 1;
    };
}

#[test]
fn test_context_with_game_lifecycle() {
    let test_contracts = setup();

    // Mint with specific lifecycle through metagame
    let start_time = 5000_u64;
    let end_time = 10000_u64;

    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('TimedPlayer'),
            Option::None,
            Option::Some(start_time),
            Option::Some(end_time),
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

    // Verify lifecycle is set correctly
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.lifecycle.start == start_time, "Start time should match");
    assert!(metadata.lifecycle.end == end_time, "End time should match");
    assert!(metadata.has_context, "Should have context");
}

#[test]
fn test_context_with_soulbound() {
    let test_contracts = setup();

    // Mint soulbound token through metagame
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('SoulboundPlayer'),
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

    // Verify token is soulbound and has context
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.soulbound, "Token should be soulbound");
    assert!(metadata.has_context, "Token should have context");
    assert!(test_contracts.test_token.is_soulbound(token_id), "is_soulbound should return true");
}

#[test]
fn test_context_extension_edge_cases() {
    let test_contracts = setup();

    // Test with empty player name
    let token_id1 = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None, // No player name
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

    // Test with all parameters
    let token_id2 = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('FullPlayer'),
            Option::None, // No settings
            Option::Some(1000), // start
            Option::Some(2000), // end
            Option::None, // No objectives
            Option::Some("https://client.url"), // client URL
            Option::Some(addr('RENDERER')),
            Option::None, // renderer
            BOB(),
            false,
            false,
            1,
            0,
        );

    // Verify both tokens have context
    assert!(
        test_contracts.test_token.token_metadata(token_id1).has_context,
        "Token 1 should have context",
    );
    assert!(
        test_contracts.test_token.token_metadata(token_id2).has_context,
        "Token 2 should have context",
    );

    // Verify other metadata
    assert!(test_contracts.test_token.player_name(token_id1) == '', "Empty player name");
    assert!(test_contracts.test_token.player_name(token_id2) == 'FullPlayer', "Full player name");
    assert!(test_contracts.test_token.objective_id(token_id2) == 0, "Should have no objective");
}
