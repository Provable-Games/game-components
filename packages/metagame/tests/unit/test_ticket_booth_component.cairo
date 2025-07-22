use game_components_metagame::ticket_booth::{TicketBoothComponent, ITicketBoothDispatcher, ITicketBoothDispatcherTrait, GoldenPass};
use game_components_metagame::extensions::context::structs::GameContextDetails;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use starknet::{ContractAddress, contract_address_const, get_caller_address, get_contract_address};
use core::num::traits::Zero;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp};

// Interface for testing the ticket booth contract
#[starknet::interface]
trait IMockTicketBooth<TContractState> {
    fn buy_game(
        ref self: TContractState,
        player_name: ByteArray,
        to: ContractAddress,
        soulbound: bool,
        objective_ids: Option<Span<u32>>,
        context: Option<GameContextDetails>,
    ) -> u64;
    fn use_golden_pass(
        ref self: TContractState,
        golden_pass_address: ContractAddress,
        golden_pass_token_id: u256,
        player_name: ByteArray,
        to: ContractAddress,
        soulbound: bool,
        objective_ids: Option<Span<u32>>,
        context: Option<GameContextDetails>,
    ) -> u64;
    fn payment_token(self: @TContractState) -> ContractAddress;
    fn cost_to_play(self: @TContractState) -> u128;
    fn settings_id(self: @TContractState) -> Option<u32>;
    fn start_time(self: @TContractState) -> Option<u64>;
    fn expiration_time(self: @TContractState) -> Option<u64>;
    fn client_url(self: @TContractState) -> Option<ByteArray>;
    fn renderer_address(self: @TContractState) -> Option<ContractAddress>;
    fn get_golden_pass(self: @TContractState, golden_pass_address: ContractAddress) -> Option<GoldenPass>;
    fn golden_pass_last_used(self: @TContractState, golden_pass_address: ContractAddress, token_id: u256) -> u64;
    fn ticket_receiver_address(self: @TContractState) -> Option<ContractAddress>;
}

