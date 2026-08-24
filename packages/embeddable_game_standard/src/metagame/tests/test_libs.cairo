// =============================================================================
// TEST: libs.cairo
// =============================================================================
// Tests for library functions: assert_game_registered, mint, mint_batch

use game_components_embeddable_game_standard::token_legacy::interface::{
    IMinigameTokenLegacyDispatcher, IMinigameTokenLegacyDispatcherTrait,
};
use game_components_testing::constants::{ALICE, BOB};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::metagame::extensions::context::structs::{GameContext, GameContextDetails};
use crate::metagame::metagame as libs;
use crate::metagame::structs::MintMetagameParams;

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

fn deploy_mock_minigame_token() -> ContractAddress {
    let contract = declare("MockMinigameTokenForLibs").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    address
}

fn deploy_mock_minigame(token_address: ContractAddress) -> ContractAddress {
    let contract = declare("MockMinigameForLibs").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![token_address.into()]).unwrap();
    address
}

fn deploy_mock_registry(registered_game: ContractAddress, is_registered: bool) -> ContractAddress {
    let contract = declare("MockRegistryForLibs").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(registered_game.into());
    calldata.append(if is_registered {
        1
    } else {
        0
    });
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

fn sample_context() -> GameContextDetails {
    GameContextDetails {
        name: "Test Tournament",
        description: "A test tournament for verification",
        id: Option::Some(1),
        context: array![
            GameContext { name: 'Prize', value: '1000 USD' },
            GameContext { name: 'Duration', value: '7 days' },
        ]
            .span(),
    }
}

// =============================================================================
// MINT TESTS - GAME PATH (the token is resolved from game_address)
// =============================================================================

// LIB-MINT-01: Mint with only required params
#[test]
fn test_mint_through_game_minimal() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
        Option::None, // player_name
        Option::None, // settings_id
        Option::None, // start
        Option::None, // end
        Option::None, // objective_id
        Option::None, // context
        Option::None, // client_url
        Option::None, // renderer_address
        Option::None,
        ALICE(),
        false,
        false,
        0,
        0,
    );

    assert!(token_id == 1.into(), "First token ID should be 1");
}

// LIB-MINT-02: Mint with player name
#[test]
fn test_mint_through_game_with_player_name() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
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

    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };
    let player_name = token_dispatcher.player_name(token_id);
    assert!(player_name == 'Player1', "Player name mismatch");
}

// LIB-MINT-03: Mint with settings_id
#[test]
fn test_mint_through_game_with_settings() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
        Option::None,
        Option::Some(42),
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

    assert!(token_id != 0, "Token should be minted");
}

// LIB-MINT-04: Mint with lifecycle (start/end)
#[test]
fn test_mint_through_game_with_lifecycle() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
        Option::None,
        Option::None,
        Option::Some(1000),
        Option::Some(2000),
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

    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.lifecycle.start == 1000, "Start time mismatch");
    assert!(metadata.lifecycle.end == 2000, "End time mismatch");
}

// LIB-MINT-05: Mint with objective_id
#[test]
fn test_mint_through_game_with_objective() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(1),
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

    assert!(token_id != 0, "Token should be minted with objective");
}

// LIB-MINT-06: Mint with context
#[test]
fn test_mint_through_game_with_context() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);
    let context = sample_context();

    let token_id = libs::mint(
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(context),
        Option::None,
        Option::None,
        Option::None,
        ALICE(),
        false,
        false,
        0,
        0,
    );

    assert!(token_id != 0, "Token should be minted with context");
}

// LIB-MINT-07: Mint with client URL
#[test]
fn test_mint_through_game_with_client_url() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some("https://game.example.com"),
        Option::None,
        Option::None,
        ALICE(),
        false,
        false,
        0,
        0,
    );

    assert!(token_id != 0, "Token should be minted with client URL");
}

// LIB-MINT-08: Mint with renderer address
#[test]
fn test_mint_through_game_with_renderer() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);
    let renderer: ContractAddress = 0xBEEF.try_into().unwrap();

    let token_id = libs::mint(
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(renderer),
        Option::None,
        ALICE(),
        false,
        false,
        0,
        0,
    );

    assert!(token_id != 0, "Token should be minted with renderer");
}

// LIB-MINT-09: Mint soulbound token
#[test]
fn test_mint_through_game_soulbound() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
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
        true, // soulbound
        false,
        0,
        0,
    );

    assert!(token_id != 0, "Soulbound token should be minted");
}

// LIB-MINT-10: Mint with all parameters
#[test]
fn test_mint_through_game_all_params() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);
    let renderer: ContractAddress = 0xBEEF.try_into().unwrap();
    let context = sample_context();

    let token_id = libs::mint(
        game_address,
        Option::Some('FullPlayer'),
        Option::Some(99),
        Option::Some(1000),
        Option::Some(2000),
        Option::Some(5),
        Option::Some(context),
        Option::Some("https://full-game.com"),
        Option::Some(renderer),
        Option::None,
        ALICE(),
        true,
        false,
        0,
        0,
    );

    assert!(token_id != 0, "Token should be minted with all params");

    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };
    let player_name = token_dispatcher.player_name(token_id);
    assert!(player_name == 'FullPlayer', "Player name mismatch");
}

// =============================================================================
// MINT TESTS - GAME TOKEN PATH (game_address = Some)
// =============================================================================

