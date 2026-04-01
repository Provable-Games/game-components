// =============================================================================
// TEST: ticket_booth.cairo
// =============================================================================
// Tests for TicketBoothComponent
// Note: buy_game integration tests are skipped because they require a full
// game contract ecosystem (minigame + token) to work properly. Those tests
// should be implemented in an integration test package.

use game_components_testing::constants::{ALICE, BOB, FAR_FUTURE_TIME, FUTURE_TIME, PAST_TIME};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_block_timestamp,
};
use starknet::ContractAddress;
use crate::ticket_booth::structs::{GameExpiration, GoldenPass, GoldenPassInfo, PaymentType};
use crate::ticket_booth::ticket_booth_component::TicketBoothComponent::{
    ITicketBoothDispatcher, ITicketBoothDispatcherTrait,
};

// =============================================================================
// CONSTANTS
// =============================================================================

const DEFAULT_COST: u128 = 100;
const DEFAULT_OPENING_TIME: u64 = 1000;
const DEFAULT_COOLDOWN: u64 = 100; // Small cooldown for testing
const DEFAULT_EXPIRATION_DURATION: u64 = 86400; // 24 hours
const LARGE_TIMESTAMP: u64 = 10000; // Large timestamp to pass cooldown checks

fn PAYMENT_TOKEN() -> ContractAddress {
    'PAYMENT_TOKEN'.try_into().unwrap()
}

fn TICKET_RECEIVER() -> ContractAddress {
    'TICKET_RECEIVER'.try_into().unwrap()
}

fn GAME_ADDRESS() -> ContractAddress {
    'GAME_ADDRESS'.try_into().unwrap()
}

// =============================================================================
// HELPER INTERFACES
// =============================================================================

#[starknet::interface]
trait IMockERC721Setter<TContractState> {
    fn set_owner(ref self: TContractState, token_id: u256, owner: ContractAddress);
}

#[starknet::interface]
trait IMockERC20Setter<TContractState> {
    fn set_balance(ref self: TContractState, account: ContractAddress, amount: u256);
    fn set_allowance(
        ref self: TContractState, owner: ContractAddress, spender: ContractAddress, amount: u256,
    );
}

// =============================================================================
// DEPLOYMENT HELPERS
// =============================================================================

fn deploy_mock_erc721() -> ContractAddress {
    let contract = declare("MockERC721ForTicketBooth").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    address
}

fn deploy_mock_minigame_token() -> ContractAddress {
    let contract = declare("MockMinigameTokenForTicketBooth").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    address
}

fn deploy_mock_erc20() -> ContractAddress {
    let contract = declare("MockERC20ForTicketBooth").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    address
}

fn deploy_ticket_booth(
    opening_time: u64,
    game_token_address: ContractAddress,
    payment_token: ContractAddress,
    cost_to_play: u128,
    ticket_receiver_address: ContractAddress,
    game_address: Option<ContractAddress>,
    settings_id: Option<u32>,
    start_time: Option<u64>,
    expiration_time: Option<u64>,
    golden_passes: Option<Span<(ContractAddress, GoldenPass)>>,
) -> (ContractAddress, ITicketBoothDispatcher) {
    let contract = declare("MockTicketBoothContract").unwrap().contract_class();

    let mut calldata = array![];
    calldata.append(opening_time.into());
    calldata.append(game_token_address.into());
    calldata.append(payment_token.into());
    calldata.append(cost_to_play.into());
    calldata.append(ticket_receiver_address.into());

    // game_address: Option<ContractAddress>
    match game_address {
        Option::Some(addr) => {
            calldata.append(0); // Some variant
            calldata.append(addr.into());
        },
        Option::None => {
            calldata.append(1); // None variant
        },
    }

    // settings_id: Option<u32>
    match settings_id {
        Option::Some(id) => {
            calldata.append(0);
            calldata.append(id.into());
        },
        Option::None => { calldata.append(1); },
    }

    // start_time: Option<u64>
    match start_time {
        Option::Some(t) => {
            calldata.append(0);
            calldata.append(t.into());
        },
        Option::None => { calldata.append(1); },
    }

    // expiration_time: Option<u64>
    match expiration_time {
        Option::Some(t) => {
            calldata.append(0);
            calldata.append(t.into());
        },
        Option::None => { calldata.append(1); },
    }

    // golden_passes: Option<Span<(ContractAddress, GoldenPass)>>
    match golden_passes {
        Option::Some(passes) => {
            calldata.append(0); // Some variant
            calldata.append(passes.len().into());
            let mut i = 0;
            loop {
                if i >= passes.len() {
                    break;
                }
                let (addr, pass) = passes.at(i);
                calldata.append((*addr).into());
                calldata.append((*pass.cooldown).into());
                // GameExpiration serialization
                match pass.game_expiration {
                    GameExpiration::None => calldata.append(0),
                    GameExpiration::Fixed(t) => {
                        calldata.append(1);
                        calldata.append((*t).into());
                    },
                    GameExpiration::Dynamic(t) => {
                        calldata.append(2);
                        calldata.append((*t).into());
                    },
                }
                calldata.append((*pass.pass_expiration).into());
                i += 1;
            };
        },
        Option::None => {
            calldata.append(1); // None variant
        },
    }

    let (address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = ITicketBoothDispatcher { contract_address: address };
    (address, dispatcher)
}

fn deploy_basic_ticket_booth() -> (ContractAddress, ITicketBoothDispatcher) {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();

    deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
    )
}