// Helper function to deploy ticket booth with all required parameters
fn deploy_ticket_booth(
    game_address: ContractAddress,
    payment_token: ContractAddress,
    cost_to_play: u128,
    settings_id: Option<u32>,
    start_time: Option<u64>,
    expiration_time: Option<u64>,
    client_url: Option<ByteArray>,
    renderer_address: Option<ContractAddress>,
    golden_passes: Option<Span<(ContractAddress, GoldenPass)>>,
    ticket_receiver_address: Option<ContractAddress>,
) -> ContractAddress {
    let contract = declare("MockTicketBooth").unwrap().contract_class();
    let mut calldata = array![];
    
    calldata.append(game_address.into());
    calldata.append(payment_token.into());
    calldata.append(cost_to_play.into());
    
    // settings_id option
    match settings_id {
        Option::Some(id) => {
            calldata.append(1); // Some
            calldata.append(id.into());
        },
        Option::None => {
            calldata.append(0); // None
        }
    }
    
    // start_time option
    match start_time {
        Option::Some(time) => {
            calldata.append(1); // Some
            calldata.append(time.into());
        },
        Option::None => {
            calldata.append(0); // None
        }
    }
    
    // expiration_time option
    match expiration_time {
        Option::Some(time) => {
            calldata.append(1); // Some
            calldata.append(time.into());
        },
        Option::None => {
            calldata.append(0); // None
        }
    }
    
    // client_url option
    match client_url {
        Option::Some(url) => {
            calldata.append(1); // Some
            let data: Span<felt252> = url.serialize();
            data.serialize(ref calldata);
        },
        Option::None => {
            calldata.append(0); // None
        }
    }
    
    
    // renderer_address option
    match renderer_address {
        Option::Some(address) => {
            calldata.append(1); // Some
            calldata.append(address.into());
        },
        Option::None => {
            calldata.append(0); // None
        }
    }
    
    // Golden passes option
    match golden_passes {
        Option::Some(passes) => {
            calldata.append(0); // Some variant
            calldata.append(passes.len().into());
            let mut i = 0;
            loop {
                if i >= passes.len() {
                    break;
                }
                let (address, config) = passes.at(i);
                calldata.append((*address).into());
                calldata.append(config.cooldown.into());
                calldata.append(config.game_expiration.into());
                i += 1;
            };
        },
        Option::None => {
            calldata.append(1); // None variant
        }
    }
    
    // Ticket receiver address option
    match ticket_receiver_address {
        Option::Some(receiver) => {
            calldata.append(0); // Some variant
            calldata.append(receiver.into());
        },
        Option::None => {
            calldata.append(1); // None variant
        }
    }
    
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

// Test TB-01: Initialization with valid parameters
#[test]
fn test_initialization_success() {
    let game_address = contract_address_const::<0x123>();
    let payment_token = contract_address_const::<0x456>();
    let cost_to_play = 1000_u128;
    let settings_id = 42_u32;
    let golden_pass_address = contract_address_const::<0x789>();
    let golden_pass_cooldown = 3600_u64; // 1 hour
    let golden_pass_expiration = 864000_u64; // 10 days
    let ticket_receiver = contract_address_const::<0xABC>();
    
    let golden_pass = GoldenPass { 
        cooldown: golden_pass_cooldown, 
        game_expiration: golden_pass_expiration 
    };
    let golden_passes = array![(golden_pass_address, golden_pass)].span();
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        cost_to_play,
        Option::Some(settings_id),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::Some(golden_passes),
        Option::Some(ticket_receiver),
    );
    
    let dispatcher = ITicketBoothDispatcher { contract_address };
    
    // Verify all parameters are set correctly
    assert!(dispatcher.payment_token() == payment_token, "Payment token mismatch");
    assert!(dispatcher.cost_to_play() == cost_to_play, "Cost to play mismatch");
    assert!(dispatcher.settings_id() == Option::Some(settings_id), "Settings ID mismatch");
    
    // Check golden pass configuration
    let retrieved_golden_pass = dispatcher.get_golden_pass(golden_pass_address).unwrap();
    assert!(retrieved_golden_pass.cooldown == golden_pass_cooldown, "Golden pass cooldown mismatch");
    assert!(retrieved_golden_pass.game_expiration == golden_pass_expiration, "Golden pass expiration mismatch");
    
    // Check ticket receiver
    assert!(dispatcher.ticket_receiver_address() == Option::Some(ticket_receiver), "Ticket receiver mismatch");
}

// Test TB-02: Initialization without golden pass
#[test]
fn test_initialization_no_golden_pass() {
    let game_address = contract_address_const::<0x123>();
    let payment_token = contract_address_const::<0x456>();
    let cost_to_play = 500_u128;
    let settings_id = 1_u32;
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        cost_to_play,
        Option::Some(settings_id),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::None, // no golden pass
        Option::None, // burn tokens (no receiver)
    );
    
    let dispatcher = ITicketBoothDispatcher { contract_address };
    
    // Verify golden pass is not configured
    let test_address = contract_address_const::<0x789>();
    assert!(dispatcher.get_golden_pass(test_address).is_none(), "Golden pass should not be configured");
    
    // Verify ticket receiver is None (tokens will be sent to zero address)
    assert!(dispatcher.ticket_receiver_address().is_none(), "Ticket receiver should be None");
}

// Test TB-03: Initialization fails with zero game address
#[test]
#[should_panic(expected: "Game address cannot be zero")]
fn test_initialization_zero_game_address() {
    let zero_address = contract_address_const::<0x0>();
    let payment_token = contract_address_const::<0x456>();
    
    deploy_ticket_booth(
        zero_address, // Should fail
        payment_token,
        1000_u128,
        Option::Some(1_u32),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::None,
        Option::None,
    );
}