// LIB-MINT-11: Mint routes through game's token
#[test]
fn test_mint_game_token_routes_through_game() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
        Option::Some('GamePlayer'),
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
        0,
        0,
    );

    assert!(token_id != 0, "Token should be minted through game");

    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };
    let player_name = token_dispatcher.player_name(token_id);
    assert!(player_name == 'GamePlayer', "Player name should be preserved");
}

// LIB-MINT-12: Mint with game_address preserves all params
#[test]
fn test_mint_game_token_preserves_params() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);
    let context = sample_context();

    let token_id = libs::mint(
        game_address,
        Option::Some('GamePlayer2'),
        Option::Some(42),
        Option::Some(500),
        Option::Some(1500),
        Option::Some(7),
        Option::Some(context),
        Option::Some("https://game-route.com"),
        Option::None,
        Option::None,
        BOB(),
        true,
        false,
        0,
        0,
    );

    assert!(token_id != 0, "Token should be minted with all params through game");

    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.lifecycle.start == 500, "Start time should be preserved");
    assert!(metadata.lifecycle.end == 1500, "End time should be preserved");
}

// =============================================================================
// MINT EDGE CASES
// =============================================================================

// LIB-MINT-E02: Instant game (start = end)
#[test]
fn test_mint_instant_game() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
        Option::None,
        Option::None,
        Option::Some(100),
        Option::Some(100), // Same as start
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

    assert!(token_id != 0, "Instant game token should be minted");

    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.lifecycle.start == metadata.lifecycle.end, "Start should equal end");
}

// =============================================================================
// MINT_BATCH TESTS
// =============================================================================

// LIB-BATCH-01: Empty batch
#[test]
fn test_mint_batch_empty_array() {
    let mints: Array<MintMetagameParams> = array![];
    let token_ids = libs::mint_batch(mints);

    assert!(token_ids.len() == 0, "Empty batch should return empty array");
}

