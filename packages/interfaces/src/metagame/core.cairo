// Core metagame interface
use starknet::ContractAddress;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - context_address()->ContractAddress
///
/// `default_token_address` was removed: every game brings its own token, so a
/// metagame-wide default token is a registry-era concept with nothing to point
/// at. The id changed accordingly — consumers probing the old
/// `0x7997c74299c045696726f0f7f0165f85817acbb0964e23ff77e11e34eff6f2` must
/// update.
pub const IMETAGAME_ID: felt252 = 0x1363c8de5144122290d663c4c7a10d09518fbe76475610a7027ea4770b9c179;

#[starknet::interface]
pub trait IMetagame<TContractState> {
    fn context_address(self: @TContractState) -> ContractAddress;
}