// =============================================================================
// INITIALIZER TESTS
// =============================================================================

// TB-U-01: Initialize with valid parameters
#[test]
fn test_initialize_with_valid_parameters() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::Some(GAME_ADDRESS()),
        Option::Some(42),
        Option::Some(500),
        Option::Some(DEFAULT_EXPIRATION_DURATION),
        Option::None,
    );

    assert!(dispatcher.opening_time() == DEFAULT_OPENING_TIME, "Opening time mismatch");
    assert!(dispatcher.payment_token() == payment_token, "Payment token mismatch");
    assert!(dispatcher.cost_to_play() == DEFAULT_COST, "Cost mismatch");
    assert!(dispatcher.ticket_receiver_address() == TICKET_RECEIVER(), "Receiver mismatch");
    assert!(dispatcher.settings_id() == Option::Some(42), "Settings ID mismatch");
    assert!(dispatcher.start_time() == Option::Some(500), "Start time mismatch");
    assert!(
        dispatcher.expiration_time() == Option::Some(DEFAULT_EXPIRATION_DURATION),
        "Expiration mismatch",
    );
}

// TB-U-06: Initialize with all optional parameters set
#[test]
fn test_initialize_with_all_optional_params() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::Some(GAME_ADDRESS()),
        Option::Some(99),
        Option::Some(1000),
        Option::Some(86400),
        Option::None,
    );

    assert!(dispatcher.settings_id() == Option::Some(99), "Settings ID should be set");
    assert!(dispatcher.start_time() == Option::Some(1000), "Start time should be set");
    assert!(dispatcher.expiration_time() == Option::Some(86400), "Expiration should be set");
}

// TB-U-07: Initialize with None for optional parameters
#[test]
fn test_initialize_with_none_optional_params() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
    );

    assert!(dispatcher.settings_id() == Option::None, "Settings ID should be None");
    assert!(dispatcher.start_time() == Option::None, "Start time should be None");
    assert!(dispatcher.expiration_time() == Option::None, "Expiration should be None");
}

// TB-U-08: Initialize with opening_time = 0 (immediately open)
#[test]
fn test_initialize_with_zero_opening_time() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();

    let (_, dispatcher) = deploy_ticket_booth(
        0, // Immediately open
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
    );

    assert!(dispatcher.opening_time() == 0, "Opening time should be 0");
}

// TB-U-04: Initialize with golden passes
#[test]
fn test_initialize_with_golden_passes() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    let golden_pass = GoldenPass {
        cooldown: DEFAULT_COOLDOWN, game_expiration: GameExpiration::None, pass_expiration: 0,
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    let retrieved_pass = dispatcher.get_golden_pass(golden_pass_nft);
    assert!(retrieved_pass.is_some(), "Golden pass should be configured");

    if let Option::Some(pass) = retrieved_pass {
        assert!(pass.cooldown == DEFAULT_COOLDOWN, "Cooldown mismatch");
    }
}

// =============================================================================
// VIEW FUNCTION TESTS
// =============================================================================

// TB-U-32: payment_token returns correct value
#[test]
fn test_payment_token_view() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
    );

    assert!(dispatcher.payment_token() == payment_token, "Payment token should match");
}

// TB-U-33: cost_to_play returns correct value
#[test]
fn test_cost_to_play_view() {
    let (_, dispatcher) = deploy_basic_ticket_booth();
    assert!(dispatcher.cost_to_play() == DEFAULT_COST, "Cost to play should match");
}

// TB-U-41: ticket_receiver_address returns correct value
#[test]
fn test_ticket_receiver_address_view() {
    let (_, dispatcher) = deploy_basic_ticket_booth();
    assert!(
        dispatcher.ticket_receiver_address() == TICKET_RECEIVER(), "Ticket receiver should match",
    );
}

// TB-U-42: opening_time returns correct value
#[test]
fn test_opening_time_view() {
    let (_, dispatcher) = deploy_basic_ticket_booth();
    assert!(dispatcher.opening_time() == DEFAULT_OPENING_TIME, "Opening time should match");
}

// =============================================================================
// GOLDEN PASS VIEW TESTS
// =============================================================================

