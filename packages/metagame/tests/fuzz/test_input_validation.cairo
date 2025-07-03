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
}

// Test various combinations of optional parameters
#[test]
#[fuzzer(runs: 200)]
fn test_fuzz_optional_parameters_combinations(
    has_game_address: u32,
    has_player_name: u32,
    has_settings: u32,
    has_times: u32,
    has_objectives: u32,
    has_client_url: u32,
    has_renderer: u32,
    token_id_seed: u64
) {
    let token_address = constants::TOKEN_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    // Prepare optional parameters based on fuzzer inputs
    let game_address = if has_game_address % 2 == 1 {
        let addr = constants::GAME_ADDRESS();
        mock_token.mock_is_game_registered(addr, true);
        Option::Some(addr)
    } else {
        Option::None
    };
    
    let player_name = if has_player_name % 2 == 1 { 
        Option::Some("Fuzzed Player") 
    } else { 
        Option::None 
    };
    
    let settings_id = if has_settings % 2 == 1 { 
        Option::Some(42_u32) 
    } else { 
        Option::None 
    };
    
    let (start, end) = if has_times % 2 == 1 {
        (Option::Some(1000_u64), Option::Some(2000_u64))
    } else {
        (Option::None, Option::None)
    };
    
    let objectives = if has_objectives % 2 == 1 {
        let arr = array![1_u32, 2_u32, 3_u32];
        Option::Some(arr.span())
    } else {
        Option::None
    };
    
    let client_url = if has_client_url % 2 == 1 {
        Option::Some("https://fuzzed.game")
    } else {
        Option::None
    };
    
    let renderer_address = if has_renderer % 2 == 1 {
        Option::Some(constants::RENDERER_ADDRESS())
    } else {
        Option::None
    };
    
    // Mock token ID based on seed
    let expected_id = (token_id_seed % 1000) + 1;
    mock_token.mock_mint(expected_id);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let token_id = test_contract.test_mint(
        game_address,
        player_name,
        settings_id,
        start,
        end,
        objectives,
        Option::None, // No context for this test
        client_url,
        renderer_address,
        constants::ALICE(),
        false,
    );
    
    assert(token_id == expected_id, 'Token minted with any params');
}

// Test string length boundaries
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_string_length_boundaries(
    player_name_length: u32,
    client_url_length: u32,
    use_special_chars: u32
) {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Generate strings of specific lengths
    let player_name = generate_test_string("Player_", player_name_length % 500, use_special_chars % 2 == 1);
    let client_url = generate_test_string("https://", client_url_length % 1000, false);
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(player_name),
        Option::Some(1),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::None,
        Option::Some(client_url),
        Option::None,
        constants::ALICE(),
        false,
    );
    
    assert(token_id == 1, 'Token handles various string lengths');
}

// Test numeric boundaries and edge cases
#[test]
#[fuzzer(runs: 150)]
fn test_fuzz_numeric_boundaries(
    settings_id: u32,
    start_time: u64,
    end_time: u64,
    num_objectives: u32,
    objective_base: u32
) {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Create objectives array with boundary values
    let mut objectives = array![];
    let count = num_objectives % 50; // Limit for performance
    
    if count > 0 {
        // Add edge case values
        objectives.append(0); // Min value
        objectives.append(core::num::traits::Bounded::<u32>::MAX); // Max value
        
        // Add regular values
        let mut i = 2_u32;
        loop {
            if i >= count {
                break;
            }
            objectives.append(objective_base.wrapping_add(i));
            i += 1;
        };
    }
    
    let objectives_option = if count > 0 {
        Option::Some(objectives.span())
    } else {
        Option::None
    };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Numeric Test"),
        Option::Some(settings_id),
        Option::Some(start_time),
        Option::Some(end_time),
        objectives_option,
        Option::None,
        Option::Some("https://numeric.test"),
        Option::None,
        constants::ALICE(),
        false,
    );
    
    assert(token_id == 1, 'Token handles numeric boundaries');
}

// Test address parameter variations
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_address_variations(
    recipient_seed: felt252,
    renderer_seed: felt252,
    use_same_address: u32,
    use_zero_recipient: u32
) {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Generate addresses based on seeds
    let base_recipient: ContractAddress = starknet::contract_address_const::<0>() + recipient_seed.into();
    let renderer_address: ContractAddress = if use_same_address % 2 == 1 {
        base_recipient
    } else {
        starknet::contract_address_const::<0>() + renderer_seed.into()
    };
    
    let recipient = if use_zero_recipient % 2 == 1 {
        constants::ZERO_ADDRESS()
    } else {
        base_recipient
    };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Address Test"),
        Option::Some(1),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::None,
        Option::Some("https://address.test"),
        Option::Some(renderer_address),
        recipient,
        false,
    );
    
    assert(token_id == 1, 'Token handles various addresses');
}

// Helper function to generate test strings
fn generate_test_string(prefix: ByteArray, length: u32, include_special: bool) -> ByteArray {
    let mut result = prefix;
    let mut i = 0_u32;
    
    loop {
        if i >= length {
            break;
        }
        
        if include_special && i % 10 == 0 {
            // Add special characters periodically
            result += match i % 5 {
                0 => "!",
                1 => "@",
                2 => "#",
                3 => "$",
                _ => "%",
            };
        } else {
            // Add regular alphanumeric
            let char_index = i % 36;
            if char_index < 10 {
                // Digits 0-9
                result += match char_index {
                    0 => "0",
                    1 => "1",
                    2 => "2",
                    3 => "3",
                    4 => "4",
                    5 => "5",
                    6 => "6",
                    7 => "7",
                    8 => "8",
                    _ => "9",
                };
            } else {
                // Letters a-z
                let letter_index = char_index - 10;
                result += match letter_index {
                    0 => "a", 1 => "b", 2 => "c", 3 => "d", 4 => "e",
                    5 => "f", 6 => "g", 7 => "h", 8 => "i", 9 => "j",
                    10 => "k", 11 => "l", 12 => "m", 13 => "n", 14 => "o",
                    15 => "p", 16 => "q", 17 => "r", 18 => "s", 19 => "t",
                    20 => "u", 21 => "v", 22 => "w", 23 => "x", 24 => "y",
                    _ => "z",
                };
            }
        }
        
        i += 1;
    };
    
    result
}

// Extension trait for wrapping addition
trait WrappingAdd<T> {
    fn wrapping_add(self: T, other: T) -> T;
}

impl WrappingAddU32 of WrappingAdd<u32> {
    fn wrapping_add(self: u32, other: u32) -> u32 {
        // Simple wrapping add for u32
        let max = core::num::traits::Bounded::<u32>::MAX;
        if self > max - other {
            // Overflow case
            self - (max - other + 1)
        } else {
            self + other
        }
    }
}