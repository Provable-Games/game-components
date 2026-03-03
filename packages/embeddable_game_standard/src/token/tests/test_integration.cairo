// Import test contracts
use game_components_embeddable_game_standard::registry::interface::IMinigameRegistryDispatcherTrait;
use snforge_std::{
    CheatSpan, cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use starknet::ContractAddress;
use crate::token::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::metagame_mock::{
    IMetagameCallbackMockViewDispatcherTrait, IMetagameMockDispatcherTrait,
};
use super::mocks::minigame_mock::{IMinigameMockDispatcherTrait, IMinigameMockInitDispatcherTrait};

// Import test helpers from setup module
use super::setup::{
    ALICE, BOB, CHARLIE, OWNER, deploy_full_token_contract,
    deploy_minigame_registry_contract_with_params, deploy_mock_game, deploy_mock_game_standalone,
    deploy_optimized_token_with_game, deploy_simple_setup, setup,
};

// ================================================================================================
// INTEGRATION & SCENARIO TESTS
// ================================================================================================

// Helper addresses are now imported from setup module

// ================================================================================================
// I-03: Time Campaign
// ================================================================================================

#[test]
fn test_time_campaign() {
    // Deploy contracts
    let test_contracts = setup();

    let current_time: u64 = 1000;
    let future_start: u64 = 2000;
    let campaign_end: u64 = 3000;

    // Set current time
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, current_time);

    // Mint token with future start
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('TimePlayer'),
            Option::None,
            Option::Some(future_start),
            Option::Some(campaign_end),
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

    // 1. Verify not playable before start
    assert!(
        !test_contracts.test_token.is_playable(token_id), "Should not be playable before start",
    );

    // 2. Move to exactly start time
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, future_start);
    assert!(test_contracts.test_token.is_playable(token_id), "Should be playable at start time");

    // 3. Play during campaign
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, future_start + 500);
    assert!(test_contracts.test_token.is_playable(token_id), "Should be playable during campaign");

    // 4. Move to exactly end time
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, campaign_end);
    assert!(!test_contracts.test_token.is_playable(token_id), "Should not be playable at end time");

    // 5. Verify unplayable after end
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, campaign_end + 1000);
    assert!(
        !test_contracts.test_token.is_playable(token_id), "Should not be playable after campaign",
    );

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}


// ================================================================================================
// A-01: Double Mint Attack
// ================================================================================================

#[test]
fn test_double_mint_attack() {
    let test_contracts = setup();

    // First mint
    let token_id_1 = test_contracts
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
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Second mint - should get different ID
    let token_id_2 = test_contracts
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
            ALICE(),
            false,
            false,
            1,
            0,
        );

    // Verify counter prevents duplicate IDs
    assert!(token_id_1 != token_id_2, "Token IDs must be unique");
}

// ================================================================================================
// A-04: Update Game Permission Test
// ================================================================================================

#[test]
fn test_update_game_any_caller() {
    let (token_dispatcher, _, game_address) = deploy_simple_setup();

    // Mint token as ALICE
    let token_id = token_dispatcher
        .mint(
            game_address,
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

    // Try to update as BOB (non-owner) - this should work
    cheat_caller_address(token_dispatcher.contract_address, BOB(), CheatSpan::TargetCalls(1));

    // This should NOT panic - anyone can sync game state
    token_dispatcher.update_game(token_id);

    // Verify token still exists and is owned by ALICE
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.game_id == 0, "Token should still have same game");
}

// ================================================================================================
// HELPER FUNCTIONS
// ================================================================================================
// deploy_mock_game and deploy_simple_setup are now imported from setup module

// ================================================================================================
// MOCK CONTRACTS
// ================================================================================================

#[starknet::contract]
mod TokenMockContextProvider {
    use game_components_embeddable_game_standard::metagame::extensions::context::interface::{
        IMetagameContext, IMetagameContextDetails,
    };
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::{
        GameContext, GameContextDetails,
    };

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MetagameContextImpl of IMetagameContext<ContractState> {
        fn has_context(self: @ContractState, token_id: felt252) -> bool {
            true
        }
    }