// TB-U-43: get_golden_pass - configured pass
#[test]
fn test_get_golden_pass_configured() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    let golden_pass = GoldenPass {
        cooldown: DEFAULT_COOLDOWN,
        game_expiration: GameExpiration::Dynamic(DEFAULT_EXPIRATION_DURATION),
        pass_expiration: FAR_FUTURE_TIME,
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    let retrieved_pass = dispatcher.get_golden_pass(golden_pass_nft);
    assert!(retrieved_pass.is_some(), "Should return configured golden pass");
}

// TB-U-44: get_golden_pass - unconfigured pass
#[test]
fn test_get_golden_pass_unconfigured() {
    let (_, dispatcher) = deploy_basic_ticket_booth();

    let unconfigured_address: ContractAddress = 'UNCONFIGURED'.try_into().unwrap();
    let retrieved_pass = dispatcher.get_golden_pass(unconfigured_address);
    assert!(retrieved_pass.is_none(), "Should return None for unconfigured pass");
}

// TB-U-46: golden_pass_last_used - never used
#[test]
fn test_golden_pass_last_used_never_used() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    let golden_pass = GoldenPass {
        cooldown: DEFAULT_COOLDOWN, game_expiration: GameExpiration::None, pass_expiration: 0,
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    let last_used = dispatcher.golden_pass_last_used(golden_pass_nft, 1);
    assert!(last_used == 0, "Last used should be 0 for never used pass");
}

// TB-U-50: is_golden_pass_usable - not configured
#[test]
fn test_is_golden_pass_usable_not_configured() {
    let (address, dispatcher) = deploy_basic_ticket_booth();

    start_cheat_block_timestamp(address, FUTURE_TIME);
    let unconfigured: ContractAddress = 'UNCONFIGURED'.try_into().unwrap();
    let usable = dispatcher.is_golden_pass_usable(unconfigured, 1);
    stop_cheat_block_timestamp(address);

    assert!(!usable, "Should return false for unconfigured pass");
}