// LIB-BATCH-02: Single mint in batch
#[test]
fn test_mint_batch_single_mint() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let mints = array![
        MintMetagameParams {
            game_address,
            player_name: Option::Some('BatchPlayer1'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(mints);

    assert!(token_ids.len() == 1, "Should return 1 token ID");
    assert!(*token_ids.at(0) == 1.into(), "First token ID should be 1");
}

// LIB-BATCH-03: Multiple mints
#[test]
fn test_mint_batch_multiple_mints() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let mints = array![
        MintMetagameParams {
            game_address,
            player_name: Option::Some('Player1'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address,
            player_name: Option::Some('Player2'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address,
            player_name: Option::Some('Player3'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: ALICE(),
            soulbound: true,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(mints);

    assert!(token_ids.len() == 3, "Should return 3 token IDs");
    assert!(*token_ids.at(0) == 1.into(), "First token ID should be 1");
    assert!(*token_ids.at(1) == 2.into(), "Second token ID should be 2");
    assert!(*token_ids.at(2) == 3.into(), "Third token ID should be 3");
}

// LIB-BATCH-05: Batch preserves order
#[test]
fn test_mint_batch_preserves_order() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let mints = array![
        MintMetagameParams {
            game_address,
            player_name: Option::Some('First'),
            settings_id: Option::None,
            start: Option::Some(100),
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address,
            player_name: Option::Some('Second'),
            settings_id: Option::None,
            start: Option::Some(200),
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(mints);

    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };

    // Verify first token
    let first_name = token_dispatcher.player_name(*token_ids.at(0));
    assert!(first_name == 'First', "First token should have 'First' name");

    // Verify second token
    let second_name = token_dispatcher.player_name(*token_ids.at(1));
    assert!(second_name == 'Second', "Second token should have 'Second' name");
}

// LIB-BATCH-06: Batch with context
#[test]
fn test_mint_batch_with_context() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);
    let context = sample_context();

    let mints = array![
        MintMetagameParams {
            game_address,
            player_name: Option::Some('ContextPlayer'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::Some(context),
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(mints);

    assert!(token_ids.len() == 1, "Should mint token with context");
}

// LIB-BATCH-07: Batch with client URL
#[test]
fn test_mint_batch_with_client_url() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let mints = array![
        MintMetagameParams {
            game_address,
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::Some("https://batch-game.com"),
            renderer_address: Option::None,
            skills_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(mints);

    assert!(token_ids.len() == 1, "Should mint token with client URL");
}

// =============================================================================
// FUZZ TESTS
// =============================================================================

// LIB-MINT-F01: Fuzz player names
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_mint_player_names(player_name: felt252) {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
        Option::Some(player_name),
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

    assert!(token_id != 0, "Token should be minted");

    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };
    let retrieved_name = token_dispatcher.player_name(token_id);
    assert!(retrieved_name == player_name, "Player name should be preserved");
}

// LIB-MINT-F02: Fuzz settings IDs
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_mint_settings_ids(settings_id: u32) {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
        Option::None,
        Option::Some(settings_id),
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

    assert!(token_id != 0, "Token should be minted with any settings_id");
}

// LIB-MINT-F04: Fuzz objective IDs
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_mint_objective_ids(objective_id: u32) {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let token_id = libs::mint(
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(objective_id),
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

    assert!(token_id != 0, "Token should be minted with any objective_id");
}

// =============================================================================
// MOCK CONTRACTS
// =============================================================================

// Mock MinigameToken for testing libs
#[starknet::contract]
mod MockMinigameTokenForLibs {
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
    use game_components_embeddable_game_standard::token_legacy::interface::{
        IMINIGAME_TOKEN_LEGACY_ID, IMinigameTokenLegacy,
    };
    use game_components_embeddable_game_standard::token_legacy::structs::{
        Lifecycle, MintBatchRecipient, PlayerNameUpdate, TokenFullState, TokenMetadata,
        TokenMutableState,
    };
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    #[storage]
    struct Storage {
        next_token_id: u64,
        token_player_names: Map<felt252, felt252>,
        token_lifecycle_start: Map<felt252, u64>,
        token_lifecycle_end: Map<felt252, u64>,
        token_game_address: Map<felt252, ContractAddress>,
        game_registry_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_token_id.write(1);
    }

    #[abi(embed_v0)]
    impl MinigameTokenImpl of IMinigameTokenLegacy<ContractState> {
        fn token_metadata(self: @ContractState, token_id: felt252) -> TokenMetadata {
            TokenMetadata {
                game_id: 0,
                minted_at: 0,
                settings_id: 0,
                lifecycle: Lifecycle {
                    start: self.token_lifecycle_start.read(token_id),
                    end: self.token_lifecycle_end.read(token_id),
                },
                minted_by: 0,
                soulbound: false,
                game_over: false,
                completed_objective: false,
                completed_at: 0,
                has_context: false,
                objective_id: 0,
                paymaster: false,
                metadata: 0,
            }
        }

        fn is_playable(self: @ContractState, token_id: felt252) -> bool {
            token_id != 0
        }

        fn assert_is_playable(self: @ContractState, token_id: felt252) {}

        fn settings_id(self: @ContractState, token_id: felt252) -> u32 {
            0
        }

        fn player_name(self: @ContractState, token_id: felt252) -> felt252 {
            self.token_player_names.read(token_id)
        }

        fn objective_id(self: @ContractState, token_id: felt252) -> u32 {
            0
        }
        fn minted_by(self: @ContractState, token_id: felt252) -> felt252 {
            0
        }
        fn minted_by_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            0.try_into().unwrap()
        }
        fn game_address(self: @ContractState) -> ContractAddress {
            Zero::zero()
        }

        fn game_registry_address(self: @ContractState) -> ContractAddress {
            self.game_registry_address.read()
        }

        fn is_soulbound(self: @ContractState, token_id: felt252) -> bool {
            false
        }
        fn renderer_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            Zero::zero()
        }

        fn token_game_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            self.token_game_address.read(token_id)
        }

        fn token_mutable_state(self: @ContractState, token_id: felt252) -> TokenMutableState {
            TokenMutableState { game_over: false, completed_objective: false, completed_at: 0 }
        }

        fn client_url(self: @ContractState, token_id: felt252) -> ByteArray {
            ""
        }

        fn skills_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            0.try_into().unwrap()
        }

        fn token_metadata_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenMetadata> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.token_metadata(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn is_playable_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.is_playable(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn settings_id_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u32> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.settings_id(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn player_name_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<felt252> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.player_name(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn objective_id_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u32> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.objective_id(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn minted_by_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<felt252> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.minted_by(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn minted_by_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            array![]
        }

        fn is_soulbound_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.is_soulbound(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn renderer_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.renderer_address(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn token_game_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.token_game_address(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn token_mutable_state_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenMutableState> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.token_mutable_state(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn token_full_state_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenFullState> {
            array![]
        }

        fn mint(
            ref self: ContractState,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> felt252 {
            let token_id_u64 = self.next_token_id.read();
            self.next_token_id.write(token_id_u64 + 1);
            let token_id: felt252 = token_id_u64.into();

            self.token_game_address.write(token_id, game_address);
            if let Option::Some(name) = player_name {
                self.token_player_names.write(token_id, name);
            }
            if let Option::Some(start_time) = start {
                self.token_lifecycle_start.write(token_id, start_time);
            }
            if let Option::Some(end_time) = end {
                self.token_lifecycle_end.write(token_id, end_time);
            }

            token_id
        }

        fn mint_batch_recipients(
            ref self: ContractState,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            recipients: Array<MintBatchRecipient>,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> Array<felt252> {
            panic!("not implemented")
        }

        fn update_game(ref self: ContractState, token_id: felt252) {}

        fn refresh_metadata(ref self: ContractState, token_id: felt252) {}
        fn update_player_name(ref self: ContractState, token_id: felt252, name: felt252) {
            self.token_player_names.write(token_id, name);
        }
        fn update_game_batch(ref self: ContractState, token_ids: Span<felt252>) {}

        fn refresh_metadata_batch(ref self: ContractState, token_ids: Span<felt252>) {}
        fn update_player_name_batch(ref self: ContractState, updates: Span<PlayerNameUpdate>) {}
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IMINIGAME_TOKEN_LEGACY_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }
}

// Mock Minigame for testing libs
#[starknet::contract]
mod MockMinigameForLibs {
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
    use game_components_embeddable_game_standard::minigame::interface::{
        IMINIGAME_ID, IMinigame, IMinigameTokenData,
    };
    use game_components_embeddable_game_standard::minigame::structs::MintGameParams;
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        token_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_address: ContractAddress) {
        self.token_address.write(token_address);
    }

    #[abi(embed_v0)]
    impl MinigameImpl of IMinigame<ContractState> {
        fn token_address(self: @ContractState) -> ContractAddress {
            self.token_address.read()
        }
        fn settings_address(self: @ContractState) -> ContractAddress {
            0.try_into().unwrap()
        }
        fn objectives_address(self: @ContractState) -> ContractAddress {
            0.try_into().unwrap()
        }

        fn mint_game(
            self: @ContractState,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> felt252 {
            1
        }

        fn mint_game_batch(self: @ContractState, mints: Array<MintGameParams>) -> Array<felt252> {
            array![]
        }
    }

    #[abi(embed_v0)]
    impl MinigameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: felt252) -> u64 {
            0
        }
        fn game_over(self: @ContractState, token_id: felt252) -> bool {
            false
        }
        fn score_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u64> {
            array![]
        }
        fn game_over_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            array![]
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IMINIGAME_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }
}

// Mock Registry for testing assert_game_registered
#[starknet::contract]
mod MockRegistryForLibs {
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::registry::interface::{
        GameFeeInfo, GameMetadata, IMinigameRegistry,
    };
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        registered_game: ContractAddress,
        is_registered: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState, registered_game: ContractAddress, is_registered: bool) {
        self.registered_game.write(registered_game);
        self.is_registered.write(is_registered);
    }

    #[abi(embed_v0)]
    impl RegistryImpl of IMinigameRegistry<ContractState> {
        fn game_count(self: @ContractState) -> u64 {
            1
        }
        fn game_id_from_address(self: @ContractState, contract_address: ContractAddress) -> u64 {
            1
        }
        fn game_address_from_id(self: @ContractState, game_id: u64) -> ContractAddress {
            self.registered_game.read()
        }
        fn game_metadata(self: @ContractState, game_id: u64) -> GameMetadata {
            GameMetadata {
                contract_address: self.registered_game.read(),
                name: "",
                description: "",
                developer: "",
                publisher: "",
                genre: "",
                image: "",
                color: "",
                client_url: "",
                renderer_address: Zero::zero(),
                royalty_fraction: 0,
                skills_address: Zero::zero(),
                created_at: 0,
                version: 0,
            }
        }
        fn is_game_registered(self: @ContractState, contract_address: ContractAddress) -> bool {
            if contract_address == self.registered_game.read() {
                self.is_registered.read()
            } else {
                false
            }
        }
        fn register_game(
            ref self: ContractState,
            creator_address: ContractAddress,
            name: ByteArray,
            description: ByteArray,
            developer: ByteArray,
            publisher: ByteArray,
            genre: ByteArray,
            image: ByteArray,
            color: Option<ByteArray>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            royalty_fraction: Option<u128>,
            skills_address: Option<ContractAddress>,
            version: u64,
            license: Option<ByteArray>,
            fee_numerator: Option<u16>,
        ) -> u64 {
            1
        }
        fn set_game_royalty(ref self: ContractState, game_id: u64, royalty_fraction: u128) {}

        fn skills_address(self: @ContractState, game_id: u64) -> ContractAddress {
            Zero::zero()
        }

        fn game_metadata_batch(self: @ContractState, game_ids: Span<u64>) -> Array<GameMetadata> {
            let mut results: Array<GameMetadata> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= game_ids.len() {
                    break;
                }
                results.append(self.game_metadata(*game_ids.at(i)));
                i += 1;
            }
            results
        }

        fn games_registered_batch(
            self: @ContractState, addresses: Span<ContractAddress>,
        ) -> Array<bool> {
            let mut results: Array<bool> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= addresses.len() {
                    break;
                }
                results.append(self.is_game_registered(*addresses.at(i)));
                i += 1;
            }
            results
        }

        fn get_games(self: @ContractState, start: u64, count: u64) -> Array<GameMetadata> {
            let mut results: Array<GameMetadata> = ArrayTrait::new();
            if count == 0 || start == 0 || start > 1 {
                return results;
            }
            results.append(self.game_metadata(1));
            results
        }

        fn get_games_by_developer(
            self: @ContractState, developer: ByteArray, start: u64, count: u64,
        ) -> Array<GameMetadata> {
            let _ = (developer, start, count);
            array![]
        }

        fn get_games_by_publisher(
            self: @ContractState, publisher: ByteArray, start: u64, count: u64,
        ) -> Array<GameMetadata> {
            let _ = (publisher, start, count);
            array![]
        }

        fn get_games_by_genre(
            self: @ContractState, genre: ByteArray, start: u64, count: u64,
        ) -> Array<GameMetadata> {
            let _ = (genre, start, count);
            array![]
        }

        fn game_fee_info(self: @ContractState, game_id: u64) -> GameFeeInfo {
            let _ = game_id;
            GameFeeInfo { license: "", fee_numerator: 500 }
        }

        fn default_game_fee_info(self: @ContractState) -> GameFeeInfo {
            GameFeeInfo { license: "", fee_numerator: 500 }
        }

        fn set_default_game_fee(ref self: ContractState, license: ByteArray, fee_numerator: u16) {}

        fn set_game_fee(
            ref self: ContractState, game_id: u64, license: ByteArray, fee_numerator: u16,
        ) {}

        fn reset_game_fee(ref self: ContractState, game_id: u64) {}
    }
}

// =============================================================================
// ASSERT_GAME_REGISTERED TESTS
// =============================================================================

fn deploy_mock_token_with_registry(registry_address: ContractAddress) -> ContractAddress {
    let contract = declare("MockMinigameTokenWithRegistry").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![registry_address.into()]).unwrap();
    address
}

fn deploy_mock_minigame_for_registry(token_address: ContractAddress) -> ContractAddress {
    let contract = declare("MockMinigameForLibs").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![token_address.into()]).unwrap();
    address
}

// LIB-REG-01: assert_game_registered succeeds for registered game
#[test]
fn test_assert_game_registered_success() {
    let game_address: ContractAddress = 0x111.try_into().unwrap();
    let token_address: ContractAddress = 0x222.try_into().unwrap();
    let registry_address: ContractAddress = 0x333.try_into().unwrap();

    mock_call(game_address, selector!("token_address"), token_address, 1);
    // Not a standard token: the SRC5 probe for IMINIGAME_TOKEN_ID answers
    // false, so the check falls through to the registry path.
    mock_call(token_address, selector!("supports_interface"), false, 1);
    mock_call(token_address, selector!("game_registry_address"), registry_address, 1);
    mock_call(registry_address, selector!("is_game_registered"), true, 1);

    libs::assert_game_registered(game_address);
}

// LIB-REG-02: assert_game_registered fails for unregistered game
#[test]
#[should_panic(expected: "Game is not registered")]
fn test_assert_game_registered_fails_for_unregistered() {
    let game_address: ContractAddress = 0x444.try_into().unwrap();
    let token_address: ContractAddress = 0x555.try_into().unwrap();
    let registry_address: ContractAddress = 0x666.try_into().unwrap();

    mock_call(game_address, selector!("token_address"), token_address, 1);
    // Not a standard token — falls through to the registry path.
    mock_call(token_address, selector!("supports_interface"), false, 1);
    mock_call(token_address, selector!("game_registry_address"), registry_address, 1);
    mock_call(registry_address, selector!("is_game_registered"), false, 1);

    libs::assert_game_registered(game_address);
}

// =============================================================================
// ADDITIONAL MINT BATCH TESTS
// =============================================================================

// LIB-BATCH-08: Batch with mixed game addresses
#[test]
fn test_mint_batch_mixed_game_addresses() {
    let token_address = deploy_mock_minigame_token();
    let game_a = deploy_mock_minigame(token_address);
    let game_b = deploy_mock_minigame(token_address);

    let mints = array![
        MintMetagameParams {
            game_address: game_a,
            player_name: Option::Some('GameA'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address: game_b,
            player_name: Option::Some('GameB'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(mints);

    assert!(token_ids.len() == 2, "Should return 2 token IDs");

    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };
    // Each entry mints against its own game.
    assert!(
        token_dispatcher.token_game_address(*token_ids.at(0)) == game_a,
        "First token should carry game A",
    );
    assert!(
        token_dispatcher.token_game_address(*token_ids.at(1)) == game_b,
        "Second token should carry game B",
    );
    assert!(
        token_dispatcher.player_name(*token_ids.at(1)) == 'GameB',
        "Second token should have GameB name",
    );
}

// LIB-BATCH-09: Batch with different recipients
#[test]
fn test_mint_batch_different_recipients() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);
    let carol: ContractAddress = 0xCAFE.try_into().unwrap();

    let mints = array![
        MintMetagameParams {
            game_address,
            player_name: Option::Some('Alice'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address,
            player_name: Option::Some('Bob'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address,
            player_name: Option::Some('Carol'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: carol,
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(mints);

    assert!(token_ids.len() == 3, "Should mint 3 tokens");
    assert!(*token_ids.at(0) == 1.into(), "First ID should be 1");
    assert!(*token_ids.at(1) == 2.into(), "Second ID should be 2");
    assert!(*token_ids.at(2) == 3.into(), "Third ID should be 3");
}

// LIB-BATCH-10: Batch with mixed soulbound flags
#[test]
fn test_mint_batch_mixed_soulbound() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let mints = array![
        MintMetagameParams {
            game_address,
            player_name: Option::Some('Transferable'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address,
            player_name: Option::Some('Soulbound'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            skills_address: Option::None,
            to: BOB(),
            soulbound: true,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(mints);
    assert!(token_ids.len() == 2, "Should mint 2 tokens with mixed soulbound");
}

// LIB-BATCH-11: Large batch (50 mints)
#[test]
fn test_mint_batch_large_batch() {
    let token_address = deploy_mock_minigame_token();
    let game_address = deploy_mock_minigame(token_address);

    let mut mints: Array<MintMetagameParams> = array![];
    let mut i: u32 = 0;
    loop {
        if i >= 50 {
            break;
        }
        mints
            .append(
                MintMetagameParams {
                    game_address,
                    player_name: Option::None,
                    settings_id: Option::Some(i),
                    start: Option::None,
                    end: Option::None,
                    objective_id: Option::None,
                    context: Option::None,
                    client_url: Option::None,
                    renderer_address: Option::None,
                    skills_address: Option::None,
                    to: ALICE(),
                    soulbound: false,
                    paymaster: false,
                    salt: 0,
                    metadata: 0,
                },
            );
        i += 1;
    }

    let token_ids = libs::mint_batch(mints);

    assert!(token_ids.len() == 50, "Should mint 50 tokens");
    assert!(*token_ids.at(0) == 1.into(), "First ID should be 1");
    assert!(*token_ids.at(49) == 50.into(), "Last ID should be 50");
}

// =============================================================================
// ADDITIONAL MOCK CONTRACTS
// =============================================================================

// Mock MinigameToken that has a registry address
#[starknet::contract]
mod MockMinigameTokenWithRegistry {
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
    use game_components_embeddable_game_standard::token_legacy::interface::{
        IMINIGAME_TOKEN_LEGACY_ID, IMinigameTokenLegacy,
    };
    use game_components_embeddable_game_standard::token_legacy::structs::{
        Lifecycle, MintBatchRecipient, PlayerNameUpdate, TokenFullState, TokenMetadata,
        TokenMutableState,
    };
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    #[storage]
    struct Storage {
        next_token_id: u64,
        token_player_names: Map<felt252, felt252>,
        token_lifecycle_start: Map<felt252, u64>,
        token_lifecycle_end: Map<felt252, u64>,
        token_game_address: Map<felt252, ContractAddress>,
        game_registry_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, registry_address: ContractAddress) {
        self.next_token_id.write(1);
        self.game_registry_address.write(registry_address);
    }

    #[abi(embed_v0)]
    impl MinigameTokenImpl of IMinigameTokenLegacy<ContractState> {
        fn token_metadata(self: @ContractState, token_id: felt252) -> TokenMetadata {
            TokenMetadata {
                game_id: 0,
                minted_at: 0,
                settings_id: 0,
                lifecycle: Lifecycle {
                    start: self.token_lifecycle_start.read(token_id),
                    end: self.token_lifecycle_end.read(token_id),
                },
                minted_by: 0,
                soulbound: false,
                game_over: false,
                completed_objective: false,
                completed_at: 0,
                has_context: false,
                objective_id: 0,
                paymaster: false,
                metadata: 0,
            }
        }
        fn is_playable(self: @ContractState, token_id: felt252) -> bool {
            token_id != 0
        }
        fn assert_is_playable(self: @ContractState, token_id: felt252) {}
        fn settings_id(self: @ContractState, token_id: felt252) -> u32 {
            0
        }
        fn player_name(self: @ContractState, token_id: felt252) -> felt252 {
            self.token_player_names.read(token_id)
        }
        fn objective_id(self: @ContractState, token_id: felt252) -> u32 {
            0
        }
        fn minted_by(self: @ContractState, token_id: felt252) -> felt252 {
            0
        }
        fn minted_by_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            0.try_into().unwrap()
        }
        fn game_address(self: @ContractState) -> ContractAddress {
            Zero::zero()
        }
        fn game_registry_address(self: @ContractState) -> ContractAddress {
            self.game_registry_address.read()
        }
        fn is_soulbound(self: @ContractState, token_id: felt252) -> bool {
            false
        }
        fn renderer_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            Zero::zero()
        }
        fn token_game_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            self.token_game_address.read(token_id)
        }
        fn token_mutable_state(self: @ContractState, token_id: felt252) -> TokenMutableState {
            TokenMutableState { game_over: false, completed_objective: false, completed_at: 0 }
        }

        fn client_url(self: @ContractState, token_id: felt252) -> ByteArray {
            ""
        }

        fn skills_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            0.try_into().unwrap()
        }

        fn token_metadata_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenMetadata> {
            let mut r = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                r.append(self.token_metadata(*token_ids.at(i)));
                i += 1;
            }
            r
        }
        fn is_playable_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut r = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                r.append(self.is_playable(*token_ids.at(i)));
                i += 1;
            }
            r
        }
        fn settings_id_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u32> {
            let mut r = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                r.append(self.settings_id(*token_ids.at(i)));
                i += 1;
            }
            r
        }
        fn player_name_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<felt252> {
            let mut r = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                r.append(self.player_name(*token_ids.at(i)));
                i += 1;
            }
            r
        }
        fn objective_id_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u32> {
            let mut r = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                r.append(self.objective_id(*token_ids.at(i)));
                i += 1;
            }
            r
        }
        fn minted_by_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<felt252> {
            let mut r = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                r.append(self.minted_by(*token_ids.at(i)));
                i += 1;
            }
            r
        }
        fn minted_by_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            array![]
        }
        fn is_soulbound_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut r = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                r.append(self.is_soulbound(*token_ids.at(i)));
                i += 1;
            }
            r
        }
        fn renderer_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            let mut r = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                r.append(self.renderer_address(*token_ids.at(i)));
                i += 1;
            }
            r
        }
        fn token_game_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            let mut r = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                r.append(self.token_game_address(*token_ids.at(i)));
                i += 1;
            }
            r
        }
        fn token_mutable_state_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenMutableState> {
            let mut r = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                r.append(self.token_mutable_state(*token_ids.at(i)));
                i += 1;
            }
            r
        }

        fn token_full_state_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenFullState> {
            array![]
        }

        fn mint(
            ref self: ContractState,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> felt252 {
            let token_id_u64 = self.next_token_id.read();
            self.next_token_id.write(token_id_u64 + 1);
            let token_id: felt252 = token_id_u64.into();
            self.token_game_address.write(token_id, game_address);
            if let Option::Some(name) = player_name {
                self.token_player_names.write(token_id, name);
            }
            if let Option::Some(start_time) = start {
                self.token_lifecycle_start.write(token_id, start_time);
            }
            if let Option::Some(end_time) = end {
                self.token_lifecycle_end.write(token_id, end_time);
            }
            token_id
        }

        fn mint_batch_recipients(
            ref self: ContractState,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            recipients: Array<MintBatchRecipient>,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> Array<felt252> {
            panic!("not implemented")
        }

        fn update_game(ref self: ContractState, token_id: felt252) {}

        fn refresh_metadata(ref self: ContractState, token_id: felt252) {}
        fn update_player_name(ref self: ContractState, token_id: felt252, name: felt252) {
            self.token_player_names.write(token_id, name);
        }
        fn update_game_batch(ref self: ContractState, token_ids: Span<felt252>) {}

        fn refresh_metadata_batch(ref self: ContractState, token_ids: Span<felt252>) {}
        fn update_player_name_batch(ref self: ContractState, updates: Span<PlayerNameUpdate>) {}
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IMINIGAME_TOKEN_LEGACY_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }
}