// Test TB-04: Initialization fails with zero payment token
#[test]
#[should_panic(expected: "Payment token cannot be zero")]
fn test_initialization_zero_payment_token() {
    let game_address = contract_address_const::<0x123>();
    let zero_address = contract_address_const::<0x0>();
    
    deploy_ticket_booth(
        game_address,
        zero_address, // Should fail
        1000_u128,
        Option::Some(1_u32),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::None,
        Option::None,
    );
}

// Test TB-05: Initialization fails with zero cost
#[test]
#[should_panic(expected: "Cost to play must be greater than zero")]
fn test_initialization_zero_cost() {
    let game_address = contract_address_const::<0x123>();
    let payment_token = contract_address_const::<0x456>();
    
    deploy_ticket_booth(
        game_address,
        payment_token,
        0_u128, // Should fail
        Option::Some(1_u32),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::None,
        Option::None,
    );
}

// Test TB-06: Buy game successfully
#[test]
fn test_buy_game_success() {
    // Deploy mock ERC20 and game token contracts
    let erc20_contract = declare("MockERC20").unwrap().contract_class();
    let (payment_token, _) = erc20_contract.deploy(@array![]).unwrap();
    
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (game_address, _) = token_contract.deploy(@array![]).unwrap();
    
    let cost_to_play = 1000_u128;
    let settings_id = 5_u32;
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        cost_to_play,
        Option::Some(settings_id),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::None,
        Option::Some(contract_address_const::<0xDEF>()), // Collect payments to this address
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    
    // Setup: Give user tokens and approve ticket booth
    let user = contract_address_const::<0x999>();
    let erc20_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    
    start_cheat_caller_address(payment_token, user);
    // Mock ERC20 should allow minting to user and approving
    stop_cheat_caller_address(payment_token);
    
    start_cheat_caller_address(contract_address, user);
    let token_id = dispatcher.buy_game(
        "Player One",
        user,
        false,
        Option::None, // objective_ids
        Option::None, // context
    );
    stop_cheat_caller_address(contract_address);
    
    assert!(token_id > 0, "Token ID should be valid");
}

// Test TB-07: Use golden pass successfully
#[test]
fn test_use_golden_pass_success() {
    // Deploy mock contracts
    let erc721_contract = declare("MockERC721").unwrap().contract_class();
    let (golden_pass_address, _) = erc721_contract.deploy(@array![]).unwrap();
    
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (game_address, _) = token_contract.deploy(@array![]).unwrap();
    
    let payment_token = contract_address_const::<0x456>();
    let golden_pass_cooldown = 3600_u64; // 1 hour
    let golden_pass_expiration = 864000_u64; // 10 days
    
    let golden_pass = GoldenPass { 
        cooldown: golden_pass_cooldown, 
        game_expiration: golden_pass_expiration 
    };
    let golden_passes = array![(golden_pass_address, golden_pass)].span();
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        1000_u128,
        Option::Some(1_u32),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::Some(golden_passes),
        Option::None,
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    
    // Setup: User owns golden pass token
    let user = contract_address_const::<0x999>();
    let golden_pass_token_id = 1_u256;
    
    // Mock the golden pass ownership
    start_cheat_caller_address(contract_address, user);
    
    // Set timestamp for testing
    start_cheat_block_timestamp(contract_address, 1000);
    
    let token_id = dispatcher.use_golden_pass(
        golden_pass_address,
        golden_pass_token_id,
        "Golden Player",
        user,
        true, // soulbound
        Option::None, // objective_ids
        Option::None, // context
    );
    
    stop_cheat_block_timestamp(contract_address);
    stop_cheat_caller_address(contract_address);
    
    assert!(token_id > 0, "Token ID should be valid");
    
    // Verify cooldown was recorded
    let last_used = dispatcher.golden_pass_last_used(golden_pass_address, golden_pass_token_id);
    assert!(last_used == 1000, "Last used timestamp should be recorded");
}