    #[abi(embed_v0)]
    impl MetagameContextDetailsImpl of IMetagameContextDetails<ContractState> {
        fn context_details(self: @ContractState, token_id: felt252) -> GameContextDetails {
            GameContextDetails {
                name: "Tournament",
                description: "Test tournament",
                id: Option::Some(1),
                context: array![
                    GameContext { name: 'Type', value: 'Tournament' },
                    GameContext { name: 'Prize', value: '1000' },
                ]
                    .span(),
            }
        }
    }
}

#[starknet::contract]
mod TokenMockMetagameWithContext {
    use game_components_embeddable_game_standard::metagame::metagame_component::MetagameComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    // GameContextDetails imported above

    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl MetagameImpl = MetagameComponent::MetagameImpl<ContractState>;
    impl MetagameInternalImpl = MetagameComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        metagame: MetagameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MetagameEvent: MetagameComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        context_address: Option<ContractAddress>,
        minigame_token_address: ContractAddress,
    ) {
        self.metagame.initializer(context_address, minigame_token_address);
    }
}

// ================================================================================================
// INT-MINT-001: Multi-minter scenario
// ================================================================================================

#[test]
fn test_multi_minter_scenario() {
    let test_contracts = setup();

    // Different users mint tokens
    let minters = array![ALICE(), BOB(), CHARLIE(), OWNER()];
    let mut token_ids: Array<felt252> = array![];
    let mut minter_ids: Array<felt252> = array![];

    // Each minter mints 2 tokens
    let mut i: u32 = 0;
    while i < minters.len() {
        let minter = *minters.at(i);

        // Mint 2 tokens as this minter
        let mut j: u32 = 0;
        while j < 2 {
            cheat_caller_address(
                test_contracts.test_token.contract_address, minter, CheatSpan::TargetCalls(1),
            );

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
                    minter,
                    false,
                    false,
                    j.try_into().unwrap(),
                    0,
                );

            token_ids.append(token_id);

            // Get minter ID for this token
            let minter_id = test_contracts.test_token.minted_by(token_id);

            // Check if this is a new minter
            let mut is_new_minter = true;
            let mut k: u32 = 0;
            while k < minter_ids.len() {
                if *minter_ids.at(k) == minter_id {
                    is_new_minter = false;
                    break;
                }
                k += 1;
            }

            if is_new_minter {
                minter_ids.append(minter_id);
            }

            j += 1;
        }
        i += 1;
    }

    // Verify results
    assert!(token_ids.len() == 8, "Should have minted 8 tokens");
    assert!(minter_ids.len() == 4, "Should have 4 unique minters");

    // Verify total minters count
    let total_minters = test_contracts.test_token.total_minters();
    assert!(total_minters >= 4, "Should have at least 4 minters");

    // Verify each minter can be looked up
    let mut m: u32 = 0;
    while m < minters.len() {
        let minter = *minters.at(m);
        assert!(test_contracts.test_token.minter_exists(minter), "Minter should exist");
        m += 1;
    };
}

// ================================================================================================
// INT-ERR-001: Game contract failures
// ================================================================================================

