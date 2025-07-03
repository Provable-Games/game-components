use starknet::ContractAddress;
use game_components_metagame::interface::{IMetagameDispatcher, IMetagameDispatcherTrait};
use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
use game_components_metagame::extensions::context::interface::{IMetagameContextDispatcher, IMetagameContextDispatcherTrait};
use crate::common::constants;
use crate::common::helpers;
use crate::common::mocks::mock_token::MockMinigameTokenTrait;

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

// INT-01: Complete Game Flow
#[test]
fn test_complete_game_flow() {
    // Step 1: Deploy token contract
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    // Step 2: Deploy metagame with token address
    let metagame_address = helpers::deploy_mock_metagame(token_address, Option::None, true);
    let metagame = IMetagameDispatcher { contract_address: metagame_address };
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    let context_dispatcher = IMetagameContextDispatcher { contract_address: metagame_address };
    
    // Step 3: Register game in token
    let game_address = constants::GAME_ADDRESS();
    mock_token.mock_is_game_registered(game_address, true);
    
    // Step 4: Player completes game
    let player = constants::ALICE();
    let objectives = helpers::create_test_objectives();
    let start_time = 1000000_u64;
    let end_time = 1005000_u64; // 5000 seconds game duration
    
    // Step 5: Mint token with achievements
    let context = GameContextDetails {
        name: "Epic Victory",
        description: "Completed all objectives on hard mode",
        id: Option::Some(1001),
        context: array![
            GameContext { name: "difficulty", value: "hard" },
            GameContext { name: "score", value: "999999" },
            GameContext { name: "perfect_run", value: "true" },
            GameContext { name: "secrets_found", value: "42/42" },
        ].span(),
    };
    
    // Store context for verification
    test_contract.set_context_data(1, context);
    
    // Mock the token mint to return ID 1
    mock_token.mock_mint(1);
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Alice The Champion"),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(start_time),
        Option::Some(end_time),
        Option::Some(objectives.span()),
        Option::Some(GameContextDetails {
            name: "Epic Achievement",
            description: "Legendary completion with all secrets",
            id: Option::Some(99),
            context: array![
                GameContext { name: "difficulty", value: "hard" },
                GameContext { name: "score", value: "999999" },
                GameContext { name: "perfect_run", value: "true" },
                GameContext { name: "secrets_found", value: "42/42" },
            ].span(),
        }),
        Option::Some("https://epicgame.com/play"),
        Option::Some(constants::RENDERER_ADDRESS()),
        player,
        false, // Transferable achievement token
    );
    
    // Step 6: Verify token metadata
    assert(token_id == 1, 'Token ID should be 1');
    
    // Step 7: Query token from contracts
    assert(metagame.minigame_token_address() == token_address, 'Token address mismatch');
    
    // Verify context was stored
    let stored_context = context_dispatcher.context(1);
    assert(stored_context.name == "Test Context", 'Context name mismatch');
    assert(stored_context.description == "Test Description", 'Context description mismatch');
    assert(stored_context.id == Option::Some(1), 'Context ID mismatch');
    assert(core::array::SpanTrait::len(stored_context.context) == 2, 'Context len mismatch');
}

// Additional integration test: Multiple mints in sequence
#[test]
fn test_sequential_minting_flow() {
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    let metagame_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    let game_address = constants::GAME_ADDRESS();
    mock_token.mock_is_game_registered(game_address, true);
    
    // Players complete game in sequence
    let players = array![constants::ALICE(), constants::BOB(), constants::RENDERER_ADDRESS()];
    let mut expected_token_id = 1_u64;
    
    let mut i = 0_u32;
    loop {
        if i >= players.len() {
            break;
        }
        
        let player = *players.at(i);
        
        // Mock incremental token IDs
        mock_token.mock_mint_once(expected_token_id);
        
        let token_id = test_contract.test_mint(
            Option::Some(game_address),
            Option::Some(format(i)),
            Option::Some(constants::SETTINGS_ID + i),
            Option::Some(1000000 + (i * 1000).into()),
            Option::Some(1001000 + (i * 1000).into()),
            Option::Some(array![i, i + 1, i + 2].span()),
            Option::None,
            Option::Some(format(i)),
            Option::None,
            player,
            i % 2 == 0, // Alternate soulbound
        );
        
        assert(token_id == expected_token_id, 'Token ID mismatch');
        
        expected_token_id += 1;
        i += 1;
    };
}

// Helper to format u32 to string
fn format(value: u32) -> ByteArray {
    if value == 0 {
        return "0";
    }
    
    let mut result: ByteArray = "";
    let mut remaining = value;
    let mut digits = array![];
    
    loop {
        if remaining == 0 {
            break;
        }
        
        let digit = remaining % 10;
        digits.append(digit);
        remaining = remaining / 10;
    };
    
    // Reverse the digits
    let mut i = digits.len();
    loop {
        if i == 0 {
            break;
        }
        i -= 1;
        let digit = *digits.at(i);
        result += match digit {
            0 => "0",
            1 => "1",
            2 => "2",
            3 => "3",
            4 => "4",
            5 => "5",
            6 => "6",
            7 => "7",
            8 => "8",
            9 => "9",
            _ => "?",
        };
    };
    
    result
}