// TB-U-51: is_golden_pass_usable - configured but cooldown not elapsed
#[test]
fn test_is_golden_pass_usable_cooldown_not_elapsed() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    // Large cooldown that won't be satisfied
    let golden_pass = GoldenPass {
        cooldown: 10000, // Large cooldown
        game_expiration: GameExpiration::None,
        pass_expiration: 0,
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    let (address, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    // With last_used = 0 and cooldown = 10000, need timestamp >= 10000
    // FUTURE_TIME = 2000 < 10000, so should not be usable
    start_cheat_block_timestamp(address, FUTURE_TIME);
    let usable = dispatcher.is_golden_pass_usable(golden_pass_nft, 1);
    stop_cheat_block_timestamp(address);

    assert!(!usable, "Should not be usable when cooldown not elapsed");
}

// TB-U-52: is_golden_pass_usable - configured and cooldown elapsed
#[test]
fn test_is_golden_pass_usable_cooldown_elapsed() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    let golden_pass = GoldenPass {
        cooldown: DEFAULT_COOLDOWN, // 100
        game_expiration: GameExpiration::None,
        pass_expiration: 0,
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    let (address, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    // With last_used = 0 and cooldown = 100, need timestamp >= 100
    // Use LARGE_TIMESTAMP (10000) > 100 so it should be usable
    start_cheat_block_timestamp(address, LARGE_TIMESTAMP);
    let usable = dispatcher.is_golden_pass_usable(golden_pass_nft, 1);
    stop_cheat_block_timestamp(address);

    assert!(usable, "Should be usable when cooldown elapsed");
}

// TB-U-53: is_golden_pass_usable - pass expired
#[test]
fn test_is_golden_pass_usable_pass_expired() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    let golden_pass = GoldenPass {
        cooldown: DEFAULT_COOLDOWN,
        game_expiration: GameExpiration::None,
        pass_expiration: 500 // Expires at 500
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    let (address, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    // Pass expires at 500, current time is LARGE_TIMESTAMP (10000) > 500
    start_cheat_block_timestamp(address, LARGE_TIMESTAMP);
    let usable = dispatcher.is_golden_pass_usable(golden_pass_nft, 1);
    stop_cheat_block_timestamp(address);

    assert!(!usable, "Should not be usable when pass expired");
}

// =============================================================================
// BUY_GAME ERROR PATH TESTS
// =============================================================================

// TB-U-09: Buy game with ticket payment before opening - should fail
#[test]
#[should_panic(expected: "Game not open yet")]
fn test_buy_game_ticket_before_opening() {
    let (address, dispatcher) = deploy_basic_ticket_booth();

    // Set block timestamp before opening
    start_cheat_block_timestamp(address, PAST_TIME);
    start_cheat_caller_address(address, ALICE());

    dispatcher.buy_game(PaymentType::Ticket, Option::None, ALICE(), false);
}

// TB-U-24: Buy game with golden pass - not configured
#[test]
#[should_panic(expected: "Golden pass not configured")]
fn test_buy_game_golden_pass_not_configured() {
    let (address, dispatcher) = deploy_basic_ticket_booth();

    let unconfigured_nft: ContractAddress = 'UNCONFIGURED'.try_into().unwrap();

    start_cheat_block_timestamp(address, FUTURE_TIME);
    start_cheat_caller_address(address, ALICE());

    let payment = PaymentType::GoldenPass(
        GoldenPassInfo { address: unconfigured_nft, token_id: 1 },
    );
    dispatcher.buy_game(payment, Option::None, ALICE(), false);
}

// TB-U-23: Buy game with golden pass - not owner
#[test]
#[should_panic(expected: "Not owner of golden pass")]
fn test_buy_game_golden_pass_not_owner() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    let golden_pass = GoldenPass {
        cooldown: DEFAULT_COOLDOWN, game_expiration: GameExpiration::None, pass_expiration: 0,
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    let (address, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    // Set BOB as owner, but ALICE tries to use
    let nft_setter = IMockERC721SetterDispatcher { contract_address: golden_pass_nft };
    nft_setter.set_owner(1, BOB());

    start_cheat_block_timestamp(address, LARGE_TIMESTAMP);
    start_cheat_caller_address(address, ALICE());

    let payment = PaymentType::GoldenPass(GoldenPassInfo { address: golden_pass_nft, token_id: 1 });
    dispatcher.buy_game(payment, Option::None, ALICE(), false);
}

// TB-U-25: Buy game with golden pass - on cooldown
#[test]
#[should_panic(expected: "Golden pass on cooldown")]
fn test_buy_game_golden_pass_on_cooldown() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    // Large cooldown that won't be satisfied at FUTURE_TIME
    let golden_pass = GoldenPass {
        cooldown: 10000, // Large cooldown
        game_expiration: GameExpiration::None,
        pass_expiration: 0,
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    let (address, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    let nft_setter = IMockERC721SetterDispatcher { contract_address: golden_pass_nft };
    nft_setter.set_owner(1, ALICE());

    // With last_used = 0 and cooldown = 10000, need timestamp >= 10000
    // FUTURE_TIME = 2000 < 10000, so should fail with cooldown error
    start_cheat_block_timestamp(address, FUTURE_TIME);
    start_cheat_caller_address(address, ALICE());

    let payment = PaymentType::GoldenPass(GoldenPassInfo { address: golden_pass_nft, token_id: 1 });
    dispatcher.buy_game(payment, Option::None, ALICE(), false);
}

// =============================================================================
// FUZZ TESTS
// =============================================================================

// TB-F-01: Fuzz cost_to_play values
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_cost_to_play(cost: u128) {
    // Skip zero cost as it's invalid
    if cost == 0 {
        return;
    }

    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        cost,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
    );

    assert!(dispatcher.cost_to_play() == cost, "Cost should match fuzzed value");
}

// TB-F-02: Fuzz opening_time values
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_opening_time(opening_time: u64) {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();

    let (_, dispatcher) = deploy_ticket_booth(
        opening_time,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
    );

    assert!(dispatcher.opening_time() == opening_time, "Opening time should match fuzzed value");
}

// =============================================================================
// MOCK CONTRACTS
// =============================================================================

// Mock TicketBooth contract that embeds the component
#[starknet::contract]
mod MockTicketBoothContract {
    use starknet::ContractAddress;
    use crate::ticket_booth::ticket_booth_component::TicketBoothComponent;

    component!(path: TicketBoothComponent, storage: ticket_booth, event: TicketBoothEvent);

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
        opening_time: u64,
        game_token_address: ContractAddress,
        payment_token: ContractAddress,
        cost_to_play: u128,
        ticket_receiver_address: ContractAddress,
        game_address: Option<ContractAddress>,
        settings_id: Option<u32>,
        start_time: Option<u64>,
        expiration_time: Option<u64>,
        golden_passes: Option<Span<(ContractAddress, crate::ticket_booth::structs::GoldenPass)>>,
    ) {
        self
            .ticket_booth
            .initializer(
                opening_time,
                game_token_address,
                payment_token,
                cost_to_play,
                ticket_receiver_address,
                game_address,
                settings_id,
                start_time,
                expiration_time,
                Option::None, // client_url
                Option::None, // renderer_address
                golden_passes,
            );
    }
}

// Mock ERC20 for payment token
#[starknet::contract]
mod MockERC20ForTicketBooth {
    use openzeppelin_interfaces::erc20::IERC20;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
        total_supply: felt252 // Use felt252 instead of u256 for simple storage
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.total_supply.write(1000000);
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read().into()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = starknet::get_caller_address();
            let sender_balance = self.balances.read(sender);
            assert!(sender_balance >= amount, "Insufficient balance");
            self.balances.write(sender, sender_balance - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let caller = starknet::get_caller_address();
            let current_allowance = self.allowances.read((sender, caller));
            assert!(current_allowance >= amount, "Insufficient allowance");
            self.allowances.write((sender, caller), current_allowance - amount);

            let sender_balance = self.balances.read(sender);
            assert!(sender_balance >= amount, "Insufficient balance");
            self.balances.write(sender, sender_balance - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let owner = starknet::get_caller_address();
            self.allowances.write((owner, spender), amount);
            true
        }
    }

    #[abi(embed_v0)]
    impl MockERC20SetterImpl of super::IMockERC20Setter<ContractState> {
        fn set_balance(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.balances.write(account, amount);
        }

        fn set_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256,
        ) {
            self.allowances.write((owner, spender), amount);
        }
    }
}

// Mock ERC721 for golden pass NFT
#[starknet::contract]
mod MockERC721ForTicketBooth {
    use openzeppelin_interfaces::erc721::IERC721;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use super::IMockERC721Setter;

    #[storage]
    struct Storage {
        owners: Map<u256, ContractAddress>,
        balances: Map<ContractAddress, u256>,
    }

    #[abi(embed_v0)]
    impl ERC721Impl of IERC721<ContractState> {
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self.owners.read(token_id)
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>,
        ) {
            self.transfer_from(from, to, token_id);
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            let owner = self.owners.read(token_id);
            assert!(owner == from, "Not owner");
            self.owners.write(token_id, to);
            self.balances.write(from, self.balances.read(from) - 1);
            self.balances.write(to, self.balances.read(to) + 1);
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {}

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool,
        ) {}

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            0.try_into().unwrap()
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress,
        ) -> bool {
            false
        }
    }

    #[abi(embed_v0)]
    impl MockERC721SetterImpl of IMockERC721Setter<ContractState> {
        fn set_owner(ref self: ContractState, token_id: u256, owner: ContractAddress) {
            self.owners.write(token_id, owner);
            self.balances.write(owner, self.balances.read(owner) + 1);
        }
    }
}

