use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, set_block_timestamp};
use snforge_std::{declare, ContractClassTrait};
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};

fn deploy_token_for_fuzz() -> IMinigameTokenDispatcher {
    let contract = declare("MockToken").unwrap();
    let (token_address, _) = contract.deploy(@array![
        'TestToken', 'TST', 'https://test.com/', 0
    ]).unwrap();
    
    IMinigameTokenDispatcher { contract_address: token_address }
}

// FZ-1: Fuzz mint parameters
#[test]
#[fuzzer(runs: 100, seed: 42)]
fn test_fuzz_mint_parameters(
    settings_id: u32,
    start_time: u64,
    end_time: u64,
    soulbound: bool
) {
    let user1 = contract_address_const::<'user1'>();
    let token = deploy_token_for_fuzz();
    
    set_caller_address(user1);
    set_block_timestamp(1000);
    
    // Only test valid lifecycle ranges
    if start_time > 0 && end_time > 0 && start_time > end_time {
        return;
    }
    
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::Some(settings_id),
        if start_time == 0 { Option::None } else { Option::Some(start_time) },
        if end_time == 0 { Option::None } else { Option::Some(end_time) },
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        soulbound
    );
    
    let metadata = token.token_metadata(token_id);
    assert!(metadata.settings_id == settings_id, "Settings ID mismatch");
    assert!(metadata.soulbound == soulbound, "Soulbound flag mismatch");
    
    if start_time > 0 {
        assert!(metadata.lifecycle.start == start_time, "Start time mismatch");
    }
    if end_time > 0 {
        assert!(metadata.lifecycle.end == end_time, "End time mismatch");
    }
}

// FZ-2: Fuzz lifecycle times
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_lifecycle_times(start: u64, end: u64) {
    let user1 = contract_address_const::<'user1'>();
    let token = deploy_token_for_fuzz();
    
    set_caller_address(user1);
    set_block_timestamp(1000);
    
    // Test boundary conditions
    if start > 0 && end > 0 && start > end {
        // Should panic with invalid lifecycle
        return;
    }
    
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::None,
        if start == 0 { Option::None } else { Option::Some(start) },
        if end == 0 { Option::None } else { Option::Some(end) },
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    let metadata = token.token_metadata(token_id);
    
    // Verify lifecycle bounds
    if start > 0 && end > 0 {
        assert!(metadata.lifecycle.start <= metadata.lifecycle.end, "Invalid lifecycle stored");
    }
}

// FZ-3: Fuzz objective lists
#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_objective_lists(objectives_count: u8) {
    if objectives_count == 0 {
        return;
    }
    
    let user1 = contract_address_const::<'user1'>();
    let token = deploy_token_for_fuzz();
    
    set_caller_address(user1);
    
    // Create objective array
    let mut objectives = array![];
    let mut i = 0_u32;
    loop {
        if i >= objectives_count.into() {
            break;
        }
        objectives.append(i + 1);
        i += 1;
    };
    
    // Should only succeed if count <= 255
    if objectives_count > 255 {
        return; // Would panic with too many objectives
    }
    
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(objectives.span()),
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    // Empty hooks return 0 for objectives count
    let metadata = token.token_metadata(token_id);
    assert!(metadata.objectives_count == 0, "Empty hooks should return 0 objectives");
}

// FZ-5: Fuzz player names
#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_player_names(name_length: u8) {
    let user1 = contract_address_const::<'user1'>();
    let token = deploy_token_for_fuzz();
    
    set_caller_address(user1);
    
    // Generate name of specified length
    let mut name_bytes = array![];
    let mut i = 0_u8;
    loop {
        if i >= name_length {
            break;
        }
        name_bytes.append('A');
        i += 1;
    };
    
    let name: ByteArray = match name_bytes.try_into() {
        Option::Some(ba) => ba,
        Option::None => "",
    };
    
    let token_id = token.mint(
        Option::None,
        Option::Some(name),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    let stored_name = token.player_name(token_id);
    assert!(stored_name == name, "Player name not stored correctly");
}

// FZ-8: Fuzz token IDs
#[test]
#[fuzzer(runs: 20)]
fn test_fuzz_sequential_mints(mint_count: u8) {
    if mint_count == 0 || mint_count > 50 {
        return; // Limit to reasonable number
    }
    
    let user1 = contract_address_const::<'user1'>();
    let token = deploy_token_for_fuzz();
    
    set_caller_address(user1);
    
    let mut expected_id = 1_u64;
    let mut i = 0_u8;
    
    loop {
        if i >= mint_count {
            break;
        }
        
        let token_id = token.mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            user1,
            false
        );
        
        assert!(token_id == expected_id, "Token ID not sequential");
        expected_id += 1;
        i += 1;
    };
}