// =============================================================================
// STANDARD (SELF-BOUND) TOKEN PATHS
// =============================================================================
//
// `assert_game_registered` accepts a self-bound standard token, so every
// downstream lib path must be able to serve one too. These run against the
// real merged game+token contract (`StandardGameMock`), not a mock ABI.

#[cfg(test)]
mod standard_token_paths {
    use game_components_embeddable_game_standard::token::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_interfaces::token::creator::{
        IMinigameTokenCreatorDispatcher, IMinigameTokenCreatorDispatcherTrait,
    };
    use game_components_testing::constants::{ALICE, BOB, OWNER};
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
    use starknet::ContractAddress;
    use crate::metagame::metagame as libs;

    /// One contract that is both the game and the standard token.
    fn deploy_standard_game(game_creator: ContractAddress) -> ContractAddress {
        let contract = declare("StandardGameMock").unwrap().contract_class();
        let mut calldata: Array<felt252> = array![];
        let name: ByteArray = "StandardToken";
        let symbol: ByteArray = "STD";
        let base_uri: ByteArray = "https://token.test/";
        name.serialize(ref calldata);
        symbol.serialize(ref calldata);
        base_uri.serialize(ref calldata);
        game_creator.serialize(ref calldata);
        OWNER().serialize(ref calldata);
        let (contract_address, _) = contract.deploy(@calldata).unwrap();
        contract_address
    }

