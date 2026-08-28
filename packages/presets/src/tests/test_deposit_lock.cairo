// ==============================================================================
// DEPOSIT LOCK TESTS
// ==============================================================================
// The property that matters: EACH deposit is held for a full term from its own
// arrival. That is exactly what OZ's VestingComponent cannot express — it vests
// one aggregate against one schedule, so a late deposit would be under-locked
// and a post-cliff deposit not locked at all.

use game_components_interfaces::tokenomics::deposit_lock::{
    IDepositLockAdminDispatcher, IDepositLockAdminDispatcherTrait, IDepositLockDispatcher,
    IDepositLockDispatcherTrait,
};
use openzeppelin_interfaces::access::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp_global,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use super::mocks::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

const DAY: u64 = 86400;
const ONE_YEAR: u64 = 365 * DAY;
/// A clean day boundary, so maturity assertions are exact.
const T0: u64 = 1_000_000 * DAY;

fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn NOT_OWNER() -> ContractAddress {
    'NOT_OWNER'.try_into().unwrap()
}

fn TREASURY() -> ContractAddress {
    'TREASURY'.try_into().unwrap()
}

fn deploy_token() -> ContractAddress {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "Starknet Token";
    let symbol: ByteArray = "STRK";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

fn deploy_lock(token: ContractAddress) -> ContractAddress {
    let contract = declare("DepositLock").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    token.serialize(ref calldata);
    TREASURY().serialize(ref calldata);
    ONE_YEAR.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

fn setup() -> (ContractAddress, ContractAddress) {
    let token = deploy_token();
    let lock = deploy_lock(token);
    start_cheat_block_timestamp_global(T0);
    (token, lock)
}

/// Send tokens in and stamp them, as the splitter's 20% leg would.
fn deposit(token: ContractAddress, lock: ContractAddress, amount: u256) {
    IMockERC20Dispatcher { contract_address: token }.mint(lock, amount);
    IDepositLockDispatcher { contract_address: lock }.lock();
}

// ==============================================================================
// THE TERM
// ==============================================================================

#[test]
fn test_deposit_is_not_releasable_before_a_year() {
    let (token, lock) = setup();
    deposit(token, lock, 1000);
    let dispatcher = IDepositLockDispatcher { contract_address: lock };

    start_cheat_block_timestamp_global(T0 + ONE_YEAR - DAY);
    assert!(dispatcher.releasable() == 0, "must not mature a day early");
    assert!(dispatcher.locked_total() == 1000, "still locked");
}

#[test]
fn test_deposit_is_releasable_after_a_year() {
    let (token, lock) = setup();
    deposit(token, lock, 1000);
    let dispatcher = IDepositLockDispatcher { contract_address: lock };

    start_cheat_block_timestamp_global(T0 + ONE_YEAR);
    assert!(dispatcher.releasable() == 1000, "should mature at the term");

    dispatcher.release(10);
    assert!(
        IERC20Dispatcher { contract_address: token }.balance_of(TREASURY()) == 1000,
        "beneficiary receives the matured deposit",
    );
    assert!(dispatcher.locked_total() == 0, "nothing left locked");
}

/// The escape hatch has to work without anyone's cooperation. `lock` being
/// permissionless is covered below, but that only stamps deposits — if
/// `release` were gated, matured STRK would sit here until whoever holds the
/// key chose to move it, which is the opposite of the guarantee.
///
/// Asserts BOTH halves: a stranger can call it, and the funds still go to the
/// beneficiary rather than to the caller.
#[test]
fn test_release_is_permissionless_and_pays_the_beneficiary() {
    let (token, lock) = setup();
    deposit(token, lock, 1000);
    let dispatcher = IDepositLockDispatcher { contract_address: lock };
    let erc20 = IERC20Dispatcher { contract_address: token };

    start_cheat_block_timestamp_global(T0 + ONE_YEAR);

    start_cheat_caller_address(lock, NOT_OWNER());
    dispatcher.release(10);
    stop_cheat_caller_address(lock);

    assert!(erc20.balance_of(TREASURY()) == 1000, "matured funds go to the beneficiary");
    assert!(erc20.balance_of(NOT_OWNER()) == 0, "never to whoever called release");
    assert!(dispatcher.locked_total() == 0, "nothing left locked");
}

#[test]
#[should_panic(expected: 'Nothing matured to release')]
fn test_release_before_maturity_reverts() {
    let (token, lock) = setup();
    deposit(token, lock, 1000);
    start_cheat_block_timestamp_global(T0 + ONE_YEAR - 1);
    IDepositLockDispatcher { contract_address: lock }.release(10);
}

/// Rounding is UP, so a deposit made mid-day is locked for at least the full
/// term — never a few hours short of it.
#[test]
fn test_rounding_never_under_locks() {
    let token = deploy_token();
    let lock = deploy_lock(token);
    // Deliberately NOT a day boundary.
    let t_mid = T0 + 3600 * 7;
    start_cheat_block_timestamp_global(t_mid);
    deposit(token, lock, 1000);
    let dispatcher = IDepositLockDispatcher { contract_address: lock };

    start_cheat_block_timestamp_global(t_mid + ONE_YEAR);
    assert!(dispatcher.releasable() == 0, "must not mature before a full term elapses");

    start_cheat_block_timestamp_global(t_mid + ONE_YEAR + DAY);
    assert!(dispatcher.releasable() == 1000, "matures within a day of the term");
}

// ==============================================================================
// PER-DEPOSIT TERMS — what OZ vesting cannot do
// ==============================================================================

/// A later deposit keeps its OWN term. Under OZ vesting both would unlock at
/// the same cliff, locking the second for a fraction of the intended year.
#[test]
fn test_each_deposit_keeps_its_own_term() {
    let (token, lock) = setup();
    let dispatcher = IDepositLockDispatcher { contract_address: lock };

    deposit(token, lock, 1000); // at T0
    start_cheat_block_timestamp_global(T0 + 300 * DAY);
    deposit(token, lock, 500); // 300 days later

    // First deposit matures; second must not.
    start_cheat_block_timestamp_global(T0 + ONE_YEAR);
    assert!(dispatcher.releasable() == 1000, "only the first deposit matures");
    dispatcher.release(10);

    let erc20 = IERC20Dispatcher { contract_address: token };
    assert!(erc20.balance_of(TREASURY()) == 1000, "only the first is paid out");
    assert!(dispatcher.locked_total() == 500, "the later deposit stays locked");

    // Second matures a year after ITS arrival, not after the first's.
    start_cheat_block_timestamp_global(T0 + 300 * DAY + ONE_YEAR);
    assert!(dispatcher.releasable() == 500, "second deposit matures on its own term");
    dispatcher.release(10);
    assert!(erc20.balance_of(TREASURY()) == 1500, "both eventually released");
    assert!(erc20.balance_of(lock) == 0, "lock holds nothing");
}

/// A deposit arriving long after the first has matured is still locked a full
/// year — the case where a single-cliff schedule locks nothing at all.
#[test]
fn test_deposit_after_earlier_maturity_is_still_locked() {
    let (token, lock) = setup();
    let dispatcher = IDepositLockDispatcher { contract_address: lock };
    deposit(token, lock, 1000);

    start_cheat_block_timestamp_global(T0 + ONE_YEAR + 10 * DAY);
    dispatcher.release(10);
    deposit(token, lock, 777);

    assert!(dispatcher.releasable() == 0, "a fresh deposit is not instantly releasable");
    start_cheat_block_timestamp_global(T0 + 2 * ONE_YEAR + 11 * DAY);
    assert!(dispatcher.releasable() == 777, "it matures a year after ITS arrival");
}

// ==============================================================================
// CRANK SEMANTICS
// ==============================================================================

/// Tokens that arrive but are never stamped cannot be released. Forgetting to
/// crank delays a release; it never causes an early one.
#[test]
fn test_unstamped_tokens_are_not_releasable() {
    let (token, lock) = setup();
    let dispatcher = IDepositLockDispatcher { contract_address: lock };
    IMockERC20Dispatcher { contract_address: token }.mint(lock, 1000);

    assert!(dispatcher.pending() == 1000, "arrived but unstamped");
    assert!(dispatcher.locked_total() == 0, "not yet recorded");

    start_cheat_block_timestamp_global(T0 + 5 * ONE_YEAR);
    assert!(dispatcher.releasable() == 0, "unstamped tokens never mature");

    // Cranking now starts the term from here, not from arrival.
    dispatcher.lock();
    assert!(dispatcher.pending() == 0, "stamped");
    assert!(dispatcher.releasable() == 0, "term starts at the crank");
    start_cheat_block_timestamp_global(T0 + 6 * ONE_YEAR + DAY);
    assert!(dispatcher.releasable() == 1000, "matures a year after the crank");
}

#[test]
fn test_lock_is_permissionless() {
    let (token, lock) = setup();
    IMockERC20Dispatcher { contract_address: token }.mint(lock, 1000);
    start_cheat_caller_address(lock, NOT_OWNER());
    IDepositLockDispatcher { contract_address: lock }.lock();
    stop_cheat_caller_address(lock);
    assert!(
        IDepositLockDispatcher { contract_address: lock }.locked_total() == 1000,
        "anyone may stamp deposits",
    );
}

#[test]
#[should_panic(expected: 'Nothing to lock')]
fn test_lock_with_nothing_pending_reverts() {
    let (_, lock) = setup();
    IDepositLockDispatcher { contract_address: lock }.lock();
}

// ==============================================================================
// DAY BUCKETING
// ==============================================================================

/// Deposits sharing a day merge into one record, so dust spam cannot inflate
/// the queue and make `release` progressively more expensive.
#[test]
fn test_same_day_deposits_merge_into_one_record() {
    let (token, lock) = setup();
    let dispatcher = IDepositLockDispatcher { contract_address: lock };

    deposit(token, lock, 100);
    deposit(token, lock, 200);
    deposit(token, lock, 300);

    let (head, tail) = dispatcher.queue_range();
    assert!(tail - head == 1, "three same-day deposits should be one record");
    let (_, amount) = dispatcher.unlock_day_at(head);
    assert!(amount == 600, "amounts accumulate in the bucket");
}

#[test]
fn test_deposits_on_different_days_are_separate_records() {
    let (token, lock) = setup();
    let dispatcher = IDepositLockDispatcher { contract_address: lock };

    deposit(token, lock, 100);
    start_cheat_block_timestamp_global(T0 + DAY);
    deposit(token, lock, 200);

    let (head, tail) = dispatcher.queue_range();
    assert!(tail - head == 2, "different days are distinct records");
}

/// `release` processes at most `limit` records, so a long backlog is drained
/// over several calls rather than reverting on gas.
#[test]
fn test_release_respects_the_limit() {
    let (token, lock) = setup();
    let dispatcher = IDepositLockDispatcher { contract_address: lock };

    deposit(token, lock, 100);
    start_cheat_block_timestamp_global(T0 + DAY);
    deposit(token, lock, 200);
    start_cheat_block_timestamp_global(T0 + 2 * DAY);
    deposit(token, lock, 300);

    start_cheat_block_timestamp_global(T0 + ONE_YEAR + 5 * DAY);
    let first = dispatcher.release(2);
    assert!(first == 300, "only two records processed");
    let second = dispatcher.release(10);
    assert!(second == 300, "the remainder drains on the next call");
    assert!(
        IERC20Dispatcher { contract_address: token }.balance_of(TREASURY()) == 600,
        "everything eventually released",
    );
}

// ==============================================================================
// ACCESS
// ==============================================================================

#[test]
fn test_beneficiary_can_be_changed_but_not_the_term() {
    let (token, lock) = setup();
    let dispatcher = IDepositLockDispatcher { contract_address: lock };
    let new_treasury: ContractAddress = 'TREASURY_V2'.try_into().unwrap();
    deposit(token, lock, 1000);

    start_cheat_caller_address(lock, OWNER());
    IDepositLockAdminDispatcher { contract_address: lock }.set_beneficiary(new_treasury);
    stop_cheat_caller_address(lock);

    // Redirecting does not accelerate maturity.
    assert!(dispatcher.releasable() == 0, "changing beneficiary must not unlock early");
    assert!(dispatcher.lock_duration() == ONE_YEAR, "term is fixed");

    start_cheat_block_timestamp_global(T0 + ONE_YEAR);
    dispatcher.release(10);
    let erc20 = IERC20Dispatcher { contract_address: token };
    assert!(erc20.balance_of(new_treasury) == 1000, "paid to the new beneficiary");
    assert!(erc20.balance_of(TREASURY()) == 0, "old beneficiary receives nothing");
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_beneficiary_rejects_non_owner() {
    let (_, lock) = setup();
    start_cheat_caller_address(lock, NOT_OWNER());
    IDepositLockAdminDispatcher { contract_address: lock }.set_beneficiary(NOT_OWNER());
}

#[test]
fn test_constructor_records_configuration() {
    let (token, lock) = setup();
    let dispatcher = IDepositLockDispatcher { contract_address: lock };
    assert!(dispatcher.token() == token, "token");
    assert!(dispatcher.beneficiary() == TREASURY(), "beneficiary");
    assert!(dispatcher.lock_duration() == ONE_YEAR, "duration");
    assert!(IOwnableDispatcher { contract_address: lock }.owner() == OWNER(), "owner");
}

// ==============================================================================
// SCALE / GAS PROFILE
// ==============================================================================
// The operational question: `lock` is permissionless and would plausibly be
// cranked once per protocol-fee claim. At 1000 tournaments that is 1000 calls.
// These measure what that actually costs and what it leaves behind.

/// Many crank calls in ONE day must leave exactly ONE record.
///
/// This is the property that makes per-claim cranking safe. Day bucketing
/// merges same-day deposits, so the queue grows at most once per DAY, not once
/// per call — and `release` walks the queue, so an unbounded queue is what
/// would eventually make releasing expensive.
///
/// Capped at 400 iterations, not 1000, for a reason worth recording: Starknet
/// allows at most 1000 events PER TRANSACTION, and each `lock` emits one. A
/// test loop runs inside a single transaction, so 1000 locks aborts with
/// "Exceeded the maximum number of events". In production every `lock` is its
/// own transaction and emits one event, so the ceiling is unreachable — but a
/// MULTICALL that batches more than ~1000 locks would hit it. Nothing here
/// does that; noting it so nobody builds one.
#[test]
fn test_many_same_day_locks_leave_one_record() {
    let (token, lock) = setup();
    let l = IDepositLockDispatcher { contract_address: lock };

    let mut i: u32 = 0;
    while i < 400 {
        IMockERC20Dispatcher { contract_address: token }.mint(lock, 1_000_000);
        l.lock();
        i += 1;
    }

    assert!(l.locked_total() == 400_000_000, "every deposit recorded");

    // One record: releasing with limit 1 must take the WHOLE amount.
    start_cheat_block_timestamp_global(T0 + ONE_YEAR + DAY);
    let released = l.release(1);
    assert!(released == 400_000_000, "400 deposits released in a single step");
    assert!(l.locked_total() == 0, "nothing left behind");
}

/// A full year of DAILY cranking, then a full drain.
///
/// This is the realistic worst case: one distinct bucket per day for the whole
/// term. It pins the queue length at 366, not 1000-plus, and shows the drain
/// completes in one call at that size.
#[test]
fn test_a_full_year_of_daily_locks_drains_in_one_release() {
    let (token, lock) = setup();
    let l = IDepositLockDispatcher { contract_address: lock };

    let mut d: u64 = 0;
    while d < 365 {
        start_cheat_block_timestamp_global(T0 + d * DAY);
        IMockERC20Dispatcher { contract_address: token }.mint(lock, 1_000);
        l.lock();
        d += 1;
    }
    assert!(l.locked_total() == 365_000, "a year of daily deposits");

    // Well past the last deposit's maturity: everything is due at once.
    start_cheat_block_timestamp_global(T0 + (365 + 366) * DAY);
    let released = l.release(400);
    assert!(released == 365_000, "a year of buckets drains in one call");
    assert!(l.locked_total() == 0, "queue fully drained");
}

/// Dust cannot inflate the queue.
///
/// `lock` is permissionless and anyone can push 1 wei in and crank. Without
/// day bucketing that would append a record per call and make `release`
/// progressively more expensive — a griefing vector against the beneficiary.
#[test]
fn test_dust_spam_cannot_inflate_the_queue() {
    let (token, lock) = setup();
    let l = IDepositLockDispatcher { contract_address: lock };

    deposit(token, lock, 1_000_000);

    // 300, not more: each mint AND each lock emits an event, and Starknet
    // caps a transaction at 1000. See the note on the same-day test.
    let mut i: u32 = 0;
    while i < 300 {
        IMockERC20Dispatcher { contract_address: token }.mint(lock, 1);
        l.lock();
        i += 1;
    }

    start_cheat_block_timestamp_global(T0 + ONE_YEAR + DAY);
    // Still one bucket, so limit 1 drains everything including the dust.
    let released = l.release(1);
    assert!(released == 1_000_300, "dust merged into the same day's bucket");
    assert!(l.locked_total() == 0, "no residue");
}

