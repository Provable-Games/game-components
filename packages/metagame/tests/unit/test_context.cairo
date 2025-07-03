use starknet::ContractAddress;
use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
use game_components_metagame::extensions::context::interface::IMETAGAME_CONTEXT_ID;
use crate::common::constants;
use crate::common::helpers;
use crate::common::mocks::mock_token::MockMinigameTokenTrait;
use crate::common::mocks::mock_context::MockContextContractTrait;

// Interface for calling test functions
#[starknet::interface]
trait IMockMetagameTest<TContractState> {
    fn test_mint(
        ref self: TContractState,
        game_address: Option<ContractAddress>,
        player_name: Option<ByteArray>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_ids: Option<Span<u32>>,
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
    
    fn set_context_data(ref self: TContractState, token_id: u64, context: GameContextDetails);
}

// CTX-01: Mint with context, no support
#[test]
#[should_panic(expected: ('No IMetagameContext', ))]
fn test_mint_with_context_no_support() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    // Deploy without context support
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let context = helpers::create_test_context();
    
    // Should revert because contract doesn't support IMetagameContext
    test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::Some(context), // Context provided
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false,
    );
}

// CTX-02: Mint with embedded context
#[test]
fn test_mint_with_embedded_context() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    // Deploy with context support
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, true);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let context = helpers::create_test_context();
    
    // Store context data for verification
    test_contract.set_context_data(1, context);
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::Some(helpers::create_test_context()),
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false,
    );
    
    assert(token_id == 1, 'Token ID mismatch');
}

// CTX-03: Mint with external context
#[test]
fn test_mint_with_external_context() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let context_address = constants::CONTEXT_ADDRESS();
    let recipient = constants::ALICE();
    // Deploy with external context address
    let contract_address = helpers::deploy_mock_metagame(
        token_address, 
        Option::Some(context_address), 
        false
    );
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(2);
    
    // Mock external context contract
    let mock_context = MockContextContractTrait::new(context_address);
    mock_context.mock_supports_interface(IMETAGAME_CONTEXT_ID, true);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let context = helpers::create_test_context();
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::Some(context),
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false,
    );
    
    assert(token_id == 2, 'Token ID mismatch');
}

// CTX-04: External context no interface
#[test]
#[should_panic(expected: ('Context no IMetagameContext', ))]
fn test_external_context_no_interface() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let context_address = constants::CONTEXT_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(
        token_address, 
        Option::Some(context_address), 
        false
    );
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    
    // Mock external context contract that doesn't support interface
    let mock_context = MockContextContractTrait::new(context_address);
    mock_context.mock_supports_interface(IMETAGAME_CONTEXT_ID, false);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let context = helpers::create_test_context();
    
    // Should revert because external context doesn't support interface
    test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::Some(context),
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false,
    );
}

// CTX-05: Complex context data
#[test]
fn test_complex_context_data() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, true);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(3);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Create complex context with many key-value pairs
    let mut context_data = array![];
    context_data.append(GameContext { name: "level", value: "99" });
    context_data.append(GameContext { name: "score", value: "999999" });
    context_data.append(GameContext { name: "achievements", value: "dragon_slayer,speedrun,no_damage" });
    context_data.append(GameContext { name: "difficulty", value: "nightmare" });
    context_data.append(GameContext { name: "character_class", value: "wizard" });
    context_data.append(GameContext { name: "play_time", value: "3600" });
    context_data.append(GameContext { name: "deaths", value: "0" });
    context_data.append(GameContext { name: "secrets_found", value: "42/42" });
    context_data.append(GameContext { name: "pvp_rank", value: "grandmaster" });
    context_data.append(GameContext { name: "guild", value: "The_Unstoppables" });
    
    let complex_context = GameContextDetails {
        name: "Epic Game Run",
        description: "A perfect run with all achievements unlocked and maximum score",
        id: Option::Some(999),
        context: context_data.span(),
    };
    
    test_contract.set_context_data(3, complex_context);
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::Some(GameContextDetails {
            name: "Epic Game Run",
            description: "A perfect run with all achievements unlocked and maximum score",
            id: Option::Some(999),
            context: array![
                GameContext { name: "level", value: "99" },
                GameContext { name: "score", value: "999999" },
                GameContext { name: "achievements", value: "dragon_slayer,speedrun,no_damage" },
                GameContext { name: "difficulty", value: "nightmare" },
                GameContext { name: "character_class", value: "wizard" },
                GameContext { name: "play_time", value: "3600" },
                GameContext { name: "deaths", value: "0" },
                GameContext { name: "secrets_found", value: "42/42" },
                GameContext { name: "pvp_rank", value: "grandmaster" },
                GameContext { name: "guild", value: "The_Unstoppables" },
            ].span(),
        }),
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false,
    );
    
    assert(token_id == 3, 'Token ID mismatch');
}

// Additional test: Empty context data
#[test]
fn test_empty_context_data() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, true);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(4);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Create context with empty data array
    let empty_context = GameContextDetails {
        name: "",
        description: "",
        id: Option::Some(0),
        context: array![].span(),
    };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::Some(empty_context),
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false,
    );
    
    assert(token_id == 4, 'Token ID mismatch');
}

// Additional test: Context with special characters
#[test]
fn test_context_with_special_characters() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, true);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(5);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Create context with special characters and unicode
    let special_context = GameContextDetails {
        name: "Game with \"quotes\" and 'apostrophes'",
        description: "Special chars: !@#$%^&*()_+-=[]{}|;:,.<>?/~`",
        id: Option::Some(12345),
        context: array![
            GameContext { name: "json_data", value: "{\"key\":\"value\",\"num\":123}" },
            GameContext { name: "path", value: "/home/user/game/save.dat" },
            GameContext { name: "url", value: "https://example.com?param=value&other=123" },
        ].span(),
    };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::Some(special_context),
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false,
    );
    
    assert(token_id == 5, 'Token ID mismatch');
}