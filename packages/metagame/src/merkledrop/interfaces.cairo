use starknet::ContractAddress;

/// Minimal subset of ERC721 used by the merkle drop component. Lets the
/// component verify NFT ownership without pulling in the full
/// `openzeppelin_token` dependency for one method.
#[starknet::interface]
pub trait IERC721Read<T> {
    fn owner_of(self: @T, token_id: u256) -> ContractAddress;
}
