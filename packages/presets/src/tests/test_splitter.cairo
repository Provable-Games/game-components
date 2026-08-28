// ==============================================================================
// REVENUE SPLITTER TESTS
// ==============================================================================
// Two properties carry the whole contract:
//
//   1. Conservation — the parts always sum to the whole, at any amount and
//      any number of legs, with nothing stranded.
//   2. Token-agnosticism — any ERC20, no per-token configuration.
//
// Everything else is input validation on the constructor -- the only place a
// split is ever written.

use game_components_interfaces::tokenomics::splitter::{
    ISplitterDispatcher, ISplitterDispatcherTrait, SplitLeg,
};
use openzeppelin_interfaces::access::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use super::mocks::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn NOT_OWNER() -> ContractAddress {
    'NOT_OWNER'.try_into().unwrap()
}

/// Stands in for the BUDOKAN buyback (80%).
fn BUYBACK_A() -> ContractAddress {
    'BUYBACK_A'.try_into().unwrap()
}

/// Stands in for the STRK buyback (20%).
fn BUYBACK_B() -> ContractAddress {
    'BUYBACK_B'.try_into().unwrap()
}

fn THIRD() -> ContractAddress {
    'THIRD'.try_into().unwrap()
}

fn ZERO() -> ContractAddress {
    0.try_into().unwrap()
}

/// Filler destinations so a split can be built at MAX_LEGS. Destinations must
/// be distinct, so these exist purely to reach eight.
fn DEST_E() -> ContractAddress {
    'DEST_E'.try_into().unwrap()
}

fn DEST_F() -> ContractAddress {
    'DEST_F'.try_into().unwrap()
}

fn DEST_G() -> ContractAddress {
    'DEST_G'.try_into().unwrap()
}

fn DEST_H() -> ContractAddress {
    'DEST_H'.try_into().unwrap()
}