    /// The self-bound pairing is what "registered" means for a standard token.
    #[test]
    fn test_assert_game_registered_accepts_standard_token() {
        let game = deploy_standard_game(ALICE());
        libs::assert_game_registered(game);
    }

    /// Regression: the gate accepted standard tokens while `mint` still spoke
    /// the legacy 15-arg ABI, so every accepted game reverted at mint.
    #[test]
    fn test_mint_through_standard_token() {
        let game = deploy_standard_game(ALICE());

        let token_id = libs::mint(
            game,
            Option::Some('player'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None, // renderer — unsupported, must be None
            Option::None, // skills — unsupported, must be None
            BOB(),
            false,
            false,
            0,
            0,
        );

        assert!(token_id != 0, "mint returned a zero token id");
        let erc721 = IERC721Dispatcher { contract_address: game };
        assert!(erc721.owner_of(token_id.into()) == BOB(), "token not minted to recipient");
        let token = IMinigameTokenDispatcher { contract_address: game };
        assert!(token.player_name(token_id) == 'player', "player name not stored");
    }

    /// Minimal mint through a standard game — every optional param None.
    #[test]
    fn test_mint_standard_token_minimal() {
        let game = deploy_standard_game(ALICE());

        let token_id = libs::mint(
            game,
            Option::None,
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
            0,
            0,
        );

        let erc721 = IERC721Dispatcher { contract_address: game };
        assert!(erc721.owner_of(token_id.into()) == BOB(), "token not minted to recipient");
    }

    /// Unsupported params are rejected loudly, never silently dropped.
    #[test]
    #[should_panic(expected: "Metagame: standard tokens have no per-token renderer")]
    fn test_mint_rejects_renderer_on_standard_token() {
        let game = deploy_standard_game(ALICE());
        libs::mint(
            game,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(BOB()),
            Option::None,
            BOB(),
            false,
            false,
            0,
            0,
        );
    }

    #[test]
    #[should_panic(expected: "Metagame: standard tokens have no per-token skills")]
    fn test_mint_rejects_skills_on_standard_token() {
        let game = deploy_standard_game(ALICE());
        libs::mint(
            game,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(BOB()),
            BOB(),
            false,
            false,
            0,
            0,
        );
    }

    /// The creator surface replaces the registry's fee role — previously this
    /// reverted on the missing `game_registry_address()` entrypoint.
    #[test]
    fn test_get_game_fee_info_reads_creator_surface() {
        let game = deploy_standard_game(ALICE());
        let fee_info = libs::get_game_fee_info(game);
        let declared = IMinigameTokenCreatorDispatcher { contract_address: game };
        assert!(
            fee_info.fee_numerator == declared.game_creator_info().fee_numerator,
            "fee numerator does not match the token's declared fee",
        );
    }

    /// The payee is named directly, not resolved through a registry NFT owner.
    #[test]
    fn test_get_game_creator_address_is_the_declared_payee() {
        let game = deploy_standard_game(ALICE());
        assert!(
            libs::get_game_creator_address(game) == ALICE(), "payee is not the declared creator",
        );
    }
}

// =============================================================================
// SINGLE-GAME LEGACY TOKEN (ZERO REGISTRY)
// =============================================================================
//
// A legacy token is a SEPARATE contract from its game, so with no registry the
// pairing is the token's own `game_address()` view — not an address equality
// against the token itself. This shape previously dispatched into address 0
// and reverted with CONTRACT_NOT_DEPLOYED.

#[cfg(test)]
mod legacy_single_game_token {
    use core::num::traits::Zero;
    use game_components_testing::constants::{ALICE, BOB};
    use snforge_std::mock_call;
    use starknet::ContractAddress;
    use crate::metagame::metagame as libs;
    use super::{deploy_mock_minigame_for_registry, deploy_mock_token_with_registry};