// Mock MinigameToken for ticket booth
#[starknet::contract]
mod MockMinigameTokenForTicketBooth {
    use core::num::traits::Zero;
    use game_components_interfaces::structs::metagame::GameContextDetails;
    use game_components_interfaces::structs::token::{
        Lifecycle, MintParams, PlayerNameUpdate, TokenFullState, TokenMetadata, TokenMutableState,
    };
    use game_components_interfaces::token::{IMINIGAME_TOKEN_ID, IMinigameToken};
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        next_token_id: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_token_id.write(1);
    }

    #[abi(embed_v0)]
    impl MinigameTokenImpl of IMinigameToken<ContractState> {
        fn token_metadata(self: @ContractState, token_id: felt252) -> TokenMetadata {
            TokenMetadata {
                game_id: 0,
                minted_at: 0,
                settings_id: 0,
                lifecycle: Lifecycle { start: 0, end: 0 },
                minted_by: 0,
                soulbound: false,
                game_over: false,
                completed_objective: false,
                has_context: false,
                objective_id: 0,
                paymaster: false,
                metadata: 0,
            }
        }

        fn is_playable(self: @ContractState, token_id: felt252) -> bool {
            true
        }

        fn assert_is_playable(self: @ContractState, token_id: felt252) {}

        fn settings_id(self: @ContractState, token_id: felt252) -> u32 {
            0
        }

        fn player_name(self: @ContractState, token_id: felt252) -> felt252 {
            0
        }

        fn objective_id(self: @ContractState, token_id: felt252) -> u32 {
            0
        }

        fn minted_by(self: @ContractState, token_id: felt252) -> felt252 {
            0
        }

        fn minted_by_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            0.try_into().unwrap()
        }

        fn game_address(self: @ContractState) -> ContractAddress {
            Zero::zero()
        }

        fn game_registry_address(self: @ContractState) -> ContractAddress {
            Zero::zero()
        }

        fn is_soulbound(self: @ContractState, token_id: felt252) -> bool {
            false
        }

        fn renderer_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            Zero::zero()
        }

        fn token_game_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            Zero::zero()
        }

        fn token_mutable_state(self: @ContractState, token_id: felt252) -> TokenMutableState {
            TokenMutableState { game_over: false, completed_objective: false }
        }

        fn client_url(self: @ContractState, token_id: felt252) -> ByteArray {
            ""
        }

        fn skills_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            0.try_into().unwrap()
        }

        fn token_metadata_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenMetadata> {
            array![]
        }

        fn is_playable_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            array![]
        }

        fn settings_id_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u32> {
            array![]
        }

        fn player_name_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<felt252> {
            array![]
        }

        fn objective_id_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u32> {
            array![]
        }

        fn minted_by_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<felt252> {
            array![]
        }

        fn minted_by_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            array![]
        }

        fn is_soulbound_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            array![]
        }

        fn renderer_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            array![]
        }

        fn token_game_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            array![]
        }

        fn token_mutable_state_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenMutableState> {
            array![]
        }

        fn token_full_state_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenFullState> {
            array![]
        }

        fn mint(
            ref self: ContractState,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> felt252 {
            let token_id_u64 = self.next_token_id.read();
            self.next_token_id.write(token_id_u64 + 1);
            let token_id: felt252 = token_id_u64.into();
            token_id
        }

        fn mint_batch(ref self: ContractState, mints: Array<MintParams>) -> Array<felt252> {
            array![]
        }

        fn mint_batch_recipients(
            ref self: ContractState,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            recipients: Array<ContractAddress>,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> Array<felt252> {
            panic!("not implemented")
        }

        fn update_game(ref self: ContractState, token_id: felt252) {}

        fn update_player_name(ref self: ContractState, token_id: felt252, name: felt252) {}

        fn update_game_batch(ref self: ContractState, token_ids: Span<felt252>) {}

        fn update_player_name_batch(ref self: ContractState, updates: Span<PlayerNameUpdate>) {}
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IMINIGAME_TOKEN_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }
}

