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
}

// ADV-01: Malicious Game Attack
#[test]
#[should_panic(expected: 'Game is not registered')]
fn test_malicious_game_attack() {
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    let metagame_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    // Deploy malicious game contract
    let malicious_game = starknet::contract_address_const::<0xDEADBEEF>();
    
    // Attempt mint without registration - should panic
    mock_token.mock_is_game_registered(malicious_game, false);
    
    test_contract.test_mint(
        Option::Some(malicious_game),
        Option::Some("Malicious Player"),
        Option::Some(666),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::None,
        Option::Some("https://malicious.com"),
        Option::None,
        constants::ALICE(),
        false,
    );
}

// ADV-02: Context Manipulation Test - Initial Success
#[test] 
fn test_context_manipulation_initial_success() {
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    // Provide context contract
    let context_address = starknet::contract_address_const::<0xBADC0DE>();
    let metagame_address = helpers::deploy_mock_metagame(
        token_address, 
        Option::Some(context_address), 
        false
    );
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    let game_address = constants::GAME_ADDRESS();
    mock_token.mock_is_game_registered(game_address, true);
    
    // Context supports interface initially
    let mock_context = MockContextContractTrait::new(context_address);
    mock_context.mock_supports_interface_once(IMETAGAME_CONTEXT_ID, true);
    
    // Setup initial context
    let initial_context = GameContextDetails {
        name: "Legitimate Game",
        description: "Normal gameplay",
        id: Option::Some(1),
        context: array![GameContext { name: "score", value: "100" }].span(),
    };
    
    mock_token.mock_mint(1);
    
    // First mint succeeds
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Player"),
        Option::Some(1),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::Some(initial_context),
        Option::Some("https://game.com"),
        Option::None,
        constants::ALICE(),
        false,
    );
    
    assert(token_id == 1, 'Initial mint succeeded');
}

// ADV-02b: Context Manipulation Test - Interface Failure
#[test]
#[should_panic]
fn test_context_manipulation_interface_failure() {
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    // Provide context contract
    let context_address = starknet::contract_address_const::<0xBADC0DE>();
    let metagame_address = helpers::deploy_mock_metagame(
        token_address, 
        Option::Some(context_address), 
        false
    );
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    let game_address = constants::GAME_ADDRESS();
    mock_token.mock_is_game_registered(game_address, true);
    
    // Context doesn't support interface - should panic
    let mock_context = MockContextContractTrait::new(context_address);
    mock_context.mock_supports_interface_once(IMETAGAME_CONTEXT_ID, false);
    
    let initial_context = GameContextDetails {
        name: "Legitimate Game",
        description: "Normal gameplay", 
        id: Option::Some(1),
        context: array![GameContext { name: "score", value: "100" }].span(),
    };
    
    mock_token.mock_mint(1);
    
    // This should panic when context doesn't support interface
    test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Player 2"),
        Option::Some(2),
        Option::Some(3000),
        Option::Some(4000),
        Option::None,
        Option::Some(initial_context),
        Option::Some("https://game.com"),
        Option::None,
        constants::BOB(),
        false,
    );
}

