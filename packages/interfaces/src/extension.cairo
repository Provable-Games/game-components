use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq)]
pub struct ExtensionConfig {
    pub address: ContractAddress,
    pub config: Span<felt252>,
}