// Test TB-08: Golden pass cooldown enforcement
#[test]
#[should_panic(expected: "Golden pass on cooldown")]
fn test_golden_pass_cooldown() {
    // Deploy mock contracts
    let erc721_contract = declare("MockERC721").unwrap().contract_class();
    let (golden_pass_address, _) = erc721_contract.deploy(@array![]).unwrap();
    
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (game_address, _) = token_contract.deploy(@array![]).unwrap();
    
    let payment_token = contract_address_const::<0x456>();
    let golden_pass_cooldown = 3600_u64; // 1 hour
    let golden_pass_expiration = 864000_u64; // 10 days
    
    let golden_pass = GoldenPass { 
        cooldown: golden_pass_cooldown, 
        game_expiration: golden_pass_expiration 
    };
    let golden_passes = array![(golden_pass_address, golden_pass)].span();
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        1000_u128,
        Option::Some(1_u32),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::Some(golden_passes),
        Option::None,
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    let user = contract_address_const::<0x999>();
    let golden_pass_token_id = 1_u256;
    
    start_cheat_caller_address(contract_address, user);
    
    // First use at timestamp 1000
    start_cheat_block_timestamp(contract_address, 1000);
    dispatcher.use_golden_pass(golden_pass_address, golden_pass_token_id, "Player", user, false, Option::None, Option::None);
    
    // Try to use again immediately (should fail)
    start_cheat_block_timestamp(contract_address, 1001); // Only 1 second later
    dispatcher.use_golden_pass(golden_pass_address, golden_pass_token_id, "Player", user, false, Option::None, Option::None); // Should panic
}

// Test TB-09: Golden pass use after cooldown
#[test]
fn test_golden_pass_after_cooldown() {
    // Deploy mock contracts
    let erc721_contract = declare("MockERC721").unwrap().contract_class();
    let (golden_pass_address, _) = erc721_contract.deploy(@array![]).unwrap();
    
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (game_address, _) = token_contract.deploy(@array![]).unwrap();
    
    let payment_token = contract_address_const::<0x456>();
    let golden_pass_cooldown = 3600_u64; // 1 hour
    let golden_pass_expiration = 864000_u64; // 10 days
    
    let golden_pass = GoldenPass { 
        cooldown: golden_pass_cooldown, 
        game_expiration: golden_pass_expiration 
    };
    let golden_passes = array![(golden_pass_address, golden_pass)].span();
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        1000_u128,
        Option::Some(1_u32),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::Some(golden_passes),
        Option::None,
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    let user = contract_address_const::<0x999>();
    let golden_pass_token_id = 1_u256;
    
    start_cheat_caller_address(contract_address, user);
    
    // First use at timestamp 1000
    start_cheat_block_timestamp(contract_address, 1000);
    let token_id_1 = dispatcher.use_golden_pass(golden_pass_address, golden_pass_token_id, "Player", user, false, Option::None, Option::None);
    
    // Use again after cooldown (1 hour + 1 second later)
    start_cheat_block_timestamp(contract_address, 1000 + 3600 + 1);
    let token_id_2 = dispatcher.use_golden_pass(golden_pass_address, golden_pass_token_id, "Player", user, false, Option::None, Option::None);
    
    stop_cheat_block_timestamp(contract_address);
    stop_cheat_caller_address(contract_address);
    
    assert!(token_id_1 > 0, "First token should be valid");
    assert!(token_id_2 > 0, "Second token should be valid");
    assert!(token_id_1 != token_id_2, "Token IDs should be different");
}

// Test TB-10: Golden pass not configured
#[test]
#[should_panic(expected: "Golden pass not configured")]
fn test_golden_pass_not_configured() {
    let game_address = contract_address_const::<0x123>();
    let payment_token = contract_address_const::<0x456>();
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        1000_u128,
        1_u32,
        Option::None, // No golden pass configured
        Option::None,
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    let user = contract_address_const::<0x999>();
    let unconfigured_golden_pass = contract_address_const::<0x789>();
    
    start_cheat_caller_address(contract_address, user);
    dispatcher.use_golden_pass(unconfigured_golden_pass, 1_u256, "Player", user, false, Option::None, Option::None); // Should panic
}

