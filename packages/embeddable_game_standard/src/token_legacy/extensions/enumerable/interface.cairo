use starknet::ContractAddress;

/// EFS: token_of_owner_by_index(ContractAddress,(u128,u128))->(u128,u128)
pub const IENUMERABLE_OWNER_ID: felt252 =
    0x312c74a3a4f7aaf9aa3e80ddea171f958139ef0c3dbea524e0763682b7d57dd;

#[starknet::interface]
pub trait IEnumerableOwner<TState> {
    fn token_of_owner_by_index(self: @TState, owner: ContractAddress, index: u256) -> u256;
}
