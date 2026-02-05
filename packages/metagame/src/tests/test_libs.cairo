// =============================================================================
// TEST: libs.cairo
// =============================================================================
// Tests for library functions: assert_game_registered, mint, mint_batch

use game_components_testing::constants::{ALICE, BOB};
use game_components_token::core::interface::{
    IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::extensions::context::structs::{GameContext, GameContextDetails};
use crate::libs;
use crate::structs::MintMetagameParams;

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
            GameContext { name: "Prize", value: "1000 USD" },
            GameContext { name: "Duration", value: "7 days" },
        ]
            .span(),
    }
}

// =============================================================================
// MINT TESTS - DEFAULT TOKEN PATH (game_address = None)
// =============================================================================

// LIB-MINT-01: Mint with only required params
#[test]
fn test_mint_default_token_minimal() {
    let token_address = deploy_mock_minigame_token();

    let token_id = libs::mint(
        token_address,
        Option::None, // game_address
        Option::None, // player_name
        Option::None, // settings_id
        Option::None, // start
        Option::None, // end
        Option::None, // objective_id
        Option::None, // context
        Option::None, // client_url
        Option::None, // renderer_address
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
fn test_mint_default_token_with_player_name() {
    let token_address = deploy_mock_minigame_token();

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::Some('Player1'),
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

    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
    let player_name = token_dispatcher.player_name(token_id);
    assert!(player_name == 'Player1', "Player name mismatch");
}

// LIB-MINT-03: Mint with settings_id
#[test]
fn test_mint_default_token_with_settings() {
    let token_address = deploy_mock_minigame_token();

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::None,
        Option::Some(42),
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
fn test_mint_default_token_with_lifecycle() {
    let token_address = deploy_mock_minigame_token();

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(1000),
        Option::Some(2000),
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

    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.lifecycle.start == 1000, "Start time mismatch");
    assert!(metadata.lifecycle.end == 2000, "End time mismatch");
}

// LIB-MINT-05: Mint with objective_id
#[test]
fn test_mint_default_token_with_objective() {
    let token_address = deploy_mock_minigame_token();

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(1),
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
fn test_mint_default_token_with_context() {
    let token_address = deploy_mock_minigame_token();
    let context = sample_context();

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(context),
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
fn test_mint_default_token_with_client_url() {
    let token_address = deploy_mock_minigame_token();

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some("https://game.example.com"),
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
fn test_mint_default_token_with_renderer() {
    let token_address = deploy_mock_minigame_token();
    let renderer: ContractAddress = 0xBEEF.try_into().unwrap();

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(renderer),
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
fn test_mint_default_token_soulbound() {
    let token_address = deploy_mock_minigame_token();

    let token_id = libs::mint(
        token_address,
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
fn test_mint_default_token_all_params() {
    let token_address = deploy_mock_minigame_token();
    let renderer: ContractAddress = 0xBEEF.try_into().unwrap();
    let context = sample_context();

    let token_id = libs::mint(
        token_address,
        Option::None, // game_address (using default token path)
        Option::Some('FullPlayer'),
        Option::Some(99),
        Option::Some(1000),
        Option::Some(2000),
        Option::Some(5),
        Option::Some(context),
        Option::Some("https://full-game.com"),
        Option::Some(renderer),
        ALICE(),
        true,
        false,
        0,
        0,
    );

    assert!(token_id != 0, "Token should be minted with all params");

    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
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
        token_address, // default_token_address (not used when game_address is provided)
        Option::Some(game_address),
        Option::Some('GamePlayer'),
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

    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
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
        token_address,
        Option::Some(game_address),
        Option::Some('GamePlayer2'),
        Option::Some(42),
        Option::Some(500),
        Option::Some(1500),
        Option::Some(7),
        Option::Some(context),
        Option::Some("https://game-route.com"),
        Option::None,
        BOB(),
        true,
        false,
        0,
        0,
    );

    assert!(token_id != 0, "Token should be minted with all params through game");

    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
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

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(100),
        Option::Some(100), // Same as start
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

    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.lifecycle.start == metadata.lifecycle.end, "Start should equal end");
}

// =============================================================================
// MINT_BATCH TESTS
// =============================================================================

// LIB-BATCH-01: Empty batch
#[test]
fn test_mint_batch_empty_array() {
    let token_address = deploy_mock_minigame_token();

    let mints: Array<MintMetagameParams> = array![];
    let token_ids = libs::mint_batch(token_address, mints);

    assert!(token_ids.len() == 0, "Empty batch should return empty array");
}

// LIB-BATCH-02: Single mint in batch
#[test]
fn test_mint_batch_single_mint() {
    let token_address = deploy_mock_minigame_token();

    let mints = array![
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('BatchPlayer1'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(token_address, mints);

    assert!(token_ids.len() == 1, "Should return 1 token ID");
    assert!(*token_ids.at(0) == 1.into(), "First token ID should be 1");
}

// LIB-BATCH-03: Multiple mints
#[test]
fn test_mint_batch_multiple_mints() {
    let token_address = deploy_mock_minigame_token();

    let mints = array![
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('Player1'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('Player2'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('Player3'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: true,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(token_address, mints);

    assert!(token_ids.len() == 3, "Should return 3 token IDs");
    assert!(*token_ids.at(0) == 1.into(), "First token ID should be 1");
    assert!(*token_ids.at(1) == 2.into(), "Second token ID should be 2");
    assert!(*token_ids.at(2) == 3.into(), "Third token ID should be 3");
}

// LIB-BATCH-05: Batch preserves order
#[test]
fn test_mint_batch_preserves_order() {
    let token_address = deploy_mock_minigame_token();

    let mints = array![
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('First'),
            settings_id: Option::None,
            start: Option::Some(100),
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('Second'),
            settings_id: Option::None,
            start: Option::Some(200),
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(token_address, mints);

    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };

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
    let context = sample_context();

    let mints = array![
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('ContextPlayer'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::Some(context),
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(token_address, mints);

    assert!(token_ids.len() == 1, "Should mint token with context");
}

// LIB-BATCH-07: Batch with client URL
#[test]
fn test_mint_batch_with_client_url() {
    let token_address = deploy_mock_minigame_token();

    let mints = array![
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::Some("https://batch-game.com"),
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(token_address, mints);

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

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::Some(player_name),
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

    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
    let retrieved_name = token_dispatcher.player_name(token_id);
    assert!(retrieved_name == player_name, "Player name should be preserved");
}

// LIB-MINT-F02: Fuzz settings IDs
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_mint_settings_ids(settings_id: u32) {
    let token_address = deploy_mock_minigame_token();

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::None,
        Option::Some(settings_id),
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

    let token_id = libs::mint(
        token_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(objective_id),
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
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use game_components_token::core::interface::{IMINIGAME_TOKEN_ID, IMinigameToken};
    use game_components_token::structs::{
        Lifecycle, MintParams, PlayerNameUpdate, TokenMetadata, TokenMutableState,
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
    impl MinigameTokenImpl of IMinigameToken<ContractState> {
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
                has_context: false,
                objective_id: 0,
                paymaster: false,
                metadata: 0,
            }
        }

        fn is_playable(self: @ContractState, token_id: felt252) -> bool {
            token_id != 0
        }

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
            TokenMutableState { game_over: false, completed_objective: false }
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

        fn mint_batch(ref self: ContractState, mints: Array<MintParams>) -> Array<felt252> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= mints.len() {
                    break;
                }
                let params = mints.at(i);
                let context_clone = match params.context {
                    Option::Some(ctx) => Option::Some(ctx.clone()),
                    Option::None => Option::None,
                };
                let client_url_clone = match params.client_url {
                    Option::Some(url) => Option::Some(url.clone()),
                    Option::None => Option::None,
                };
                let token_id = self
                    .mint(
                        *params.game_address,
                        *params.player_name,
                        *params.settings_id,
                        *params.start,
                        *params.end,
                        *params.objective_id,
                        context_clone,
                        client_url_clone,
                        *params.renderer_address,
                        *params.to,
                        *params.soulbound,
                        *params.paymaster,
                        *params.salt,
                        *params.metadata,
                    );
                results.append(token_id);
                i += 1;
            }
            results
        }

        fn update_game(ref self: ContractState, token_id: felt252) {}
        fn update_player_name(ref self: ContractState, token_id: felt252, name: felt252) {
            self.token_player_names.write(token_id, name);
        }
        fn update_game_batch(ref self: ContractState, token_ids: Span<felt252>) {}
        fn update_player_name_batch(ref self: ContractState, updates: Span<PlayerNameUpdate>) {}
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IMINIGAME_TOKEN_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }
}

// Mock Minigame for testing libs
#[starknet::contract]
mod MockMinigameForLibs {
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use game_components_minigame::interface::{IMINIGAME_ID, IMinigame, IMinigameTokenData};
    use game_components_minigame::structs::MintGameParams;
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
    use game_components_registry::interface::{GameMetadata, IMinigameRegistry};
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
                created_at: 0,
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
        ) -> u64 {
            1
        }
        fn set_game_royalty(ref self: ContractState, game_id: u64, royalty_fraction: u128) {}

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
    let game_address = deploy_mock_minigame(token_address);

    let mints = array![
        MintMetagameParams {
            game_address: Option::Some(game_address),
            player_name: Option::Some('WithGame'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('NoGame'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(token_address, mints);

    assert!(token_ids.len() == 2, "Should return 2 token IDs");

    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
    let first_game_addr = token_dispatcher.token_game_address(*token_ids.at(0));
    assert!(first_game_addr == game_address, "First token should have game address");

    let second_name = token_dispatcher.player_name(*token_ids.at(1));
    assert!(second_name == 'NoGame', "Second token should have NoGame name");
}

// LIB-BATCH-09: Batch with different recipients
#[test]
fn test_mint_batch_different_recipients() {
    let token_address = deploy_mock_minigame_token();
    let carol: ContractAddress = 0xCAFE.try_into().unwrap();

    let mints = array![
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('Alice'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('Bob'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('Carol'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: carol,
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(token_address, mints);

    assert!(token_ids.len() == 3, "Should mint 3 tokens");
    assert!(*token_ids.at(0) == 1.into(), "First ID should be 1");
    assert!(*token_ids.at(1) == 2.into(), "Second ID should be 2");
    assert!(*token_ids.at(2) == 3.into(), "Third ID should be 3");
}

// LIB-BATCH-10: Batch with mixed soulbound flags
#[test]
fn test_mint_batch_mixed_soulbound() {
    let token_address = deploy_mock_minigame_token();

    let mints = array![
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('Transferable'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('Soulbound'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: true,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = libs::mint_batch(token_address, mints);
    assert!(token_ids.len() == 2, "Should mint 2 tokens with mixed soulbound");
}

// LIB-BATCH-11: Large batch (50 mints)
#[test]
fn test_mint_batch_large_batch() {
    let token_address = deploy_mock_minigame_token();

    let mut mints: Array<MintMetagameParams> = array![];
    let mut i: u32 = 0;
    loop {
        if i >= 50 {
            break;
        }
        mints
            .append(
                MintMetagameParams {
                    game_address: Option::None,
                    player_name: Option::None,
                    settings_id: Option::Some(i),
                    start: Option::None,
                    end: Option::None,
                    objective_id: Option::None,
                    context: Option::None,
                    client_url: Option::None,
                    renderer_address: Option::None,
                    to: ALICE(),
                    soulbound: false,
                    paymaster: false,
                    salt: 0,
                    metadata: 0,
                },
            );
        i += 1;
    }

    let token_ids = libs::mint_batch(token_address, mints);

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
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use game_components_token::core::interface::{IMINIGAME_TOKEN_ID, IMinigameToken};
    use game_components_token::structs::{
        Lifecycle, MintParams, PlayerNameUpdate, TokenMetadata, TokenMutableState,
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
    impl MinigameTokenImpl of IMinigameToken<ContractState> {
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
                has_context: false,
                objective_id: 0,
                paymaster: false,
                metadata: 0,
            }
        }
        fn is_playable(self: @ContractState, token_id: felt252) -> bool {
            token_id != 0
        }
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
            TokenMutableState { game_over: false, completed_objective: false }
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

        fn mint_batch(ref self: ContractState, mints: Array<MintParams>) -> Array<felt252> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= mints.len() {
                    break;
                }
                let params = mints.at(i);
                let context_clone = match params.context {
                    Option::Some(ctx) => Option::Some(ctx.clone()),
                    Option::None => Option::None,
                };
                let client_url_clone = match params.client_url {
                    Option::Some(url) => Option::Some(url.clone()),
                    Option::None => Option::None,
                };
                let token_id = self
                    .mint(
                        *params.game_address,
                        *params.player_name,
                        *params.settings_id,
                        *params.start,
                        *params.end,
                        *params.objective_id,
                        context_clone,
                        client_url_clone,
                        *params.renderer_address,
                        *params.to,
                        *params.soulbound,
                        *params.paymaster,
                        *params.salt,
                        *params.metadata,
                    );
                results.append(token_id);
                i += 1;
            }
            results
        }

        fn update_game(ref self: ContractState, token_id: felt252) {}
        fn update_player_name(ref self: ContractState, token_id: felt252, name: felt252) {
            self.token_player_names.write(token_id, name);
        }
        fn update_game_batch(ref self: ContractState, token_ids: Span<felt252>) {}
        fn update_player_name_batch(ref self: ContractState, updates: Span<PlayerNameUpdate>) {}
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IMINIGAME_TOKEN_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }
}
