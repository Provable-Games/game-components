// Deposit-lock interface. `IDepositLock` is permissionless (lock/release can
// only make funds more restricted); `IDepositLockAdmin` holds the one
// owner-gated write, protected by the embedding contract.
use starknet::ContractAddress;

#[starknet::interface]
pub trait IDepositLock<TState> {
    /// Stamp everything arrived since the last call with a fresh term.
    fn lock(ref self: TState) -> u256;

    /// Release matured deposits to the beneficiary, oldest first, up to `limit` buckets.
    fn release(ref self: TState, limit: u32) -> u256;

    /// Arrived but not yet stamped by `lock`.
    fn pending(self: @TState) -> u256;

    fn releasable(self: @TState) -> u256;

    fn locked_total(self: @TState) -> u256;

    /// `(unlock_day, amount)` at a queue index.
    fn unlock_day_at(self: @TState, index: u32) -> (u64, u256);

    /// `(head, tail)`; entries in `[head, tail)` are live.
    fn queue_range(self: @TState) -> (u32, u32);

    fn token(self: @TState) -> ContractAddress;
    fn beneficiary(self: @TState) -> ContractAddress;
    fn lock_duration(self: @TState) -> u64;
}

#[starknet::interface]
pub trait IDepositLockAdmin<TState> {
    /// Redirect future funds. Owner-gated by the embedder; cannot shorten a lock.
    fn set_beneficiary(ref self: TState, beneficiary: ContractAddress);
}
