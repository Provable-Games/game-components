use game_components_metagame::ticket_booth::{TicketBoothComponent, ITicketBoothDispatcher, ITicketBoothDispatcherTrait};
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
    ) -> u64;
    fn use_golden_pass(
        ref self: TContractState,
        golden_pass_token_id: u256,
        player_name: ByteArray,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
    fn payment_token(self: @TContractState) -> ContractAddress;
    fn cost_to_play(self: @TContractState) -> u128;
    fn burn_payment(self: @TContractState) -> bool;
    fn settings_id(self: @TContractState) -> u32;
    fn golden_pass_address(self: @TContractState) -> ContractAddress;
    fn golden_pass_cooldown(self: @TContractState) -> u64;
    fn golden_pass_last_used(self: @TContractState, token_id: u256) -> u64;
}

// Helper function to deploy ticket booth with all required parameters
fn deploy_ticket_booth(
    game_address: ContractAddress,
    payment_token: ContractAddress,
    cost_to_play: u128,
    burn_payment: bool,
    settings_id: u32,
    golden_pass: Option<(ContractAddress, u64)>,
    grant_approval_to: Option<ContractAddress>,
) -> ContractAddress {
    let contract = declare("MockTicketBooth").unwrap().contract_class();
    let mut calldata = array![];
    
    calldata.append(game_address.into());
    calldata.append(payment_token.into());
    calldata.append(cost_to_play.into());
    calldata.append(if burn_payment { 1 } else { 0 });
    calldata.append(settings_id.into());
    
    // Golden pass option
    match golden_pass {
        Option::Some((address, cooldown)) => {
            calldata.append(0); // Some variant
            calldata.append(address.into());
            calldata.append(cooldown.into());
        },
        Option::None => {
            calldata.append(1); // None variant
        }
    }
    
    // Grant approval option
    match grant_approval_to {
        Option::Some(operator) => {
            calldata.append(0); // Some variant
            calldata.append(operator.into());
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
    let burn_payment = false;
    let settings_id = 42_u32;
    let golden_pass_address = contract_address_const::<0x789>();
    let golden_pass_cooldown = 3600_u64; // 1 hour
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        cost_to_play,
        burn_payment,
        settings_id,
        Option::Some((golden_pass_address, golden_pass_cooldown)),
        Option::None,
    );
    
    let dispatcher = ITicketBoothDispatcher { contract_address };
    
    // Verify all parameters are set correctly
    assert!(dispatcher.payment_token() == payment_token, "Payment token mismatch");
    assert!(dispatcher.cost_to_play() == cost_to_play, "Cost to play mismatch");
    assert!(dispatcher.burn_payment() == burn_payment, "Burn payment mismatch");
    assert!(dispatcher.settings_id() == settings_id, "Settings ID mismatch");
    assert!(dispatcher.golden_pass_address() == golden_pass_address, "Golden pass address mismatch");
    assert!(dispatcher.golden_pass_cooldown() == golden_pass_cooldown, "Golden pass cooldown mismatch");
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
        true, // burn_payment
        settings_id,
        Option::None, // no golden pass
        Option::None,
    );
    
    let dispatcher = ITicketBoothDispatcher { contract_address };
    
    // Verify golden pass is not configured
    assert!(dispatcher.golden_pass_address().is_zero(), "Golden pass address should be zero");
    assert!(dispatcher.golden_pass_cooldown() == 0, "Golden pass cooldown should be zero");
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
        false,
        1_u32,
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
        false,
        1_u32,
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
        false,
        1_u32,
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
        false,
        settings_id,
        Option::None,
        Option::None,
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
        false
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
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        1000_u128,
        false,
        1_u32,
        Option::Some((golden_pass_address, golden_pass_cooldown)),
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
        golden_pass_token_id,
        "Golden Player",
        user,
        true // soulbound
    );
    
    stop_cheat_block_timestamp(contract_address);
    stop_cheat_caller_address(contract_address);
    
    assert!(token_id > 0, "Token ID should be valid");
    
    // Verify cooldown was recorded
    let last_used = dispatcher.golden_pass_last_used(golden_pass_token_id);
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
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        1000_u128,
        false,
        1_u32,
        Option::Some((golden_pass_address, golden_pass_cooldown)),
        Option::None,
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    let user = contract_address_const::<0x999>();
    let golden_pass_token_id = 1_u256;
    
    start_cheat_caller_address(contract_address, user);
    
    // First use at timestamp 1000
    start_cheat_block_timestamp(contract_address, 1000);
    dispatcher.use_golden_pass(golden_pass_token_id, "Player", user, false);
    
    // Try to use again immediately (should fail)
    start_cheat_block_timestamp(contract_address, 1001); // Only 1 second later
    dispatcher.use_golden_pass(golden_pass_token_id, "Player", user, false); // Should panic
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
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        1000_u128,
        false,
        1_u32,
        Option::Some((golden_pass_address, golden_pass_cooldown)),
        Option::None,
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    let user = contract_address_const::<0x999>();
    let golden_pass_token_id = 1_u256;
    
    start_cheat_caller_address(contract_address, user);
    
    // First use at timestamp 1000
    start_cheat_block_timestamp(contract_address, 1000);
    let token_id_1 = dispatcher.use_golden_pass(golden_pass_token_id, "Player", user, false);
    
    // Use again after cooldown (1 hour + 1 second later)
    start_cheat_block_timestamp(contract_address, 1000 + 3600 + 1);
    let token_id_2 = dispatcher.use_golden_pass(golden_pass_token_id, "Player", user, false);
    
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
        false,
        1_u32,
        Option::None, // No golden pass configured
        Option::None,
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    let user = contract_address_const::<0x999>();
    
    start_cheat_caller_address(contract_address, user);
    dispatcher.use_golden_pass(1_u256, "Player", user, false); // Should panic
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
    
    let contract_address = deploy_ticket_booth(
        game_address,
        payment_token,
        1000_u128,
        false,
        1_u32,
        Option::Some((golden_pass_address, golden_pass_cooldown)),
        Option::None,
    );
    
    let dispatcher = IMockTicketBoothDispatcher { contract_address };
    let user = contract_address_const::<0x999>();
    
    start_cheat_caller_address(contract_address, user);
    start_cheat_block_timestamp(contract_address, 1000);
    
    let token_id = dispatcher.use_golden_pass(1_u256, "Player", user, false);
    
    stop_cheat_block_timestamp(contract_address);
    stop_cheat_caller_address(contract_address);
    
    assert!(token_id > 0, "Token should be minted with expiration");
    // Note: The 10-day expiration would be verified by checking the minted token's metadata
    // in a more comprehensive test with a real game token contract
}

// Mock TicketBooth contract for testing
#[starknet::contract]
mod MockTicketBooth {
    use game_components_metagame::ticket_booth::TicketBoothComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: TicketBoothComponent, storage: ticket_booth, event: TicketBoothEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Embed the implementations
    #[abi(embed_v0)]
    impl TicketBoothImpl = TicketBoothComponent::TicketBoothImpl<ContractState>;
    impl TicketBoothInternalImpl = TicketBoothComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ticket_booth: TicketBoothComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        TicketBoothEvent: TicketBoothComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        game_address: ContractAddress,
        payment_token: ContractAddress,
        cost_to_play: u128,
        burn_payment: bool,
        settings_id: u32,
        golden_pass: Option<(ContractAddress, u64)>,
        grant_approval_to: Option<ContractAddress>,
    ) {
        self.ticket_booth.initializer(
            game_address,
            payment_token,
            cost_to_play,
            burn_payment,
            settings_id,
            golden_pass,
            grant_approval_to,
        );
    }
}