// =============================================================================
// PURE LIBRARY TESTS
// =============================================================================

// TB-U-62: calculate_ticket_expiration with Some duration
#[test]
fn test_calculate_ticket_expiration_with_duration() {
    let result = crate::ticket_booth::ticket_booth::calculate_ticket_expiration(
        Option::Some(3600), 1000,
    );
    assert!(result == Option::Some(4600), "Should be current_time + duration");
}

// TB-U-63: calculate_ticket_expiration with None duration
#[test]
fn test_calculate_ticket_expiration_with_none() {
    let result = crate::ticket_booth::ticket_booth::calculate_ticket_expiration(Option::None, 1000);
    assert!(result.is_none(), "Should be None when no duration");
}

// TB-U-64: calculate_golden_pass_expiration variants
#[test]
fn test_calculate_golden_pass_expiration_none() {
    let result = crate::ticket_booth::ticket_booth::calculate_golden_pass_expiration(
        @GameExpiration::None, 1000,
    );
    assert!(result.is_none(), "None expiration should return None");
}

#[test]
fn test_calculate_golden_pass_expiration_fixed() {
    let result = crate::ticket_booth::ticket_booth::calculate_golden_pass_expiration(
        @GameExpiration::Fixed(5000), 1000,
    );
    assert!(result == Option::Some(5000), "Fixed should return the fixed timestamp");
}

#[test]
fn test_calculate_golden_pass_expiration_dynamic() {
    let result = crate::ticket_booth::ticket_booth::calculate_golden_pass_expiration(
        @GameExpiration::Dynamic(3600), 1000,
    );
    assert!(result == Option::Some(4600), "Dynamic should return current_time + duration");
}

// TB-U-65: is_golden_pass_configured
#[test]
fn test_is_golden_pass_configured_true() {
    let pass = GoldenPass {
        cooldown: 100, game_expiration: GameExpiration::None, pass_expiration: 0,
    };
    assert!(
        crate::ticket_booth::ticket_booth::is_golden_pass_configured(@pass),
        "Should be configured with cooldown > 0",
    );
}

#[test]
fn test_is_golden_pass_configured_false() {
    let pass = GoldenPass {
        cooldown: 0, game_expiration: GameExpiration::None, pass_expiration: 0,
    };
    assert!(
        !crate::ticket_booth::ticket_booth::is_golden_pass_configured(@pass),
        "Should not be configured with cooldown = 0",
    );
}

// TB-U-66: is_golden_pass_usable edge cases
#[test]
fn test_is_golden_pass_usable_zero_cooldown() {
    let pass = GoldenPass {
        cooldown: 0, game_expiration: GameExpiration::None, pass_expiration: 0,
    };
    assert!(
        !crate::ticket_booth::ticket_booth::is_golden_pass_usable(@pass, 0, 1000),
        "Should not be usable with zero cooldown",
    );
}

#[test]
fn test_is_golden_pass_usable_not_expired_cooldown_met() {
    let pass = GoldenPass {
        cooldown: 100, game_expiration: GameExpiration::None, pass_expiration: 5000,
    };
    // last_used=0, cooldown=100, current_time=1000 >= 0+100
    assert!(
        crate::ticket_booth::ticket_booth::is_golden_pass_usable(@pass, 0, 1000),
        "Should be usable when not expired and cooldown met",
    );
}

#[test]
fn test_is_golden_pass_usable_expired() {
    let pass = GoldenPass {
        cooldown: 100, game_expiration: GameExpiration::None, pass_expiration: 500,
    };
    // pass_expiration=500, current_time=1000 >= 500 => expired
    assert!(
        !crate::ticket_booth::ticket_booth::is_golden_pass_usable(@pass, 0, 1000),
        "Should not be usable when expired",
    );
}

// =============================================================================
// BUY GAME WITH BURN PATH (ticket_receiver_address = zero)
// =============================================================================

