use starknet::ContractAddress;
use game_components_metagame::interface::{IMetagameDispatcher, IMetagameDispatcherTrait};
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
}

// INT-02: Multi-Game Tournament
#[test]
fn test_multi_game_tournament() {
    // Step 1: Deploy shared infrastructure
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    let metagame_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    let metagame = IMetagameDispatcher { contract_address: metagame_address };
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    // Step 2: Register multiple games
    let game1_address = constants::GAME_ADDRESS();
    let game2_address = constants::ALICE(); // Using different address for game 2
    let game3_address = constants::BOB(); // Using different address for game 3
    
    mock_token.mock_is_game_registered(game1_address, true);
    mock_token.mock_is_game_registered(game2_address, true);
    mock_token.mock_is_game_registered(game3_address, true);
    
    // Step 3: Different games mint tokens
    let player = constants::RENDERER_ADDRESS();
    let mut token_ids = array![];
    
    // Game 1 mints token
    mock_token.mock_mint_once(1);
    let token1 = test_contract.test_mint(
        Option::Some(game1_address),
        Option::Some("Tournament Player"),
        Option::Some(101),
        Option::Some(1000000),
        Option::Some(1001000),
        Option::Some(array![1, 2, 3].span()),
        Option::None,
        Option::Some("https://game1.tournament.com"),
        Option::None,
        player,
        false,
    );
    token_ids.append(token1);
    
    // Game 2 mints token
    mock_token.mock_mint_once(2);
    let token2 = test_contract.test_mint(
        Option::Some(game2_address),
        Option::Some("Tournament Player"),
        Option::Some(201),
        Option::Some(1002000),
        Option::Some(1003000),
        Option::Some(array![10, 20, 30].span()),
        Option::None,
        Option::Some("https://game2.tournament.com"),
        Option::None,
        player,
        false,
    );
    token_ids.append(token2);
    
    // Game 3 mints token
    mock_token.mock_mint_once(3);
    let token3 = test_contract.test_mint(
        Option::Some(game3_address),
        Option::Some("Tournament Player"),
        Option::Some(301),
        Option::Some(1004000),
        Option::Some(1005000),
        Option::Some(array![100, 200, 300].span()),
        Option::None,
        Option::Some("https://game3.tournament.com"),
        Option::None,
        player,
        true, // This one is soulbound
    );
    token_ids.append(token3);
    
    // Step 4: Verify isolation between games
    assert(token1 == 1, 'Game 1 token ID incorrect');
    assert(token2 == 2, 'Game 2 token ID incorrect');
    assert(token3 == 3, 'Game 3 token ID incorrect');
    
    // Step 5: Check token uniqueness
    assert(token1 != token2 && token2 != token3 && token1 != token3, 'Token IDs must be unique');
    
    // Verify all tokens use same infrastructure
    assert(metagame.minigame_token_address() == token_address, 'Token address shared');
}

// Test multiple players across multiple games
#[test]
fn test_multi_player_multi_game() {
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    let metagame_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    // Register games
    let games = array![
        constants::GAME_ADDRESS(),
        constants::CONTEXT_ADDRESS(),
        constants::RENDERER_ADDRESS()
    ];
    
    let mut i = 0_u32;
    loop {
        if i >= games.len() {
            break;
        }
        mock_token.mock_is_game_registered(*games.at(i), true);
        i += 1;
    };
    
    // Players
    let players = array![
        constants::ALICE(),
        constants::BOB(),
        constants::TOKEN_ADDRESS()
    ];
    
    // Each player plays each game
    let mut token_counter = 1_u64;
    let mut game_idx = 0_u32;
    
    loop {
        if game_idx >= games.len() {
            break;
        }
        
        let game = *games.at(game_idx);
        let mut player_idx = 0_u32;
        
        loop {
            if player_idx >= players.len() {
                break;
            }
            
            let player = *players.at(player_idx);
            
            // Mock token mint
            mock_token.mock_mint_once(token_counter);
            
            let token_id = test_contract.test_mint(
                Option::Some(game),
                Option::Some(format(player_idx, "Player_Game_")),
                Option::Some((game_idx * 100 + player_idx).try_into().unwrap()),
                Option::Some((1000000 + (token_counter * 1000)).try_into().unwrap()),
                Option::Some((1001000 + (token_counter * 1000)).try_into().unwrap()),
                Option::Some(array![token_counter.try_into().unwrap()].span()),
                Option::None,
                Option::Some(format(game_idx, "https://game.com/player")),
                Option::None,
                player,
                false,
            );
            
            assert(token_id == token_counter, 'Token ID mismatch');
            
            token_counter += 1;
            player_idx += 1;
        };
        
        game_idx += 1;
    };
    
    // Verify total tokens minted
    assert(token_counter - 1 == 9, 'Should have minted 9 tokens');
}

// Test game isolation with failures
#[test]
fn test_game_isolation_with_unregistered() {
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    let metagame_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    // Register only game 1 and game 3
    let game1 = constants::GAME_ADDRESS();
    let game2 = constants::ALICE();
    let game3 = constants::BOB();
    
    mock_token.mock_is_game_registered(game1, true);
    mock_token.mock_is_game_registered(game2, false); // Not registered
    mock_token.mock_is_game_registered(game3, true);
    
    let player = constants::RENDERER_ADDRESS();
    
    // Game 1 should succeed
    mock_token.mock_mint_once(1);
    let token1 = test_contract.test_mint(
        Option::Some(game1),
        Option::Some("Player 1"),
        Option::Some(1),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::None,
        Option::Some("https://game1.com"),
        Option::None,
        player,
        false,
    );
    assert(token1 == 1, 'Token1 should be 1');
    
    // Game 2 is not registered so we skip testing it here
    // (Unregistered game testing is covered in other tests with should_panic)
    
    // Game 3 should succeed
    mock_token.mock_mint_once(2);
    let token3 = test_contract.test_mint(
        Option::Some(game3),
        Option::Some("Player 3"),
        Option::Some(3),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::None,
        Option::Some("https://game3.com"),
        Option::None,
        player,
        false,
    );
    assert(token3 == 2, 'Token3 should be 2');
}

// Test unregistered game failure
#[test]
#[should_panic(expected: 'Game is not registered')]
fn test_unregistered_game_failure() {
    let token_address = constants::TOKEN_ADDRESS();
    let mock_token = MockMinigameTokenTrait::new(token_address);
    
    let metagame_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    let test_contract = IMockMetagameTestDispatcher { contract_address: metagame_address };
    
    // Don't register this game
    let unregistered_game = constants::ALICE();
    mock_token.mock_is_game_registered(unregistered_game, false);
    
    let player = constants::RENDERER_ADDRESS();
    
    // This should panic
    test_contract.test_mint(
        Option::Some(unregistered_game),
        Option::Some("Player 2"),
        Option::Some(2),
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::None,
        Option::Some("https://game2.com"),
        Option::None,
        player,
        false,
    );
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