// Token enumerable extension interface

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - total_supply()->u64
/// - token_by_index(u64)->felt252
/// - token_of_owner_by_index(ContractAddress,u64)->felt252
pub const IMINIGAME_TOKEN_ENUMERABLE_ID: felt252 =
    0x3ed5768cee59a892645d1e04477447f48a4f2695ea421aed135e9eda4309c6a;

#[starknet::interface]
pub trait IMinigameTokenEnumerable<TState> {
    fn total_supply(self: @TState) -> u64;
    fn token_by_index(self: @TState, index: u64) -> felt252;
    fn token_of_owner_by_index(
        self: @TState, owner: starknet::ContractAddress, index: u64,
    ) -> felt252;
}