// TB-U-67: Buy game with zero ticket_receiver triggers burn fallback
#[test]
fn test_buy_game_ticket_zero_receiver_burn_fallback() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let zero_receiver: ContractAddress = 0.try_into().unwrap();

    let (address, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        zero_receiver, // Zero receiver triggers burn path
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
    );

    // Fund ALICE with tokens by setting balance directly
    let mock_setter = IMockERC20SetterDispatcher { contract_address: payment_token };
    mock_setter.set_balance(ALICE(), DEFAULT_COST.into());
    mock_setter.set_allowance(ALICE(), address, DEFAULT_COST.into());

    start_cheat_block_timestamp(address, FUTURE_TIME);
    start_cheat_caller_address(address, ALICE());

    // This exercises the burn fallback path (burn_from will fail on mock,
    // falling back to transfer_from to zero address)
    let token_id = dispatcher.buy_game(PaymentType::Ticket, Option::None, ALICE(), false);
    assert!(token_id != 0, "Should mint a token");
}

// =============================================================================
// ADDITIONAL VIEW FUNCTION TESTS
// =============================================================================

// TB-U-54: client_url returns correct value when set
#[test]
fn test_client_url_view_when_set() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();

    let contract = declare("MockTicketBoothContractWithClientUrl").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(DEFAULT_OPENING_TIME.into());
    calldata.append(game_token.into());
    calldata.append(payment_token.into());
    calldata.append(DEFAULT_COST.into());
    calldata.append(TICKET_RECEIVER().into());
    calldata.append(1); // None for game_address
    calldata.append(1); // None for settings_id
    calldata.append(1); // None for start_time
    calldata.append(1); // None for expiration_time
    calldata.append(1); // None for golden_passes

    let (address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = ITicketBoothDispatcher { contract_address: address };

    let client_url = dispatcher.client_url();
    assert!(client_url == Option::Some("https://test.game.com"), "Client URL mismatch");
}

// TB-U-55: client_url returns None when not set
#[test]
fn test_client_url_view_when_none() {
    let (_, dispatcher) = deploy_basic_ticket_booth();
    let client_url = dispatcher.client_url();
    assert!(client_url.is_none(), "Client URL should be None");
}

// TB-U-56: renderer_address returns correct value when set
#[test]
fn test_renderer_address_view_when_set() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let renderer: ContractAddress = 0xDEAD.try_into().unwrap();

    let contract = declare("MockTicketBoothContractWithRenderer").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(DEFAULT_OPENING_TIME.into());
    calldata.append(game_token.into());
    calldata.append(payment_token.into());
    calldata.append(DEFAULT_COST.into());
    calldata.append(TICKET_RECEIVER().into());
    calldata.append(renderer.into());

    let (address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = ITicketBoothDispatcher { contract_address: address };

    let result = dispatcher.renderer_address();
    assert!(result == Option::Some(renderer), "Renderer address mismatch");
}

// TB-U-57: renderer_address returns None when not set
#[test]
fn test_renderer_address_view_when_none() {
    let (_, dispatcher) = deploy_basic_ticket_booth();
    let result = dispatcher.renderer_address();
    assert!(result.is_none(), "Renderer address should be None");
}

// =============================================================================
// GOLDEN PASS EXPIRATION TESTS
// =============================================================================

// TB-U-58: Golden pass with Fixed expiration
#[test]
fn test_golden_pass_fixed_expiration() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    let golden_pass = GoldenPass {
        cooldown: DEFAULT_COOLDOWN,
        game_expiration: GameExpiration::Fixed(50000), // Fixed expiration timestamp
        pass_expiration: 0,
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    let retrieved_pass = dispatcher.get_golden_pass(golden_pass_nft);
    assert!(retrieved_pass.is_some(), "Should have golden pass");

    if let Option::Some(pass) = retrieved_pass {
        match pass.game_expiration {
            GameExpiration::Fixed(time) => assert!(time == 50000, "Fixed time mismatch"),
            _ => panic!("Wrong expiration type"),
        }
    }
}

// TB-U-59: Golden pass with Dynamic expiration
#[test]
fn test_golden_pass_dynamic_expiration() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    let golden_pass = GoldenPass {
        cooldown: DEFAULT_COOLDOWN,
        game_expiration: GameExpiration::Dynamic(3600), // 1 hour duration
        pass_expiration: 0,
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    let retrieved_pass = dispatcher.get_golden_pass(golden_pass_nft);
    assert!(retrieved_pass.is_some(), "Should have golden pass");

    if let Option::Some(pass) = retrieved_pass {
        match pass.game_expiration {
            GameExpiration::Dynamic(duration) => assert!(duration == 3600, "Duration mismatch"),
            _ => panic!("Wrong expiration type"),
        }
    }
}