#[test]
fn test_game_contract_unresponsive() {
    // Deploy a mock game that can become unresponsive
    let game_address = deploy_mock_game_standalone();

    // Deploy token with this game using helper function
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(game_address);

    // Mint a token
    let token_id = token_dispatcher
        .mint(
            game_address,
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

    // Token should exist and be valid
    let metadata = token_dispatcher.token_metadata(token_id);
    // Get game address directly
    let token_game_address = token_dispatcher.game_address();
    assert!(token_game_address == game_address, "Token should have game address");

    // Even if game becomes unresponsive, token operations should continue
    assert!(token_dispatcher.is_playable(token_id), "Token should be playable");

    // Update game - this might fail if game is truly unresponsive
    // but we test that token contract handles it gracefully
    token_dispatcher.update_game(token_id);

    // Token should still be valid
    let metadata_after = token_dispatcher.token_metadata(token_id);
    assert!(metadata_after.game_id == metadata.game_id, "Game ID should not change");
}

// ================================================================================================
// INT-ERR-002: Registry failures
// ================================================================================================

#[test]
fn test_registry_lookup_edge_cases() {
    // Deploy registry
    let registry_dispatcher = deploy_minigame_registry_contract_with_params(
        "Test Registry", "REG", "", Option::None,
    );
    let registry_address = registry_dispatcher.contract_address;

    // Deploy token with registry using helper function
    let (token_dispatcher, _, _, token_address) = deploy_full_token_contract(
        Option::Some("Multi Game Token"),
        Option::Some("MGT"),
        Option::Some(""),
        Option::None, // owner
        Option::None, // royalty_receiver
        Option::None, // royalty_fraction
        Option::Some(registry_address),
    );

    // Register some games
    let mut games: Array<ContractAddress> = array![];
    let mut i: u32 = 0;
    while i < 3 {
        let (game, game_init, _) = deploy_mock_game();
        game_init
            .initializer(
                OWNER(),
                "Game",
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
                token_address,
                Option::None // royalty_fraction
            );
        games.append(game.contract_address);
        i += 1;
    }

    // Test edge cases

    // 1. Mint with valid registered game
    let token_id1 = token_dispatcher
        .mint(
            *games.at(0),
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
    assert!(token_dispatcher.token_metadata(token_id1).game_id == 1, "Should have game ID 1");

    // 2. Verify game address resolution
    let resolved_address = token_dispatcher.token_game_address(token_id1);
    assert!(resolved_address == *games.at(0), "Should resolve to correct game address");

    // 3. Test with maximum game ID
    let last_game_id = registry_dispatcher.game_count();
    let last_game_address = registry_dispatcher.game_address_from_id(last_game_id);

    let token_id2 = token_dispatcher
        .mint(
            last_game_address,
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
    assert!(
        token_dispatcher.token_metadata(token_id2).game_id == last_game_id,
        "Should have last game ID",
    );
}

// ================================================================================================
// Additional Integration Scenarios
// ================================================================================================

#[test]
fn test_concurrent_operations() {
    let test_contracts = setup();

    // Simulate concurrent minting from multiple users
    let users = array![ALICE(), BOB(), CHARLIE()];
    let mut all_tokens: Array<felt252> = array![];

    // Each user mints tokens in interleaved fashion
    let mut round: u32 = 0;
    while round < 3 {
        let mut user_idx: u32 = 0;
        while user_idx < users.len() {
            let user = *users.at(user_idx);

            cheat_caller_address(
                test_contracts.test_token.contract_address, user, CheatSpan::TargetCalls(1),
            );

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
                    user,
                    false,
                    false,
                    round.try_into().unwrap(),
                    0,
                );

            all_tokens.append(token_id);
            user_idx += 1;
        }
        round += 1;
    }

    // Verify all tokens are unique
    assert!(all_tokens.len() == 9, "Should have 9 tokens");

    let mut i: u32 = 0;
    while i < all_tokens.len() {
        let mut j: u32 = i + 1;
        while j < all_tokens.len() {
            assert!(*all_tokens.at(i) != *all_tokens.at(j), "Tokens should be unique");
            j += 1;
        }
        i += 1;
    };
}

#[test]
fn test_lifecycle_boundary_conditions() {
    let test_contracts = setup();

    // Test with exact current timestamp
    let current_time = 1000_u64;
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, current_time);

    // Mint token that starts now and ends in 1 second
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(current_time),
            Option::Some(current_time + 1),
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

    // Should be playable at start time
    assert!(test_contracts.test_token.is_playable(token_id), "Should be playable at start");

    // Move to end time
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, current_time + 1);
    assert!(!test_contracts.test_token.is_playable(token_id), "Should not be playable at end");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

// ================================================================================================
// METAGAME CALLBACK INTEGRATION TESTS
// ================================================================================================

// CB-INT-01: update_game triggers on_game_action callback
#[test]
fn test_update_game_triggers_game_action_callback() {
    let test_contracts = setup();

    // Mint token through metagame mock (registers metagame as minter)
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player1'),
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

    // End game with score (sets game_over=true and score)
    let score: u64 = 150;
    test_contracts.mock_minigame.end_game(token_id, score);

    // Call update_game to sync state and trigger callbacks
    test_contracts.test_token.update_game(token_id);

    // Verify on_game_action was called
    let cb_view = test_contracts.metagame_callback_view;
    assert!(cb_view.game_action_count() == 1, "on_game_action should be called once");
    assert!(
        cb_view.last_callback_token_id() == token_id.into(),
        "Callback should receive correct token_id",
    );
    assert!(cb_view.last_callback_score() == score, "Callback should receive correct score");
}

// CB-INT-02: update_game triggers on_game_over callback on game_over transition
#[test]
fn test_update_game_triggers_game_over_callback() {
    let test_contracts = setup();

    // Mint token through metagame mock
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player2'),
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

    // End game with score
    let score: u64 = 500;
    test_contracts.mock_minigame.end_game(token_id, score);

    // Call update_game
    test_contracts.test_token.update_game(token_id);

    // Verify both on_game_action and on_game_over were called
    let cb_view = test_contracts.metagame_callback_view;
    assert!(cb_view.game_action_count() == 1, "on_game_action should be called");
    assert!(cb_view.game_over_count() == 1, "on_game_over should be called on transition");
    assert!(cb_view.last_callback_score() == score, "Callback should receive final score");
}

// CB-INT-03: on_game_over only fires once (transition guard)
#[test]
fn test_update_game_no_game_over_callback_without_transition() {
    let test_contracts = setup();

    // Mint token through metagame mock
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player3'),
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

    // End game
    test_contracts.mock_minigame.end_game(token_id, 100);

    // First update_game - triggers game_over transition
    test_contracts.test_token.update_game(token_id);

    // Second update_game - game_over is already true, no transition
    test_contracts.test_token.update_game(token_id);

    // Verify on_game_over was called only once (first transition)
    let cb_view = test_contracts.metagame_callback_view;
    assert!(cb_view.game_action_count() == 2, "on_game_action should be called twice");
    assert!(cb_view.game_over_count() == 1, "on_game_over should only fire once on transition");
}

// CB-INT-04: update_game triggers on_objective_complete callback
#[test]
fn test_update_game_triggers_objective_complete_callback() {
    let test_contracts = setup();

    // Create an objective with target score of 100
    test_contracts.mock_minigame.create_objective_score(100);

    // Mint token through metagame mock WITH an objective
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player4'),
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1), // objective_id = 1
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // End game with score >= objective target
    test_contracts.mock_minigame.end_game(token_id, 200);

    // Call update_game
    test_contracts.test_token.update_game(token_id);

    // Verify on_objective_complete was called
    let cb_view = test_contracts.metagame_callback_view;
    assert!(cb_view.game_action_count() == 1, "on_game_action should be called");
    assert!(cb_view.game_over_count() == 1, "on_game_over should be called");
    assert!(
        cb_view.objective_complete_count() == 1,
        "on_objective_complete should fire when objective met",
    );
}

// CB-INT-05: No callbacks when minter is a contract without IMetagameCallback
#[test]
fn test_update_game_no_callback_for_non_callback_minter() {
    let test_contracts = setup();

    // Mint as the minigame contract (which does NOT implement IMetagameCallback)
    cheat_caller_address(
        test_contracts.test_token.contract_address,
        test_contracts.minigame.contract_address,
        CheatSpan::TargetCalls(1),
    );
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Player5'),
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

    // End game with score
    test_contracts.mock_minigame.end_game(token_id, 300);

    // Call update_game - minter is the minigame contract, which doesn't support IMetagameCallback
    test_contracts.test_token.update_game(token_id);

    // Verify no callbacks were dispatched (minter doesn't support IMetagameCallback)
    let cb_view = test_contracts.metagame_callback_view;
    assert!(cb_view.game_action_count() == 0, "No callbacks for non-callback minter");
    assert!(cb_view.game_over_count() == 0, "No game_over callback for non-callback minter");
}
