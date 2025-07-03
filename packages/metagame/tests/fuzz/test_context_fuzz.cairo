use starknet::ContractAddress;
use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
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

// Interface for retrieving context data
#[starknet::interface]
trait IMetagameContextTest<TContractState> {
    fn game_context(self: @TContractState, token_id: u64) -> GameContextDetails;
}

// FZ-03: Context Data Integrity
#[test]
#[fuzzer(runs: 100, seed: 9876)]
fn test_fuzz_context_data_integrity(
    name_length: u32,
    description_length: u32,
    context_id: u32,
    num_entries: u32,
    key_length: u32,
    value_length: u32
) {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    // Deploy with context support
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, true);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    let context_contract = IMetagameContextTestDispatcher { contract_address };
    
    // Generate context data based on fuzzer inputs
    let name = generate_string("Name_", name_length % 100); // Limit to 100 chars
    let description = generate_string("Desc_", description_length % 200); // Limit to 200 chars
    
    let mut context_data = array![];
    let entries = num_entries % 20; // Limit to 20 entries for performance
    let mut i = 0_u32;
    
    loop {
        if i >= entries {
            break;
        }
        
        let name = generate_string("key_", (key_length + i) % 50);
        let value = generate_string("val_", (value_length + i) % 100);
        
        context_data.append(GameContext { name, value });
        i += 1;
    };
    
    let context = GameContextDetails {
        name: name.clone(),
        description: description.clone(),
        id: Option::Some(context_id),
        context: context_data.span(),
    };
    
    // Create a copy for minting
    let mint_context = GameContextDetails {
        name: context.name.clone(),
        description: context.description.clone(),
        id: context.id,
        context: context.context.clone(),
    };
    
    // Store expected context
    test_contract.set_context_data(1, context);
    
    // Mint with context
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Context Fuzz"),
        Option::Some(1),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::Some(mint_context),
        Option::Some("https://context.test"),
        Option::None,
        recipient,
        false,
    );
    
    assert(token_id == 1, 'Token ID should be 1');
    
    // Verify context integrity
    let stored_context = context_contract.game_context(1);
    assert(stored_context.name == name, 'Context name mismatch');
    assert(stored_context.description == description, 'Context description mismatch');
    assert(stored_context.id == Option::Some(context_id), 'Context ID mismatch');
    assert(stored_context.context.len() == context_data.len(), 'Context data length mismatch');
}

// Test context with special characters and edge cases
#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_context_special_characters(
    include_quotes: u32,
    include_newlines: u32,
    include_unicode: u32,
    include_json: u32,
    data_entries: u32
) {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, true);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Build context with special characters based on fuzzer inputs
    let mut name = "Context";
    let mut description = "Test";
    
    if include_quotes % 2 == 1 {
        name = "Context with \"quotes\" and 'apostrophes'";
    }
    
    if include_newlines % 2 == 1 {
        description = "Line1\nLine2\nLine3";
    }
    
    let mut context_data = array![];
    
    if include_json % 2 == 1 {
        context_data.append(
            GameContext { 
                name: "json", 
                value: "{\"test\":true,\"value\":123,\"array\":[1,2,3]}" 
            }
        );
    }
    
    if include_unicode % 2 == 1 {
        context_data.append(
            GameContext { 
                name: "special", 
                value: "!@#$%^&*()_+-=[]{}|;:,.<>?/~`" 
            }
        );
    }
    
    // Add random entries
    let entries = data_entries % 10;
    let mut i = 0_u32;
    loop {
        if i >= entries {
            break;
        }
        context_data.append(
            GameContext { 
                name: format("key_", i), 
                value: format("value_", i) 
            }
        );
        i += 1;
    };
    
    let context = GameContextDetails {
        name,
        description,
        id: Option::Some(999),
        context: context_data.span(),
    };
    
    // Create a copy for storing
    let store_context = GameContextDetails {
        name: context.name.clone(),
        description: context.description.clone(),
        id: context.id,
        context: context.context.clone(),
    };
    
    // Store expected context
    test_contract.set_context_data(1, store_context);
    
    // Mint with special context
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Special Chars"),
        Option::Some(1),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::Some(context),
        Option::Some("https://special.test"),
        Option::None,
        recipient,
        false,
    );
    
    assert(token_id == 1, 'Token minted with special chars');
}

// Test empty and boundary context cases
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_context_boundaries(
    use_empty_name: u32,
    use_empty_description: u32,
    use_zero_id: u32,
    use_empty_data: u32,
    use_max_id: u32
) {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, true);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Build context based on fuzzer inputs
    let name = if use_empty_name % 2 == 1 { "" } else { "Normal Name" };
    let description = if use_empty_description % 2 == 1 { "" } else { "Normal Description" };
    let id = if use_zero_id % 2 == 1 { 
        0 
    } else if use_max_id % 2 == 1 { 
        core::num::traits::Bounded::<u32>::MAX 
    } else { 
        12345 
    };
    
    let data = if use_empty_data % 2 == 1 {
        array![]
    } else {
        array![GameContext { name: "test", value: "value" }]
    };
    
    let context = GameContextDetails {
        name,
        description,
        id: Option::Some(id),
        context: data.span(),
    };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Boundary Test"),
        Option::Some(1),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::Some(context),
        Option::Some("https://boundary.test"),
        Option::None,
        recipient,
        false,
    );
    
    assert(token_id == 1, 'Token handles boundary values');
}

// Helper function to generate strings
fn generate_string(prefix: ByteArray, length: u32) -> ByteArray {
    let mut result = prefix;
    let mut i = 0_u32;
    
    loop {
        if i >= length {
            break;
        }
        
        // Add alphanumeric characters
        let char_index = i % 26;
        result += match char_index {
            0 => "A", 1 => "B", 2 => "C", 3 => "D", 4 => "E",
            5 => "F", 6 => "G", 7 => "H", 8 => "I", 9 => "J",
            10 => "K", 11 => "L", 12 => "M", 13 => "N", 14 => "O",
            15 => "P", 16 => "Q", 17 => "R", 18 => "S", 19 => "T",
            20 => "U", 21 => "V", 22 => "W", 23 => "X", 24 => "Y",
            _ => "Z",
        };
        i += 1;
    };
    
    result
}

// Helper to format numbers with prefix
fn format(prefix: ByteArray, value: u32) -> ByteArray {
    let mut result: ByteArray = prefix;
    
    // Convert number to string
    let num_str = format_number(value);
    result += num_str;
    
    result
}

// Helper to format numbers
fn format_number(value: u32) -> ByteArray {
    // Simple number to string conversion
    if value == 0 {
        return "0";
    }
    
    let mut result: ByteArray = Default::default();
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