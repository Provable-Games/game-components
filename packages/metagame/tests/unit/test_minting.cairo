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
        soulbound: bool,
    ) -> u64;
    
    fn test_assert_game_registered(ref self: TContractState, game_address: ContractAddress);
}

// MINT-01: Basic mint without context
#[test]
fn test_basic_mint_without_context() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    // Setup mocks
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(1); // Return token ID 1
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Mint token
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None, // No objectives
        Option::None, // No context
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false, // Not soulbound
    );
    
    assert(token_id == 1, 'Token ID mismatch');
}

// MINT-02: Mint with empty objectives array
#[test]
fn test_mint_with_empty_objectives() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::BOB();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(2);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let empty_objectives: Array<u32> = array![];
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::Some(empty_objectives.span()),
        Option::None,
        Option::Some(constants::CLIENT_URL()),
        Option::None, // No renderer
        recipient,
        false,
    );
    
    assert(token_id == 2, 'Token ID mismatch');
}

// MINT-03: Mint with multiple objectives
#[test]
fn test_mint_with_multiple_objectives() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(3);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let objectives = helpers::create_test_objectives();
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::Some(objectives.span()),
        Option::None,
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false,
    );
    
    assert(token_id == 3, 'Token ID mismatch');
}

// MINT-04: Mint to zero address - should fail in token contract
// Note: We test that the call succeeds in metagame, actual validation happens in token contract
#[test]
fn test_mint_to_zero_address() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let zero_address = constants::ZERO_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    // Mock the token contract to simulate rejection
    mock_token.mock_mint(0); // Return 0 to indicate failure
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::None,
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        zero_address,
        false,
    );
    
    // Token contract would return 0 or revert
    assert(token_id == 0, 'Token ID should be 0');
}

// MINT-05: Mint from unregistered game
#[test]
#[should_panic(expected: ('Game is not registered', ))]
fn test_mint_from_unregistered_game() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, false); // Not registered
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Should revert with "Game is not registered"
    test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::None,
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false,
    );
}

// MINT-06: Mint soulbound token
#[test]
fn test_mint_soulbound_token() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(4);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::None,
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        true, // Soulbound
    );
    
    assert(token_id == 4, 'Token ID mismatch');
}

// MINT-07: Mint transferable token
#[test]
fn test_mint_transferable_token() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::BOB();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(5);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::None,
        Option::None,
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false, // Transferable
    );
    
    assert(token_id == 5, 'Token ID mismatch');
}

// Additional test: Mint with all optional parameters as None
#[test]
fn test_mint_minimal_parameters() {
    let token_address = constants::TOKEN_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    // When game_address is None, no registration check is performed
    mock_token.mock_mint(6);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    let token_id = test_contract.test_mint(
        Option::None, // No game address
        Option::None, // No player name
        Option::None, // No settings
        Option::None, // No start time
        Option::None, // No end time
        Option::None, // No objectives
        Option::None, // No context
        Option::None, // No client URL
        Option::None, // No renderer
        recipient,
        false,
    );
    
    assert(token_id == 6, 'Token ID mismatch');
}

// Additional test: Mint with very large objective array
#[test]
fn test_mint_with_large_objectives_array() {
    let token_address = constants::TOKEN_ADDRESS();
    let game_address = constants::GAME_ADDRESS();
    let recipient = constants::ALICE();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let mock_token = MockMinigameTokenTrait::new(token_address);
    mock_token.mock_is_game_registered(game_address, true);
    mock_token.mock_mint(7);
    
    let test_contract = IMockMetagameTestDispatcher { contract_address };
    
    // Create large objectives array
    let mut objectives = array![];
    let mut i: u32 = 0;
    loop {
        if i >= 100 {
            break;
        }
        objectives.append(i);
        i += 1;
    };
    
    let token_id = test_contract.test_mint(
        Option::Some(game_address),
        Option::Some(constants::PLAYER_NAME()),
        Option::Some(constants::SETTINGS_ID),
        Option::Some(constants::TIME_START),
        Option::Some(constants::TIME_END),
        Option::Some(objectives.span()),
        Option::None,
        Option::Some(constants::CLIENT_URL()),
        Option::Some(constants::RENDERER_ADDRESS()),
        recipient,
        false,
    );
    
    assert(token_id == 7, 'Token ID mismatch');
}