use starknet::ContractAddress;

pub const IMETAGAME_ID: felt252 =
    0x0260d5160a283a03815f6c3799926c7bdbec5f22e759f992fb8faf172243ab20;

#[starknet::interface]
pub trait IMetagame<TContractState> {
    fn context_address(self: @TContractState) -> ContractAddress;
    fn default_token_address(self: @TContractState) -> ContractAddress;
}