    #[test]
    fn test_assert_game_registered_accepts_paired_single_game_token() {
        let zero_registry: ContractAddress = Zero::zero();
        let token = deploy_mock_token_with_registry(zero_registry);
        let game = deploy_mock_minigame_for_registry(token);
        // The token names its paired game — that is the pairing to check.
        mock_call(token, selector!("game_address"), game, 1);

        libs::assert_game_registered(game);
    }

    #[test]
    #[should_panic(expected: "Game is not registered")]
    fn test_assert_game_registered_rejects_mispaired_single_game_token() {
        let zero_registry: ContractAddress = Zero::zero();
        let token = deploy_mock_token_with_registry(zero_registry);
        let game = deploy_mock_minigame_for_registry(token);
        // The token is bound to a different game.
        mock_call(token, selector!("game_address"), ALICE(), 1);

        libs::assert_game_registered(game);
    }

    #[test]
    #[should_panic(expected: "Game is not registered")]
    fn test_assert_game_registered_rejects_unbound_single_game_token() {
        let zero_registry: ContractAddress = Zero::zero();
        let token = deploy_mock_token_with_registry(zero_registry);
        let game = deploy_mock_minigame_for_registry(token);
        // A token that names no game at all must not pass.
        mock_call(token, selector!("game_address"), BOB(), 1);

        libs::assert_game_registered(game);
    }
}

// =============================================================================
// HOSTILE GAME POINTING AT SOMEONE ELSE'S STANDARD TOKEN
// =============================================================================
//
// A standard token is self-bound, so `token_address() == game_address` IS its
// registration check. Any path that trusts a game's `token_address()` must
// enforce it: otherwise a contract that merely implements `token_address()`
// can name a standard token it does not own and have the metagame mint on it
// or pay its creator — at a fee rate the attacker controls.

#[cfg(test)]
mod hostile_game_paths {
    use game_components_testing::constants::{ALICE, BOB, OWNER};
    use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
    use starknet::ContractAddress;
    use crate::metagame::metagame as libs;

