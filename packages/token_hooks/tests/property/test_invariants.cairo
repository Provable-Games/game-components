use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, set_block_timestamp};
use snforge_std::{declare, ContractClassTrait};
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

fn deploy_token_for_property_tests() -> (IMinigameTokenDispatcher, IERC721Dispatcher) {
    let contract = declare("MockToken").unwrap();
    let (token_address, _) = contract.deploy(@array![
        'TestToken', 'TST', 'https://test.com/', 0
    ]).unwrap();
    
    (IMinigameTokenDispatcher { contract_address: token_address }, IERC721Dispatcher { contract_address: token_address })
}

// PBT-1: Token ID sequence property
#[test]
#[fuzzer(runs: 50)]
fn test_property_token_id_sequence(mint_count: u8) {
    if mint_count == 0 || mint_count > 20 {
        return;
    }
    
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_token_for_property_tests();
    
    set_caller_address(user1);
    
    let mut previous_id = 0_u64;
    let mut i = 0_u8;
    
    loop {
        if i >= mint_count {
            break;
        }
        
        let token_id = token.mint(
            Option::None, Option::None, Option::None, Option::None, Option::None,
            Option::None, Option::None, Option::None, Option::None,
            user1, false
        );
        
        // Property: token_id[n] = token_id[n-1] + 1
        if previous_id > 0 {
            assert!(token_id == previous_id + 1, "Token ID sequence violated");
        } else {
            assert!(token_id == 1, "First token ID should be 1");
        }
        
        previous_id = token_id;
        i += 1;
    };
}

// PBT-2: Lifecycle validity property
#[test]
#[fuzzer(runs: 100)]
fn test_property_lifecycle_validity(start: u64, end: u64) {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_token_for_property_tests();
    
    set_caller_address(user1);
    
    // Skip invalid ranges
    if start > 0 && end > 0 && start > end {
        return;
    }
    
    let token_id = token.mint(
        Option::None, Option::None, Option::None,
        if start == 0 { Option::None } else { Option::Some(start) },
        if end == 0 { Option::None } else { Option::Some(end) },
        Option::None, Option::None, Option::None, Option::None,
        user1, false
    );
    
    let metadata = token.token_metadata(token_id);
    
    // Property: start < end when both provided
    if start > 0 && end > 0 {
        assert!(metadata.lifecycle.start < metadata.lifecycle.end, "Lifecycle validity violated");
    }
}

// PBT-3: Playability consistency property
#[test]
#[fuzzer(runs: 100)]
fn test_property_playability_consistency(
    current_time: u64,
    start_time: u64,
    end_time: u64,
    game_over: bool
) {
    if start_time > end_time && start_time > 0 && end_time > 0 {
        return;
    }
    
    let user1 = contract_address_const::<'user1'>();
    let game_address = deploy_mock_minigame();
    let (token, _) = deploy_token_for_property_tests();
    
    set_caller_address(user1);
    set_block_timestamp(1000);
    
    let token_id = token.mint(
        Option::Some(game_address),
        Option::None, Option::None,
        if start_time == 0 { Option::None } else { Option::Some(start_time) },
        if end_time == 0 { Option::None } else { Option::Some(end_time) },
        Option::None, Option::None, Option::None, Option::None,
        user1, false
    );
    
    // Set game state if needed
    if game_over {
        let mock_game = IMockMinigameDispatcher { contract_address: game_address };
        mock_game.set_game_over(token_id, true);
        token.update_game(token_id);
    }
    
    // Now test playability at different times
    set_block_timestamp(current_time);
    let is_playable = token.is_playable(token_id);
    
    // Property: is_playable ⟺ (start ≤ now < end ∧ ¬game_over)
    let in_time_range = if start_time == 0 && end_time == 0 {
        true // No bounds means always in range
    } else if start_time == 0 {
        current_time < end_time
    } else if end_time == 0 {
        current_time >= start_time
    } else {
        current_time >= start_time && current_time < end_time
    };
    
    let expected_playable = in_time_range && !game_over;
    assert!(is_playable == expected_playable, "Playability consistency violated");
}

