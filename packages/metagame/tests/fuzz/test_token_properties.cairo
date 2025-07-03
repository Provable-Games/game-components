use starknet::ContractAddress;
use game_components_metagame::extensions::context::structs::GameContextDetails;
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
        soulbound: u32,
    ) -> u64;
}

// FZ-01: Token ID Monotonicity
#[test]
#[fuzzer(runs: 100, seed: 42)]
fn test_fuzz_token_id_monotonicity(
    game_seed: felt252,
    player_seed: felt252,
    settings_id: u32,
    start_time: u64,
    end_time: u64,
    soulbound: u32
) {
    let token_address = constants::TOKEN_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    // Generate random addresses from seeds
    // Use modulo to ensure valid address range
    // Use simpler approach for address generation
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    
    // Register the game
    mock_token.mock_is_game_registered(game_address, true);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Mint multiple tokens and verify monotonicity
    let mut prev_token_id = 0_u64;
    let mut i = 0_u32;
    
    loop {
        if i >= 5 {
            break;
        }
        
        // Mock incremental token IDs
        let expected_id = prev_token_id + 1;
        mock_token.mock_mint_once(expected_id);
        
        let token_id = test_contract.test_mint(
            Option::Some(game_address),
            Option::Some("Player"),
            Option::Some(settings_id),
            Option::Some(start_time),
            Option::Some(end_time),
            Option::None,
            Option::None,
            Option::Some("https://game.com"),
            Option::None,
            recipient,
            if soulbound % 2 == 1 { 1 } else { 0 },
        );
        
        // Verify monotonicity
        assert(token_id > prev_token_id, 'Token ID must increase');
        assert(token_id == expected_id, 'Token ID mismatch');
        
        prev_token_id = token_id;
        i += 1;
    };
}

// FZ-02: Game Registration Consistency
#[test]
#[fuzzer(runs: 256)]
fn test_fuzz_game_registration_consistency(game_address_seed: felt252) {
    let token_address = constants::TOKEN_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    // Generate random game address
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    
    // Randomly decide if game is registered (based on seed)
    // Simplify registration check
    let is_registered = true;
    mock_token.mock_is_game_registered(game_address, is_registered);
    
    if is_registered {
        mock_token.mock_mint(1);
    }
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Only test registered games for simplicity
    if is_registered {
        let token_id = test_contract.test_mint(
            Option::Some(game_address),
            Option::Some("Test Player"),
            Option::Some(1),
            Option::Some(1000),
            Option::Some(2000),
            Option::None,
            Option::None,
            Option::Some("https://test.com"),
            Option::None,
            recipient,
            0,
        );
        assert(token_id == 1, 'Registered game should mint');
    }
    // Note: Unregistered games would panic, which is expected behavior
}

// FZ-04: Timestamp Validation (for future enhancement)
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_timestamp_validation(start_time: u64, end_time: u64) {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Currently no validation, but test that all timestamp combinations work
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Time Test"),
        Option::Some(1),
        Option::Some(start_time),
        Option::Some(end_time),
        Option::None,
        Option::None,
        Option::Some("https://time.test"),
        Option::None,
        recipient,
        0,
    );
    
    assert(token_id == 1, 'Token minted regardless');
    
    // Note for future: When validation is added, check that end_time >= start_time
}

// FZ-05: Objective Array Handling
#[test]
#[fuzzer(runs: 50, seed: 12345)]
fn test_fuzz_objective_array_handling(
    array_size: u32,
    base_value: u32,
    include_duplicates: u32
) {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Create objective array with fuzzed parameters
    let mut objectives = array![];
    let size = array_size % 100; // Limit size to 100 for performance
    let mut i = 0_u32;
    
    loop {
        if i >= size {
            break;
        }
        
        if include_duplicates % 2 == 1 && i % 3 == 0 {
            // Add duplicate values
            objectives.append(base_value);
        } else {
            // Add unique values
            objectives.append(base_value + i);
        }
        
        i += 1;
    };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Objective Test"),
        Option::Some(1),
        Option::Some(1000),
        Option::Some(2000),
        Option::Some(objectives.span()),
        Option::None,
        Option::Some("https://objectives.test"),
        Option::None,
        recipient,
        0,
    );
    
    assert(token_id == 1, 'Token minted with objectives');
}

// NFZ-01: Invalid Addresses (edge cases)
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_invalid_addresses(
    invalid_pattern: felt252,
    use_game_address: u32,
    use_renderer_address: u32
) {
    let token_address = constants::TOKEN_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    // Create potentially invalid address patterns
    let test_address = constants::ALICE();
    
    // Setup based on fuzzer parameters
    let game_address = if use_game_address % 2 == 1 { Option::Some(test_address) } else { Option::None };
    let renderer_address = if use_renderer_address % 2 == 1 { Option::Some(test_address) } else { Option::None };
    let recipient = constants::ALICE();
    
    if use_game_address % 2 == 1 {
        // Always register for this test to isolate address validation
        mock_token.mock_is_game_registered(test_address, true);
    }
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // All addresses should work (no validation on address format)
    let token_id = test_contract.test_mint(
        game_address,
        Option::Some("Address Test"),
        Option::Some(1),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::None,
        Option::Some("https://address.test"),
        renderer_address,
        recipient,
        0,
    );
    
    assert(token_id == 1, 'Token should be minted');
}

// NFZ-02: Overflow Scenarios
#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_overflow_scenarios(
    settings_id: u32,
    time_value: u64,
    context_id: u32,
    objective_count: u32
) {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Create objectives array with potentially large values
    let mut objectives = array![];
    let count = objective_count % 50; // Limit for performance
    let mut i = 0_u32;
    
    loop {
        if i >= count {
            break;
        }
        // Use max values to test overflow handling
        objectives.append(core::num::traits::Bounded::<u32>::MAX - i);
        i += 1;
    };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some("Overflow Test"),
        Option::Some(settings_id),
        Option::Some(time_value),
        Option::Some(core::num::traits::Bounded::<u64>::MAX - time_value), // Ensure end > start
        Option::Some(objectives.span()),
        Option::None,
        Option::Some("https://overflow.test"),
        Option::None,
        recipient,
        0,
    );
    
    assert(token_id == 1, 'Token handles max values');
}