    fn deploy_standard_game(game_creator: ContractAddress) -> ContractAddress {
        let contract = declare("StandardGameMock").unwrap().contract_class();
        let mut calldata: Array<felt252> = array![];
        let name: ByteArray = "StandardToken";
        let symbol: ByteArray = "STD";
        let base_uri: ByteArray = "https://token.test/";
        name.serialize(ref calldata);
        symbol.serialize(ref calldata);
        base_uri.serialize(ref calldata);
        game_creator.serialize(ref calldata);
        OWNER().serialize(ref calldata);
        let (contract_address, _) = contract.deploy(@calldata).unwrap();
        contract_address
    }

    /// A hostile "game" that reports a victim's standard token as its own.
    fn hostile_game_pointing_at(victim_token: ContractAddress) -> ContractAddress {
        let hostile: ContractAddress = 0xBAD.try_into().unwrap();
        mock_call(hostile, selector!("token_address"), victim_token, 10);
        hostile
    }

    #[test]
    #[should_panic(expected: "Game is not registered")]
    fn test_mint_rejects_game_pointing_at_foreign_standard_token() {
        let victim = deploy_standard_game(ALICE());
        let hostile = hostile_game_pointing_at(victim);

        libs::mint(
            hostile,
            Option::None,
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
            0,
            0,
        );
    }

    /// Fee terms must not be readable through a game that does not own the token.
    #[test]
    #[should_panic(expected: "Game is not registered")]
    fn test_get_game_fee_info_rejects_foreign_standard_token() {
        let victim = deploy_standard_game(ALICE());
        let hostile = hostile_game_pointing_at(victim);
        libs::get_game_fee_info(hostile);
    }

    /// The payee must not be redirectable to a foreign token's creator.
    #[test]
    #[should_panic(expected: "Game is not registered")]
    fn test_get_game_creator_address_rejects_foreign_standard_token() {
        let victim = deploy_standard_game(ALICE());
        let hostile = hostile_game_pointing_at(victim);
        libs::get_game_creator_address(hostile);
    }

    /// The self-bound game itself still works through all three paths.
    #[test]
    fn test_self_bound_game_still_passes_every_path() {
        let game = deploy_standard_game(ALICE());
        libs::assert_game_registered(game);
        assert!(libs::get_game_creator_address(game) == ALICE(), "payee should be the creator");
        assert!(libs::get_game_fee_info(game).fee_numerator == 500, "default fee is 500 bps");
    }
}