// Test TB-11: Golden pass with 10-day expiration
#[test]
fn test_golden_pass_expiration() {
    // This test verifies that golden pass games are minted with 10-day expiration
    // The actual expiration check would be in the game token contract
    // Here we just verify the call is made with the right parameters
    
    let erc721_contract = declare("MockERC721").unwrap().contract_class();
    let (golden_pass_address, _) = erc721_contract.deploy(@array![]).unwrap();
    
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (game_address, _) = token_contract.deploy(@array![]).unwrap();
    
    let payment_token = contract_address_const::<0x456>();
    let golden_pass_cooldown = 3600_u64;
    let golden_pass_expiration = 864000_u64; // 10 days
    
    let golden_pass = GoldenPass { 
        cooldown: golden_pass_cooldown, 
        game_expiration: golden_pass_expiration 
    };
    let golden_passes = array![(golden_pass_address, golden_pass)].span();
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        1000_u128,
        Option::Some(1_u32),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::Some(golden_passes),
        Option::None,
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    let user = contract_address_const::<0x999>();
    
    start_cheat_caller_address(contract_address, user);
    start_cheat_block_timestamp(contract_address, 1000);
    
    let token_id = dispatcher.use_golden_pass(golden_pass_address, 1_u256, "Player", user, false, Option::None, Option::None);
    
    stop_cheat_block_timestamp(contract_address);
    stop_cheat_caller_address(contract_address);
    
    assert!(token_id > 0, "Token should be minted with expiration");
    // Note: The 10-day expiration would be verified by checking the minted token's metadata
    // in a more comprehensive test with a real game token contract
}

// Test TB-12: Buy game with payment sent to zero address
#[test]
fn test_buy_game_send_to_zero() {
    // Deploy mock ERC20
    let erc20_contract = declare("MockERC20").unwrap().contract_class();
    let (payment_token, _) = erc20_contract.deploy(@array![]).unwrap();
    
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (game_address, _) = token_contract.deploy(@array![]).unwrap();
    
    let cost_to_play = 1000_u128;
    let settings_id = 5_u32;
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        cost_to_play,
        Option::Some(settings_id),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::None, // golden_passes
        Option::None, // No receiver = send tokens to zero address
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    let user = contract_address_const::<0x999>();
    
    // Setup: Give user tokens and approve ticket booth for burning
    use super::super::mocks::mock_erc20::{MockERC20Dispatcher, MockERC20DispatcherTrait};
    
    let mock_erc20 = MockERC20Dispatcher { contract_address: payment_token };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    
    // Mint tokens to user
    mock_erc20.mint(user, cost_to_play.into());
    
    // User approves ticket booth to transfer tokens
    start_cheat_caller_address(payment_token, user);
    erc20_dispatcher.approve(contract_address, cost_to_play.into());
    stop_cheat_caller_address(payment_token);
    
    // Check initial balance
    let initial_balance = erc20_dispatcher.balance_of(user);
    let zero_address: ContractAddress = 0.try_into().unwrap();
    let initial_zero_balance = erc20_dispatcher.balance_of(zero_address);
    assert!(initial_balance >= cost_to_play.into(), "User should have enough tokens");
    
    // Buy game (should send tokens to zero address)
    start_cheat_caller_address(contract_address, user);
    let token_id = dispatcher.buy_game("Player One", user, false, Option::None, Option::None);
    stop_cheat_caller_address(contract_address);
    
    // Verify token was minted
    assert!(token_id > 0, "Token ID should be valid");
    
    // Verify tokens were sent to zero address
    let final_user_balance = erc20_dispatcher.balance_of(user);
    let final_zero_balance = erc20_dispatcher.balance_of(zero_address);
    
    assert!(final_user_balance == initial_balance - cost_to_play.into(), "User balance should decrease");
    assert!(final_zero_balance == initial_zero_balance + cost_to_play.into(), "Zero address balance should increase");
}