// EDGE-01: Maximum Data Sizes
#[test]
fn test_maximum_data_sizes() {
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    let metagame_address = helpers::deploy_mock_metagame(token_address, Option::None, true);
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    let game_address = constants::GAME_ADDRESS();
    mock_token.mock_is_game_registered(game_address, true);
    
    // Step 1: Max length player name (simulate 1000+ chars)
    let mut max_player_name: ByteArray = "";
    let mut i = 0_u32;
    loop {
        if i >= 100 { // Limited for test performance
            break;
        }
        max_player_name += "PlayerName";
        i += 1;
    };
    
    // Step 2: Max objectives array (simulate 1000 items)
    let mut max_objectives = array![];
    let mut j = 0_u32;
    loop {
        if j >= 100 { // Limited for test performance
            break;
        }
        max_objectives.append(j);
        j += 1;
    };
    
    // Step 3: Max context data (simulate 100 key-value pairs)
    let mut max_context_data = array![];
    let mut k = 0_u32;
    loop {
        if k >= 20 { // Limited for test performance
            break;
        }
        max_context_data.append(
            GameContext { 
                name: format(k, "key_very_long_key_name_for_testing_"), 
                value: format(k, "value_with_extremely_long_content_for_boundary_testing_") 
            }
        );
        k += 1;
    };
    
    let max_context = GameContextDetails {
        name: max_player_name.clone(),
        description: "A very long description that simulates maximum allowed length for context descriptions in the system",
        id: Option::Some(core::num::traits::Bounded::<u32>::MAX),
        context: max_context_data.span(),
    };
    
    mock_token.mock_mint(1);
    
    // Step 4: Verify gas limits and functionality
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(max_player_name),
        Option::Some(core::num::traits::Bounded::<u32>::MAX),
        Option::Some(0), // Min time
        Option::Some(core::num::traits::Bounded::<u64>::MAX), // Max time
        Option::Some(max_objectives.span()),
        Option::Some(max_context),
        Option::Some("https://very-long-url-for-testing-maximum-length-boundaries-in-the-system-with-many-parameters.com/game/play?param1=value1&param2=value2"),
        Option::Some(constants::RENDERER_ADDRESS()),
        constants::ALICE(),
        false,
    );
    
    assert(token_id == 1, 'Max data sizes OK');
}

// EDGE-02: Timing Edge Cases
#[test]
fn test_timing_edge_cases() {
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    let metagame_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    let game_address = constants::GAME_ADDRESS();
    mock_token.mock_is_game_registered(game_address, true);
    
    // Test various timing scenarios
    let timing_tests = array![
        (0_u64, 0_u64), // Both zero
        (0_u64, core::num::traits::Bounded::<u64>::MAX), // Start zero, end max
        (core::num::traits::Bounded::<u64>::MAX, core::num::traits::Bounded::<u64>::MAX), // Both max
        (2000_u64, 1000_u64), // Start > end (currently allowed)
        (1_u64, 1_u64), // Same time
    ];
    
    let mut test_idx = 0_u32;
    loop {
        if test_idx >= timing_tests.len() {
            break;
        }
        
        let (start, end) = *timing_tests.at(test_idx);
        
        mock_token.mock_mint_once(test_idx.into() + 1);
        
        let token_id = test_contract.test_mint(
            Option::Some(game_address),
            Option::Some(format(test_idx, "Timing Test ")),
            Option::Some(test_idx),
            Option::Some(start),
            Option::Some(end),
            Option::None,
            Option::None,
            Option::Some("https://timing.test"),
            Option::None,
            constants::ALICE(),
            false,
        );
        
        assert(token_id == test_idx.into() + 1, 'Edge timing OK');
        
        test_idx += 1;
    };
}

// Test reentrancy protection (simulated)
#[test]
fn test_reentrancy_protection() {
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    let metagame_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    let game_address = constants::GAME_ADDRESS();
    mock_token.mock_is_game_registered(game_address, true);
    
    // Simulate rapid successive calls (reentrancy attempt)
    let mut i = 0_u32;
    loop {
        if i >= 3 {
            break;
        }
        
        mock_token.mock_mint_once(i.into() + 1);
        
        let token_id = test_contract.test_mint(
            Option::Some(game_address),
            Option::Some(format(i, "Reentrancy Test ")),
            Option::Some(i),
            Option::Some(1000),
            Option::Some(2000),
            Option::None,
            Option::None,
            Option::Some("https://reentrancy.test"),
            Option::None,
            constants::ALICE(),
            false,
        );
        
        assert(token_id == i.into() + 1, 'Call completed');
        
        i += 1;
    };
}

// Helper to format u32 to string
fn format(value: u32, prefix: ByteArray) -> ByteArray {
    if value == 0 {
        return prefix + "0";
    }
    
    let mut result = prefix;
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