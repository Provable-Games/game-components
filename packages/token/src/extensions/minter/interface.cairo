pub const IMINIGAME_TOKEN_MINTER_ID: felt252 =
    0x021482384f4a706dbe387c9fc12175768c24904c5f5f258f1189a6d545eb3104;

#[starknet::interface]
pub trait IMinigameTokenMinter<TState> {
    fn get_minter_address(self: @TState, minter_id: u64) -> starknet::ContractAddress;
    fn get_minter_id(self: @TState, minter_address: starknet::ContractAddress) -> u64;
    fn minter_exists(self: @TState, minter_address: starknet::ContractAddress) -> bool;
    fn total_minters(self: @TState) -> u64;
}
