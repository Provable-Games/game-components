use openzeppelin_interfaces::erc721::ERC721ABIDispatcherTrait;
use snforge_std::{
    CheatSpan, EventSpyAssertionsTrait, EventSpyTrait, cheat_caller_address, spy_events,
};
use starknet::ContractAddress;
use crate::token::interface::{IMinigameTokenMixinDispatcher, IMinigameTokenMixinDispatcherTrait};
use crate::token::token_component::CoreTokenComponent;
use super::mocks::minigame_mock::IMinigameMockInitDispatcherTrait;

// Import IMockGameDispatcher trait
use super::mocks::mock_game::{IMockGameDispatcher, IMockGameDispatcherTrait};

// Import test helpers from setup module
use super::setup::{
    ALICE, BOB, OWNER, deploy_basic_mock_game, deploy_mock_game, deploy_optimized_token_with_game,
    setup, setup_multi_game,
};

// ================================================================================================
// EVENT EMISSION TESTS
// ================================================================================================

#[test]
fn test_mint_event_emission() {
    let test_contracts = setup();
    let mut _spy = spy_events();

    // Mint a token
    let _token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Player1'),
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
}

#[test]
fn test_update_game_event_emissions() {
    let _test_contracts = setup();
    let (minigame, mock_game) = deploy_basic_mock_game();

    // Deploy token contract with mock game
    let (token_dispatcher, _, _, token_address) = deploy_optimized_token_with_game(
        minigame.contract_address,
    );

    // Mint a token
    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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
            false,
            0,
            0,
        );

    // Start spying after mint to focus on update events
    let mut spy = spy_events();

    // Update game state
    mock_game.set_score(token_id, 100);
    token_dispatcher.update_game(token_id);

    // Should emit MetadataUpdate event
    let events = spy.get_events();

    // Verify we have at least 1 event (MetadataUpdate)
    assert!(events.events.span().len() >= 1, "Should emit at least 1 event");

    // Check for MetadataUpdate event from token contract
    let mut found_metadata_update = false;

    let mut i: u32 = 0;
    while i < events.events.span().len() {
        let (contract_address, _event) = events.events.at(i);
        if *contract_address == token_address {
            found_metadata_update = true;
        }
        i += 1;
    }

    assert!(found_metadata_update, "Should emit MetadataUpdate event");
}

#[test]
fn test_update_game_with_metadata_change_events() {
    let _test_contracts = setup();
    let (minigame, mock_game) = deploy_basic_mock_game();

    // Deploy token contract
    let (token_dispatcher, _, _, _token_address) = deploy_optimized_token_with_game(
        minigame.contract_address,
    );

    // Mint token
    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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
            false,
            0,
            0,
        );

    // Set game as completed
    mock_game.set_game_over(token_id, true);

    let mut spy = spy_events();
    token_dispatcher.update_game(token_id);

    // Should emit MetadataUpdate when game state changes
    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit at least 1 event when metadata changes");
}

#[test]
fn test_mint_with_context_event() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Use test token to mint (metagame doesn't have mint_game method)
    let _token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Player1'),
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

    // Should emit events
    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit mint events");
}

#[test]
fn test_transfer_events() {
    let test_contracts = setup();

    // Mint a non-soulbound token
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    let mut spy = spy_events();

    // Transfer token
    cheat_caller_address(
        test_contracts.erc721.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.erc721.transfer_from(ALICE(), BOB(), token_id.into());

    // Should emit Transfer event
    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit Transfer event");
}

#[test]
fn test_batch_operations_event_count() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Mint multiple tokens
    let mut token_ids: Array<felt252> = array![];
    let mut i: u32 = 0;
    while i < 3 {
        let token_id = test_contracts
            .test_token
            .mint(
                test_contracts.minigame.contract_address,
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
                false,
                i.try_into().unwrap(),
                0,
            );
        token_ids.append(token_id);
        i += 1;
    }

    // Should emit 3 TokenMinted events
    let events = spy.get_events();
    assert!(events.events.span().len() >= 3, "Should emit event for each mint");
}


