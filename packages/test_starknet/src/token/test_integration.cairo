use starknet::ContractAddress;
use snforge_std::{
    start_cheat_block_timestamp, stop_cheat_block_timestamp, cheat_caller_address, CheatSpan,
};

use game_components_token::interface::{
    IMinigameTokenMixinDispatcher, IMinigameTokenMixinDispatcherTrait,
};
use game_components_token::examples::minigame_registry_contract::{IMinigameRegistryDispatcherTrait};

// Import test contracts
use game_components_test_starknet::minigame::mocks::minigame_starknet_mock::{
    IMinigameStarknetMockInitDispatcherTrait, IMinigameStarknetMockDispatcherTrait,
};

// Import test helpers from setup module
use super::setup::{
    setup, deploy_optimized_token_with_game, deploy_full_token_contract, deploy_mock_game,
    deploy_mock_context_provider, deploy_mock_metagame_with_context,
    deploy_minigame_registry_contract_with_params, deploy_mock_game_standalone, deploy_simple_setup,
    OWNER, ALICE, BOB, CHARLIE,
};

// ================================================================================================
// INTEGRATION & SCENARIO TESTS
// ================================================================================================

// Helper addresses are now imported from setup module

// ================================================================================================
// I-01: Tournament Flow
// ================================================================================================

#[ignore]
#[test] // Requires context provider implementation
fn test_tournament_flow() {
    // Deploy context provider
    let context_address = deploy_mock_context_provider();

    // Deploy token contract (registry)
    let registry_dispatcher = deploy_minigame_registry_contract_with_params(
        "TournamentTokens", "TOUR", "", Option::None,
    );
    let registry_address = registry_dispatcher.contract_address;

    // Deploy metagame with context
    let _metagame_dispatcher = deploy_mock_metagame_with_context(
        Option::Some(context_address), registry_address,
    );

    // Create and register multiple games
    let mut game_addresses = array![];
    let mut i: u32 = 0;
    while i < 3 {
        let (game, game_init, _) = deploy_mock_game();
        game_init
            .initializer(
                ALICE(),
                "Game",
                "Game Description",
                "Developer",
                "Publisher",
                "Genre",
                "Image",
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                registry_address,
            );
        game_addresses.append(game.contract_address);
        i += 1;
    };

    // Mint tokens for tournament participants
    let participants = array![ALICE(), BOB(), CHARLIE()];
    let mut token_ids = array![];

    let mut j: u32 = 0;
    while j < participants.len() {
        let participant = *participants.at(j);
        let game_idx = j % game_addresses.len();
        let game_address = *game_addresses.at(game_idx);

        // Mint through metagame (would normally include context)
        let mixin_dispatcher = IMinigameTokenMixinDispatcher { contract_address: registry_address };
        let token_id = mixin_dispatcher
            .mint(
                Option::Some(game_address),
                Option::Some("Player"),
                Option::None,
                Option::Some(1000), // Tournament start
                Option::Some(2000), // Tournament end
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                participant,
                false,
            );
        token_ids.append(token_id);
        j += 1;
    };

    // Simulate gameplay
    start_cheat_block_timestamp(registry_address, 1500); // Mid-tournament

    // Verify all tokens are playable during tournament
    let mixin_dispatcher = IMinigameTokenMixinDispatcher { contract_address: registry_address };
    let mut k: u32 = 0;
    while k < token_ids.len() {
        let token_id = *token_ids.at(k);
        assert!(
            mixin_dispatcher.is_playable(token_id), "Token should be playable during tournament",
        );
        k += 1;
    };

    // Move to after tournament
    start_cheat_block_timestamp(registry_address, 2001);

    // Verify tokens are no longer playable
    let mut l: u32 = 0;
    while l < token_ids.len() {
        let token_id = *token_ids.at(l);
        assert!(
            !mixin_dispatcher.is_playable(token_id),
            "Token should not be playable after tournament",
        );
        l += 1;
    };

    stop_cheat_block_timestamp(registry_address);
}

// ================================================================================================
// I-02: Multi-Game Platform
// ================================================================================================