// TB-U-60: Multiple golden passes
#[test]
fn test_multiple_golden_passes_configuration() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft_1 = deploy_mock_erc721();
    let golden_pass_nft_2 = deploy_mock_erc721();

    let golden_pass_1 = GoldenPass {
        cooldown: 100, game_expiration: GameExpiration::None, pass_expiration: 0,
    };

    let golden_pass_2 = GoldenPass {
        cooldown: 200,
        game_expiration: GameExpiration::Fixed(10000),
        pass_expiration: FAR_FUTURE_TIME,
    };

    let passes = array![(golden_pass_nft_1, golden_pass_1), (golden_pass_nft_2, golden_pass_2)];

    let (_, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME,
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    let retrieved_pass_1 = dispatcher.get_golden_pass(golden_pass_nft_1);
    let retrieved_pass_2 = dispatcher.get_golden_pass(golden_pass_nft_2);

    assert!(retrieved_pass_1.is_some(), "Should have first golden pass");
    assert!(retrieved_pass_2.is_some(), "Should have second golden pass");

    if let Option::Some(pass) = retrieved_pass_1 {
        assert!(pass.cooldown == 100, "First pass cooldown mismatch");
    }

    if let Option::Some(pass) = retrieved_pass_2 {
        assert!(pass.cooldown == 200, "Second pass cooldown mismatch");
    }
}

// =============================================================================
// BUY GAME WITH GOLDEN PASS EXPIRED TEST
// =============================================================================

// TB-U-61: Buy game with golden pass - pass expired
#[test]
#[should_panic(expected: "Golden pass expired")]
fn test_buy_game_golden_pass_expired() {
    let game_token = deploy_mock_minigame_token();
    let payment_token = deploy_mock_erc20();
    let golden_pass_nft = deploy_mock_erc721();

    let golden_pass = GoldenPass {
        cooldown: DEFAULT_COOLDOWN,
        game_expiration: GameExpiration::None,
        pass_expiration: 1500 // Expires at timestamp 1500, after opening time
    };

    let passes = array![(golden_pass_nft, golden_pass)];

    // Set opening time to 1000 (DEFAULT_OPENING_TIME)
    let (address, dispatcher) = deploy_ticket_booth(
        DEFAULT_OPENING_TIME, // 1000
        game_token,
        payment_token,
        DEFAULT_COST,
        TICKET_RECEIVER(),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(passes.span()),
    );

    let nft_setter = IMockERC721SetterDispatcher { contract_address: golden_pass_nft };
    nft_setter.set_owner(1, ALICE());

    // Set timestamp to after both opening time (1000) and pass expiration (1500)
    start_cheat_block_timestamp(address, 2000); // > 1500, so pass is expired but game is open
    start_cheat_caller_address(address, ALICE());

    let payment = PaymentType::GoldenPass(GoldenPassInfo { address: golden_pass_nft, token_id: 1 });
    dispatcher.buy_game(payment, Option::None, ALICE(), false);
}

// =============================================================================
// ADDITIONAL MOCK CONTRACTS
// =============================================================================

// Mock TicketBooth with client_url set
#[starknet::contract]
mod MockTicketBoothContractWithClientUrl {
    use starknet::ContractAddress;
    use crate::ticket_booth::ticket_booth_component::TicketBoothComponent;

    component!(path: TicketBoothComponent, storage: ticket_booth, event: TicketBoothEvent);

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
        opening_time: u64,
        game_token_address: ContractAddress,
        payment_token: ContractAddress,
        cost_to_play: u128,
        ticket_receiver_address: ContractAddress,
        game_address: Option<ContractAddress>,
        settings_id: Option<u32>,
        start_time: Option<u64>,
        expiration_time: Option<u64>,
        golden_passes: Option<Span<(ContractAddress, crate::ticket_booth::structs::GoldenPass)>>,
    ) {
        self
            .ticket_booth
            .initializer(
                opening_time,
                game_token_address,
                payment_token,
                cost_to_play,
                ticket_receiver_address,
                game_address,
                settings_id,
                start_time,
                expiration_time,
                Option::Some("https://test.game.com"),
                Option::None,
                golden_passes,
            );
    }
}

// Mock TicketBooth with renderer_address set
#[starknet::contract]
mod MockTicketBoothContractWithRenderer {
    use starknet::ContractAddress;
    use crate::ticket_booth::ticket_booth_component::TicketBoothComponent;

    component!(path: TicketBoothComponent, storage: ticket_booth, event: TicketBoothEvent);

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
        opening_time: u64,
        game_token_address: ContractAddress,
        payment_token: ContractAddress,
        cost_to_play: u128,
        ticket_receiver_address: ContractAddress,
        renderer_address: ContractAddress,
    ) {
        self
            .ticket_booth
            .initializer(
                opening_time,
                game_token_address,
                payment_token,
                cost_to_play,
                ticket_receiver_address,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::Some(renderer_address),
                Option::None,
            );
    }
}
