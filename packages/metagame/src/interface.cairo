use starknet::ContractAddress;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - context_address()->ContractAddress
/// - default_token_address()->ContractAddress
pub const IMETAGAME_ID: felt252 = 0x7997c74299c045696726f0f7f0165f85817acbb0964e23ff77e11e34eff6f2;

#[starknet::interface]
pub trait IMetagame<TContractState> {
    fn context_address(self: @TContractState) -> ContractAddress;
    fn default_token_address(self: @TContractState) -> ContractAddress;
}