fn deploy_mock_erc20(name: ByteArray, symbol: ByteArray) -> ContractAddress {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

fn default_legs() -> Span<SplitLeg> {
    array![
        SplitLeg { destination: BUYBACK_A(), bps: 8000 },
        SplitLeg { destination: BUYBACK_B(), bps: 2000 },
    ]
        .span()
}

fn deploy_splitter_with(legs: Span<SplitLeg>) -> ContractAddress {
    let contract = declare("Splitter").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    legs.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

fn deploy_splitter() -> ContractAddress {
    deploy_splitter_with(default_legs())
}

/// A constructor panic surfaces as an `Err` from `deploy`, not as a panic in
/// the caller — `deploy(...).unwrap()` would report `Result::unwrap failed`
/// and hide which assert actually fired. So these assert on the payload.
fn assert_deploy_fails_with(legs: Span<SplitLeg>, expected: felt252) {
    let contract = declare("Splitter").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    legs.serialize(ref calldata);

    match contract.deploy(@calldata) {
        Result::Ok(_) => panic!("deploy should have been rejected"),
        Result::Err(err) => assert!(*err.at(0) == expected, "wrong rejection reason"),
    }
}

// ==============================================================================
// CONSTRUCTION AND VALIDATION
// ==============================================================================

#[test]
fn test_constructor_sets_the_split() {
    let splitter = deploy_splitter();
    let dispatcher = ISplitterDispatcher { contract_address: splitter };

    let legs = dispatcher.split();
    assert!(legs.len() == 2, "split should have two legs");
    assert!(*legs.at(0) == SplitLeg { destination: BUYBACK_A(), bps: 8000 }, "leg 0 mismatch");
    assert!(*legs.at(1) == SplitLeg { destination: BUYBACK_B(), bps: 2000 }, "leg 1 mismatch");
}

#[test]
fn test_rejects_split_that_does_not_sum_to_10000() {
    let legs = array![
        SplitLeg { destination: BUYBACK_A(), bps: 8000 },
        SplitLeg { destination: BUYBACK_B(), bps: 1000 },
    ]
        .span();
    assert_deploy_fails_with(legs, 'Split must sum to 10000 bps');
}

#[test]
fn test_rejects_duplicate_destinations() {
    let legs = array![
        SplitLeg { destination: BUYBACK_A(), bps: 8000 },
        SplitLeg { destination: BUYBACK_A(), bps: 2000 },
    ]
        .span();
    assert_deploy_fails_with(legs, 'Duplicate destination');
}

#[test]
fn test_rejects_empty_split() {
    assert_deploy_fails_with(array![].span(), 'Split must have >= 1 leg');
}

#[test]
fn test_rejects_zero_destination() {
    let legs = array![
        SplitLeg { destination: ZERO(), bps: 8000 },
        SplitLeg { destination: BUYBACK_B(), bps: 2000 },
    ]
        .span();
    assert_deploy_fails_with(legs, 'Destination cannot be zero');
}

#[test]
fn test_rejects_zero_bps_leg() {
    let legs = array![
        SplitLeg { destination: BUYBACK_A(), bps: 10000 },
        SplitLeg { destination: BUYBACK_B(), bps: 0 },
    ]
        .span();
    assert_deploy_fails_with(legs, 'Leg bps must be non-zero');
}

#[test]
fn test_rejects_more_than_max_legs() {
    // Nine legs, one over MAX_LEGS.
    let legs = array![
        SplitLeg { destination: 1.try_into().unwrap(), bps: 2000 },
        SplitLeg { destination: 2.try_into().unwrap(), bps: 1000 },
        SplitLeg { destination: 3.try_into().unwrap(), bps: 1000 },
        SplitLeg { destination: 4.try_into().unwrap(), bps: 1000 },
        SplitLeg { destination: 5.try_into().unwrap(), bps: 1000 },
        SplitLeg { destination: 6.try_into().unwrap(), bps: 1000 },
        SplitLeg { destination: 7.try_into().unwrap(), bps: 1000 },
        SplitLeg { destination: 8.try_into().unwrap(), bps: 1000 },
        SplitLeg { destination: 9.try_into().unwrap(), bps: 1000 },
    ]
        .span();
    assert_deploy_fails_with(legs, 'Too many legs');
}

#[test]
fn test_single_leg_split_is_allowed() {
    let splitter = deploy_splitter_with(
        array![SplitLeg { destination: BUYBACK_A(), bps: 10000 }].span(),
    );
    let token = deploy_mock_erc20("Revenue", "REV");
    IMockERC20Dispatcher { contract_address: token }.mint(splitter, 777);

    ISplitterDispatcher { contract_address: splitter }.distribute(token);

    let erc20 = IERC20Dispatcher { contract_address: token };
    assert!(erc20.balance_of(BUYBACK_A()) == 777, "sole leg should receive everything");
    assert!(erc20.balance_of(splitter) == 0, "no dust stranded");
}

// ==============================================================================
// DISTRIBUTION
// ==============================================================================

#[test]
fn test_distribute_splits_80_20() {
    let splitter = deploy_splitter();
    let token = deploy_mock_erc20("Revenue", "REV");
    IMockERC20Dispatcher { contract_address: token }.mint(splitter, 1000);

    ISplitterDispatcher { contract_address: splitter }.distribute(token);

    let erc20 = IERC20Dispatcher { contract_address: token };
    assert!(erc20.balance_of(BUYBACK_A()) == 800, "leg A should receive 80%");
    assert!(erc20.balance_of(BUYBACK_B()) == 200, "leg B should receive 20%");
    assert!(erc20.balance_of(splitter) == 0, "splitter should retain nothing");
}

/// Token-agnostic: no per-token setup, and each token splits independently.
#[test]
fn test_distribute_works_for_any_token() {
    let splitter = deploy_splitter();
    let usdc = deploy_mock_erc20("USDC", "USDC");
    let strk = deploy_mock_erc20("Starknet Token", "STRK");
    IMockERC20Dispatcher { contract_address: usdc }.mint(splitter, 500);
    IMockERC20Dispatcher { contract_address: strk }.mint(splitter, 2000);

    ISplitterDispatcher { contract_address: splitter }.distribute_many(array![usdc, strk].span());

    assert!(IERC20Dispatcher { contract_address: usdc }.balance_of(BUYBACK_A()) == 400, "usdc A");
    assert!(IERC20Dispatcher { contract_address: usdc }.balance_of(BUYBACK_B()) == 100, "usdc B");
    assert!(IERC20Dispatcher { contract_address: strk }.balance_of(BUYBACK_A()) == 1600, "strk A");
    assert!(IERC20Dispatcher { contract_address: strk }.balance_of(BUYBACK_B()) == 400, "strk B");
}

/// Conservation under rounding: 9 units at 80/20 is 7.2 / 1.8. The earlier
/// leg floors to 7 and the final leg takes the remainder, so the parts still
/// sum to 9 and nothing is left behind.
#[test]
fn test_rounding_strands_nothing() {
    let splitter = deploy_splitter();
    let token = deploy_mock_erc20("Revenue", "REV");
    IMockERC20Dispatcher { contract_address: token }.mint(splitter, 9);

    ISplitterDispatcher { contract_address: splitter }.distribute(token);

    let erc20 = IERC20Dispatcher { contract_address: token };
    let a = erc20.balance_of(BUYBACK_A());
    let b = erc20.balance_of(BUYBACK_B());
    assert!(a == 7, "earlier leg floors");
    assert!(b == 2, "final leg takes the remainder");
    assert!(a + b == 9, "parts must sum to the whole");
    assert!(erc20.balance_of(splitter) == 0, "no dust stranded");
}

/// Conservation at MAX_LEGS, fuzzed. The suite otherwise tops out at three
/// legs and hand-picked amounts, so a regression that only shows up with more
/// legs — where seven floors accumulate before the remainder lands — would not
/// have been caught. Eight legs is the configured maximum, so this is the
/// worst case the contract can be put in.
///
/// The property is exact: whatever arrives, the parts sum to it and the
/// splitter keeps nothing. Fuzzed rather than sampled because rounding bugs
/// hide in specific residues, not round numbers.
#[test]
#[fuzzer(runs: 500)]
fn test_conservation_holds_at_max_legs(amount: u64) {
    // u64 keeps the fuzzer in a realistic token range; 0 has nothing to
    // distribute and reverts by design, covered separately.
    let amount: u256 = if amount == 0 {
        1
    } else {
        amount.into()
    };

    let dests = array![
        BUYBACK_A(), BUYBACK_B(), THIRD(), NOT_OWNER(), DEST_E(), DEST_F(), DEST_G(), DEST_H(),
    ];
    // Eight legs, deliberately uneven so every floor loses a different residue.
    let bps = array![1250_u16, 1249, 1251, 1248, 1252, 1247, 1253, 1250];
    let mut legs: Array<SplitLeg> = array![];
    let mut i: u32 = 0;
    while i < 8 {
        legs.append(SplitLeg { destination: *dests.at(i), bps: *bps.at(i) });
        i += 1;
    }

    let splitter = deploy_splitter_with(legs.span());
    let token = deploy_mock_erc20("Revenue", "REV");
    IMockERC20Dispatcher { contract_address: token }.mint(splitter, amount);

    ISplitterDispatcher { contract_address: splitter }.distribute(token);

    let erc20 = IERC20Dispatcher { contract_address: token };
    let mut paid: u256 = 0;
    let mut j: u32 = 0;
    while j < 8 {
        paid += erc20.balance_of(*dests.at(j));
        j += 1;
    }
    assert!(paid == amount, "eight legs must still sum to the whole");
    assert!(erc20.balance_of(splitter) == 0, "no dust stranded at max legs");
}

/// The smallest possible amount: the sole unit goes to the final leg rather
/// than being rounded away.
#[test]
fn test_single_unit_is_not_lost() {
    let splitter = deploy_splitter();
    let token = deploy_mock_erc20("Revenue", "REV");
    IMockERC20Dispatcher { contract_address: token }.mint(splitter, 1);

    ISplitterDispatcher { contract_address: splitter }.distribute(token);

    let erc20 = IERC20Dispatcher { contract_address: token };
    assert!(erc20.balance_of(BUYBACK_A()) == 0, "80% of one unit floors to zero");
    assert!(erc20.balance_of(BUYBACK_B()) == 1, "final leg takes the remainder");
    assert!(erc20.balance_of(splitter) == 0, "no dust stranded");
}

#[test]
fn test_three_way_split_conserves() {
    let legs = array![
        SplitLeg { destination: BUYBACK_A(), bps: 5000 },
        SplitLeg { destination: THIRD(), bps: 3000 },
        SplitLeg { destination: BUYBACK_B(), bps: 2000 },
    ]
        .span();
    let splitter = deploy_splitter_with(legs);
    let token = deploy_mock_erc20("Revenue", "REV");
    IMockERC20Dispatcher { contract_address: token }.mint(splitter, 1001);

    ISplitterDispatcher { contract_address: splitter }.distribute(token);

    let erc20 = IERC20Dispatcher { contract_address: token };
    let a = erc20.balance_of(BUYBACK_A());
    let t = erc20.balance_of(THIRD());
    let b = erc20.balance_of(BUYBACK_B());
    assert!(a == 500, "leg A floors to 500");
    assert!(t == 300, "leg THIRD floors to 300");
    assert!(b == 201, "final leg absorbs the remainder");
    assert!(a + t + b == 1001, "parts must sum to the whole");
    assert!(erc20.balance_of(splitter) == 0, "no dust stranded");
}

#[test]
fn test_distribute_is_permissionless() {
    let splitter = deploy_splitter();
    let token = deploy_mock_erc20("Revenue", "REV");
    IMockERC20Dispatcher { contract_address: token }.mint(splitter, 1000);

    // Anyone may call it — the funds only ever move to configured legs.
    start_cheat_caller_address(splitter, NOT_OWNER());
    ISplitterDispatcher { contract_address: splitter }.distribute(token);
    stop_cheat_caller_address(splitter);

    assert!(
        IERC20Dispatcher { contract_address: token }.balance_of(BUYBACK_A()) == 800,
        "distribute should succeed for a non-owner",
    );
}

#[test]
#[should_panic(expected: 'No balance to distribute')]
fn test_distribute_rejects_empty_balance() {
    let splitter = deploy_splitter();
    let token = deploy_mock_erc20("Revenue", "REV");
    ISplitterDispatcher { contract_address: splitter }.distribute(token);
}

// ==============================================================================
// IMMUTABILITY
// ==============================================================================
// The split is written once, in the constructor. There is no setter and no
// owner. Redirecting the revenue SOURCE to a different splitter is the
// supported way to change a split, which costs the same governance action and
// leaves an audit trail, so mutability here would have added risk and no
// capability.

/// The contract exposes no ownership surface at all.
///
/// Not merely "the owner cannot change the split" — there is no owner. An
/// `owner()` entrypoint would imply a control that does not exist, and the
/// only honest ABI for an immutable contract is one with nothing to call.
/// Asserting the absence is the only way to keep it absent: a future edit that
/// reintroduces `OwnableComponent` for convenience fails here.
#[test]
#[should_panic]
fn test_splitter_has_no_owner_entrypoint() {
    let splitter = deploy_splitter();
    IOwnableDispatcher { contract_address: splitter }.owner();
}

/// The split still reads back exactly as constructed after use.
///
/// Pairs with the test above: nothing can change it, and nothing does.
#[test]
fn test_split_is_unchanged_by_distributing() {
    let splitter = deploy_splitter();
    let dispatcher = ISplitterDispatcher { contract_address: splitter };

    let token = deploy_mock_erc20("Revenue", "REV");
    IMockERC20Dispatcher { contract_address: token }.mint(splitter, 1000);
    dispatcher.distribute(token);
    IMockERC20Dispatcher { contract_address: token }.mint(splitter, 1000);
    dispatcher.distribute(token);

    let legs = dispatcher.split();
    assert!(legs.len() == 2, "still two legs");
    assert!(*legs.at(0).bps == 8000, "leg A share unchanged");
    assert!(*legs.at(1).bps == 2000, "leg B share unchanged");

    let erc20 = IERC20Dispatcher { contract_address: token };
    assert!(erc20.balance_of(BUYBACK_A()) == 1600, "80% across both distributes");
    assert!(erc20.balance_of(BUYBACK_B()) == 400, "20% across both distributes");
}