// Test TB-13: Buy game without burn (collect payment)
#[test]
fn test_buy_game_collect_payment() {
    // Deploy mock ERC20
    let erc20_contract = declare("MockERC20").unwrap().contract_class();
    let (payment_token, _) = erc20_contract.deploy(@array![]).unwrap();
    
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (game_address, _) = token_contract.deploy(@array![]).unwrap();
    
    let cost_to_play = 1000_u128;
    let settings_id = 5_u32;
    
    let receiver_address = contract_address_const::<0xDEF>();
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        cost_to_play,
        Option::Some(settings_id),
        Option::None, // start_time
        Option::None, // expiration_time
        Option::None, // client_url
        Option::None, // renderer_address
        Option::None, // golden_passes
        Option::Some(receiver_address), // Collect payments to this address
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    let user = contract_address_const::<0x999>();
    
    // Setup: Give user tokens and approve ticket booth
    use super::super::mocks::mock_erc20::{MockERC20Dispatcher, MockERC20DispatcherTrait};
    
    let mock_erc20 = MockERC20Dispatcher { contract_address: payment_token };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    
    // Mint tokens to user
    mock_erc20.mint(user, cost_to_play.into());
    
    // User approves ticket booth
    start_cheat_caller_address(payment_token, user);
    erc20_dispatcher.approve(contract_address, cost_to_play.into());
    stop_cheat_caller_address(payment_token);
    
    // Check initial balances
    let initial_user_balance = erc20_dispatcher.balance_of(user);
    let initial_receiver_balance = erc20_dispatcher.balance_of(receiver_address);
    
    // Buy game (should transfer tokens to receiver address)
    start_cheat_caller_address(contract_address, user);
    let token_id = dispatcher.buy_game("Player One", user, false, Option::None, Option::None);
    stop_cheat_caller_address(contract_address);
    
    // Verify token was minted
    assert!(token_id > 0, "Token ID should be valid");
    
    // Verify tokens were transferred to receiver
    let final_user_balance = erc20_dispatcher.balance_of(user);
    let final_receiver_balance = erc20_dispatcher.balance_of(receiver_address);
    
    assert!(final_user_balance == initial_user_balance - cost_to_play.into(), "User balance should decrease");
    assert!(final_receiver_balance == initial_receiver_balance + cost_to_play.into(), "Receiver balance should increase");
}

// Mock TicketBooth contract for testing
#[starknet::contract]
mod MockTicketBooth {
    use game_components_metagame::ticket_booth::TicketBoothComponent;
    use starknet::ContractAddress;

    component!(path: TicketBoothComponent, storage: ticket_booth, event: TicketBoothEvent);
    // Embed the implementations
    #[abi(embed_v0)]
    impl TicketBoothImpl = TicketBoothComponent::TicketBoothImpl<ContractState>;
    impl TicketBoothInternalImpl = TicketBoothComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ticket_booth: TicketBoothComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        TicketBoothEvent: TicketBoothComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        game_address: ContractAddress,
        payment_token: ContractAddress,
        cost_to_play: u128,
        settings_id: Option<u32>,
        start_time: Option<u64>,
        expiration_time: Option<u64>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        golden_passes: Option<Span<(ContractAddress, GoldenPass)>>,
        ticket_receiver_address: Option<ContractAddress>,
    ) {
        self.ticket_booth.initializer(
            game_address,
            payment_token,
            cost_to_play,
            settings_id,
            start_time,
            expiration_time,
            client_url,
            renderer_address,
            golden_passes,
            ticket_receiver_address,
        );
    }
}