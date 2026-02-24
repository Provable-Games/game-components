/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - get_minter_address(u64)->ContractAddress
/// - get_minter_id(ContractAddress)->u64
/// - minter_exists(ContractAddress)->E((),())
/// - total_minters()->u64
pub const IMINIGAME_TOKEN_MINTER_ID: felt252 =
    0x2198424b9ee68499f53f33ad952598acbd6d141af6c6863c9c56b117063acca;

#[starknet::interface]
pub trait IMinigameTokenMinter<TState> {
    fn get_minter_address(self: @TState, minter_id: u64) -> starknet::ContractAddress;
    fn get_minter_id(self: @TState, minter_address: starknet::ContractAddress) -> u64;
    fn minter_exists(self: @TState, minter_address: starknet::ContractAddress) -> bool;
    fn total_minters(self: @TState) -> u64;
}