#[test]
fn test_multi_game_registry_events() {
    let test_contracts = setup_multi_game();
    let mut spy = spy_events();

    // Deploy and register a new game
    let (game, game_init, _) = deploy_mock_game();
    game_init
        .initializer(
            OWNER(),
            "New Game",
            "Description",
            "Developer",
            "Publisher",
            "Genre",
            "Image",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            test_contracts.test_token.contract_address,
            Option::None // royalty_fraction
        );

    // Mint token for new game
    let _token_id = test_contracts
        .test_token
        .mint(
            game.contract_address,
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
            false,
            0,
            0,
        );

    // Should emit TokenMinted with correct game_id
    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit TokenMinted event");
}

// ================================================================================================
// REFRESH_METADATA TESTS
// ================================================================================================

// Mints a token against a fresh mock game and returns (token dispatcher, mock game, token id).
fn setup_refresh_metadata() -> (
    IMinigameTokenMixinDispatcher, IMockGameDispatcher, ContractAddress, felt252,
) {
    let (minigame, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, token_address) = deploy_optimized_token_with_game(
        minigame.contract_address,
    );

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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
            false,
            0,
            0,
        );

    (token_dispatcher, mock_game, token_address, token_id)
}

#[test]
fn test_refresh_metadata_emits_metadata_update() {
    let (token_dispatcher, _mock_game, token_address, token_id) = setup_refresh_metadata();

    let mut spy = spy_events();
    token_dispatcher.refresh_metadata(token_id);

    spy
        .assert_emitted(
            @array![
                (
                    token_address,
                    CoreTokenComponent::Event::MetadataUpdate(
                        CoreTokenComponent::MetadataUpdate { token_id: token_id.into() },
                    ),
                ),
            ],
        );
}

// The whole point of the entrypoint: it must never persist game state. A game that is over
// on the game contract stays "not over" on the token until update_game is called, so
// refresh_metadata can never be substituted for the game-over sync.
#[test]
fn test_refresh_metadata_does_not_persist_game_state() {
    let (token_dispatcher, mock_game, _token_address, token_id) = setup_refresh_metadata();

    mock_game.set_score(token_id, 100);
    mock_game.set_game_over(token_id, true);

    token_dispatcher.refresh_metadata(token_id);

    let state = token_dispatcher.token_mutable_state(token_id);
    assert!(!state.game_over, "refresh_metadata must not persist game_over");
    assert!(!state.completed_objective, "refresh_metadata must not persist completed_objective");
    assert!(token_dispatcher.is_playable(token_id), "token should still be playable");

    // update_game is still the thing that syncs it.
    token_dispatcher.update_game(token_id);
    assert!(token_dispatcher.token_mutable_state(token_id).game_over, "update_game should sync");
}

#[test]
fn test_refresh_metadata_emits_only_one_event() {
    let (token_dispatcher, _mock_game, _token_address, token_id) = setup_refresh_metadata();

    let mut spy = spy_events();
    token_dispatcher.refresh_metadata(token_id);

    let events = spy.get_events();
    assert!(
        events.events.span().len() == 1,
        "refresh_metadata should emit exactly 1 event, got {}",
        events.events.span().len(),
    );
}

#[test]
#[should_panic]
fn test_refresh_metadata_nonexistent_token_panics() {
    let (token_dispatcher, _mock_game, _token_address, _token_id) = setup_refresh_metadata();

    token_dispatcher.refresh_metadata(999999);
}

#[test]
fn test_refresh_metadata_batch_emits_per_token() {
    let (minigame, _mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, token_address) = deploy_optimized_token_with_game(
        minigame.contract_address,
    );

    // Distinct salts, otherwise the packed token ids collide.
    let mut token_ids: Array<felt252> = array![];
    let mut salt: u16 = 0;
    while salt < 3 {
        token_ids
            .append(
                token_dispatcher
                    .mint(
                        minigame.contract_address,
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
                        false,
                        salt,
                        0,
                    ),
            );
        salt += 1;
    }

    let mut spy = spy_events();
    token_dispatcher.refresh_metadata_batch(token_ids.span());

    let events = spy.get_events();
    assert!(
        events.events.span().len() == 3,
        "should emit 1 event per token, got {}",
        events.events.span().len(),
    );

    spy
        .assert_emitted(
            @array![
                (
                    token_address,
                    CoreTokenComponent::Event::MetadataUpdate(
                        CoreTokenComponent::MetadataUpdate { token_id: (*token_ids.at(2)).into() },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_refresh_metadata_batch_empty_panics() {
    let (token_dispatcher, _mock_game, _token_address, _token_id) = setup_refresh_metadata();

    token_dispatcher.refresh_metadata_batch(array![].span());
}