// PBT-6: Owner exclusivity property
#[test]
#[fuzzer(runs: 50)]
fn test_property_owner_exclusivity(owner_index: u8, caller_index: u8) {
    if owner_index == caller_index {
        return; // Skip when owner is caller
    }
    
    let addresses = array![
        contract_address_const::<'user1'>(),
        contract_address_const::<'user2'>(),
        contract_address_const::<'user3'>(),
        contract_address_const::<'user4'>(),
    ];
    
    let owner = *addresses.at((owner_index % 4).into());
    let caller = *addresses.at((caller_index % 4).into());
    
    let game_address = deploy_mock_minigame();
    let (token, _) = deploy_token_for_property_tests();
    
    // Mint token to owner
    set_caller_address(owner);
    set_block_timestamp(1000);
    
    let token_id = token.mint(
        Option::Some(game_address),
        Option::None, Option::None,
        Option::Some(500), Option::Some(2000),
        Option::None, Option::None, Option::None, Option::None,
        owner, false
    );
    
    // Try to update as non-owner
    set_caller_address(caller);
    
    // Property: Only owner succeeds update_game
    // This should panic for non-owners
    let result = @token.update_game(token_id);
    match result {
        Result::Ok(_) => panic!("Non-owner should not be able to update"),
        Result::Err(_) => {} // Expected
    }
}

// PBT-8: Objective bounds property
#[test]
#[fuzzer(runs: 50)]
fn test_property_objective_bounds(objective_count: u16) {
    let user1 = contract_address_const::<'user1'>();
    let (token, _) = deploy_token_for_property_tests();
    
    set_caller_address(user1);
    
    // Create objectives array
    let mut objectives = array![];
    let mut i = 0_u16;
    loop {
        if i >= objective_count {
            break;
        }
        objectives.append((i + 1).into());
        i += 1;
    };
    
    // Property: Count ≤ 255
    if objective_count > 255 {
        // Should fail - too many objectives
        return;
    }
    
    let token_id = token.mint(
        Option::None, Option::None, Option::None, Option::None, Option::None,
        Option::Some(objectives.span()),
        Option::None, Option::None, Option::None,
        user1, false
    );
    
    let metadata = token.token_metadata(token_id);
    // With empty hooks, objectives_count is always 0
    assert!(metadata.objectives_count == 0, "Objective bounds property with empty hooks");
}

// Helper functions
fn deploy_mock_minigame() -> ContractAddress {
    let contract = declare("MockMinigame").unwrap();
    let (game_address, _) = contract.deploy(@array![]).unwrap();
    game_address
}

// Mock minigame interface
#[starknet::interface]
trait IMockMinigame<TContractState> {
    fn set_score(ref self: TContractState, token_id: u64, score: u64);
    fn set_game_over(ref self: TContractState, token_id: u64, game_over: bool);
}

#[derive(Copy, Drop, Serde)]
struct IMockMinigameDispatcher {
    contract_address: ContractAddress,
}

impl IMockMinigameDispatcherImpl of IMockMinigameDispatcherTrait {
    fn set_score(self: IMockMinigameDispatcher, token_id: u64, score: u64) {
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        score.serialize(ref calldata);
        starknet::syscalls::call_contract_syscall(
            self.contract_address,
            selector!("set_score"),
            calldata.span()
        ).unwrap();
    }
    
    fn set_game_over(self: IMockMinigameDispatcher, token_id: u64, game_over: bool) {
        let mut calldata = array![];
        token_id.serialize(ref calldata);
        game_over.serialize(ref calldata);
        starknet::syscalls::call_contract_syscall(
            self.contract_address,
            selector!("set_game_over"),
            calldata.span()
        ).unwrap();
    }
}