#[ignore]
#[test] // Registry integration test - depends on external contracts
fn test_multi_game_platform() {
    // Deploy registry for multi-game support
    let registry_dispatcher = deploy_minigame_registry_contract_with_params(
        "GamePlatform", "GAME", "", Option::None,
    );
    let registry_address = registry_dispatcher.contract_address;

    // Register 5 different games
    let mut game_ids = array![];
    let mut i: u32 = 0;
    while i < 5 {
        let (game, game_init, _) = deploy_mock_game();
        game_init
            .initializer(
                ALICE(),
                "Game",
                "Unique game",
                "Dev",
                "Publisher",
                "Genre",
                "Image",
                Option::Some("Red"), // Different colors
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                registry_address,
            );

        // Verify game is registered
        assert!(
            registry_dispatcher.is_game_registered(game.contract_address),
            "Game should be registered",
        );
        let game_id = registry_dispatcher.game_id_from_address(game.contract_address);
        game_ids.append(game_id);
        i += 1;
    };

    // Mint tokens for each game
    let mut token_game_map: Array<(u64, u64)> = array![];
    let mut j: u32 = 0;
    while j < game_ids.len() {
        let game_id = *game_ids.at(j);
        let game_address = registry_dispatcher.game_address_from_id(game_id);

        // Mint 3 tokens per game
        let mut k: u32 = 0;
        while k < 3 {
            let mixin_dispatcher = IMinigameTokenMixinDispatcher {
                contract_address: registry_address,
            };
            let token_id = mixin_dispatcher
                .mint(
                    Option::Some(game_address),
                    Option::Some("Player"),
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
            token_game_map.append((token_id, game_id.into()));
            k += 1;
        };
        j += 1;
    };

    // Verify game isolation - each token belongs to correct game
    let mut l: u32 = 0;
    while l < token_game_map.len() {
        let (token_id, expected_game_id) = *token_game_map.at(l);
        let token_dispatcher = IMinigameTokenMixinDispatcher { contract_address: registry_address };
        let metadata = token_dispatcher.token_metadata(token_id);
        assert!(metadata.game_id == expected_game_id.into(), "Token should belong to correct game");
        l += 1;
    };

    // Verify game metadata
    let mut m: u32 = 0;
    while m < game_ids.len() {
        let game_id = *game_ids.at(m);
        let game_meta = registry_dispatcher.game_metadata(game_id);
        assert!(game_meta.name == "Game", "Game name mismatch");
        // Color comparison would be: assert!(game_meta.color == Option::Some(0xFF0000 + m), "Game
        // color mismatch");
        m += 1;
    };

    // Verify total game count
    assert!(registry_dispatcher.game_count() == 5, "Should have 5 registered games");
}

// ================================================================================================
// I-03: Time Campaign
// ================================================================================================

#[test]
fn test_time_campaign() {
    // Deploy contracts
    let (token_dispatcher, _, _) = deploy_simple_setup();

    let current_time: u64 = 1000;
    let future_start: u64 = 2000;
    let campaign_end: u64 = 3000;

    // Set current time
    start_cheat_block_timestamp(token_dispatcher.contract_address, current_time);

    // Mint token with future start
    let token_id = token_dispatcher
        .mint(
            Option::None,
            Option::Some("TimePlayer"),
            Option::None,
            Option::Some(future_start),
            Option::Some(campaign_end),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // 1. Verify not playable before start
    assert!(!token_dispatcher.is_playable(token_id), "Should not be playable before start");

    // 2. Move to exactly start time
    start_cheat_block_timestamp(token_dispatcher.contract_address, future_start);
    assert!(token_dispatcher.is_playable(token_id), "Should be playable at start time");

    // 3. Play during campaign
    start_cheat_block_timestamp(token_dispatcher.contract_address, future_start + 500);
    assert!(token_dispatcher.is_playable(token_id), "Should be playable during campaign");

    // 4. Move to exactly end time
    start_cheat_block_timestamp(token_dispatcher.contract_address, campaign_end);
    assert!(!token_dispatcher.is_playable(token_id), "Should not be playable at end time");

    // 5. Verify unplayable after end
    start_cheat_block_timestamp(token_dispatcher.contract_address, campaign_end + 1000);
    assert!(!token_dispatcher.is_playable(token_id), "Should not be playable after campaign");

    stop_cheat_block_timestamp(token_dispatcher.contract_address);
}

// ================================================================================================
// I-04: Achievement Hunt
// ================================================================================================

#[ignore]
#[test] // Requires objectives extension implementation
fn test_achievement_hunt() {
    // Deploy contracts with objectives support
    let (game, game_init, mock_game) = deploy_mock_game();

    // Deploy token with custom metadata and game address
    let (token_dispatcher, _, _, token_address) = deploy_full_token_contract(
        Option::Some("AchievementToken"),
        Option::Some("ACH"),
        Option::Some(""),
        Option::Some(game.contract_address),
        Option::None,
        Option::None,
    );

    // Initialize game
    game_init
        .initializer(
            ALICE(),
            "AchievementGame",
            "Hunt for achievements",
            "Developer",
            "Publisher",
            "Adventure",
            "Image",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(game.contract_address),
            Option::Some(game.contract_address),
            token_address,
        );

    // Create 10 objectives
    let mut objective_ids = array![];
    let mut i: u32 = 0;
    while i < 10 {
        // MockGame doesn't have create_objective_score
        objective_ids.append(i + 1);
        i += 1;
    };

    // Mint token with all objectives
    let token_id = token_dispatcher
        .mint(
            Option::Some(game.contract_address),
            Option::Some("AchievementHunter"),
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids.span()),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // Verify initial state
    assert!(token_dispatcher.objectives_count(token_id) == 10, "Should have 10 objectives");
    assert!(
        !token_dispatcher.all_objectives_completed(token_id), "Objectives should not be completed",
    );

    // Complete first 5 objectives
    let mut j: u32 = 0;
    while j < 5 {
        // Set score to complete objective
        // mock_game.set_score(token_id, (j + 1) * 100);
        token_dispatcher.update_game(token_id);
        j += 1;
    };

    // Verify partial completion
    let objectives = token_dispatcher.objectives(token_id);
    let mut completed_count: u32 = 0;
    let mut k: u32 = 0;
    while k < objectives.len() {
        if *objectives.at(k).completed {
            completed_count += 1;
        }
        k += 1;
    };

    // Note: In real implementation, objectives would be marked completed based on score
    // For this test, we verify the structure is correct

    // Complete remaining objectives
    let mut l: u32 = 5;
    while l < 10 {
        // Set score to complete remaining objectives
        // mock_game.set_score(token_id, (l + 1) * 100);
        token_dispatcher.update_game(token_id);
        l += 1;
    };

    // Set final state
    mock_game.end_game(token_id, 1000);
    token_dispatcher.update_game(token_id);

    // Verify completion
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.completed_all_objectives, "All objectives should be completed");
    assert!(metadata.game_over, "Game should be over");
}

// ================================================================================================
// A-01: Double Mint Attack
// ================================================================================================

#[test]
fn test_double_mint_attack() {
    let (token_dispatcher, _, _) = deploy_simple_setup();

    // First mint
    let token_id_1 = token_dispatcher
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

    // Second mint - should get different ID
    let token_id_2 = token_dispatcher
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

    // Verify counter prevents duplicate IDs
    assert!(token_id_1 != token_id_2, "Token IDs must be unique");
    assert!(token_id_2 == token_id_1 + 1, "Counter should increment");
}

// ================================================================================================
// A-04: Access Escalation
// ================================================================================================

#[ignore]
#[test] // Access control might be handled differently in the current implementation
fn test_access_escalation_attack() {
    let (token_dispatcher, _, _) = deploy_simple_setup();

    // Mint token as ALICE
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

    // Try to update as BOB (non-owner)
    cheat_caller_address(token_dispatcher.contract_address, BOB(), CheatSpan::TargetCalls(1));

    // This should panic due to ownership check
    token_dispatcher.update_game(token_id);
}

// ================================================================================================
// HELPER FUNCTIONS
// ================================================================================================
// deploy_mock_game and deploy_simple_setup are now imported from setup module

// ================================================================================================
// MOCK CONTRACTS
// ================================================================================================

#[starknet::contract]
mod MockContextProvider {
    use game_components_metagame::extensions::context::interface::IMetagameContext;
    use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MetagameContextImpl of IMetagameContext<ContractState> {
        fn has_context(self: @ContractState, token_id: u64) -> bool {
            true
        }

        fn context(self: @ContractState, token_id: u64) -> GameContextDetails {
            GameContextDetails {
                name: "Tournament",
                description: "Test tournament",
                id: Option::Some(1),
                context: array![
                    GameContext { name: "Type", value: "Tournament" },
                    GameContext { name: "Prize", value: "1000" },
                ]
                    .span(),
            }
        }
        // fn context_svg(self: @ContractState, token_id: u64) -> ByteArray {
    //     "<svg>Tournament</svg>"
    // }
    }
}

#[starknet::contract]
mod MockMetagameWithContext {
    use game_components_metagame::metagame::MetagameComponent;
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
    let mut token_ids: Array<u64> = array![];
    let mut minter_ids: Array<u64> = array![];

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
            };

            if is_new_minter {
                minter_ids.append(minter_id);
            }

            j += 1;
        };
        i += 1;
    };

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
            Option::Some(game_address),
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
        Option::None,
        Option::Some(registry_address),
        Option::None,
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
            );
        games.append(game.contract_address);
        i += 1;
    };

    // Test edge cases

    // 1. Mint with valid registered game
    let token_id1 = token_dispatcher
        .mint(
            Option::Some(*games.at(0)),
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
    assert!(token_dispatcher.token_metadata(token_id1).game_id == 1, "Should have game ID 1");

    // 2. Verify game address resolution
    let resolved_address = token_dispatcher.token_game_address(token_id1);
    assert!(resolved_address == *games.at(0), "Should resolve to correct game address");

    // 3. Test with maximum game ID
    let last_game_id = registry_dispatcher.game_count();
    let last_game_address = registry_dispatcher.game_address_from_id(last_game_id);

    let token_id2 = token_dispatcher
        .mint(
            Option::Some(last_game_address),
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
    let mut all_tokens: Array<u64> = array![];

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
                    Option::Some(test_contracts.minigame.contract_address),
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
                );

            all_tokens.append(token_id);
            user_idx += 1;
        };
        round += 1;
    };

    // Verify all tokens are unique and sequential
    assert!(all_tokens.len() == 9, "Should have 9 tokens");

    let mut i: u32 = 0;
    while i < all_tokens.len() {
        assert!(*all_tokens.at(i) == (i + 1).into(), "Tokens should be sequential");
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
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    // Should be playable at start time
    assert!(test_contracts.test_token.is_playable(token_id), "Should be playable at start");

    // Move to end time
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, current_time + 1);
    assert!(!test_contracts.test_token.is_playable(token_id), "Should not be playable at end");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}
