use crate::extensions::context::structs::GameContextDetails;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - has_context(u64)->E((),())
pub const IMETAGAME_CONTEXT_ID: felt252 =
    0x3b6bca2fc494503dcfa4284efdff9553578f0144d6f8bc4495ea95b0b4b0f57;

#[starknet::interface]
pub trait IMetagameContext<TState> {
    fn has_context(self: @TState, token_id: u64) -> bool;
}

#[starknet::interface]
pub trait IMetagameContextDetails<TState> {
    fn context_details(self: @TState, token_id: u64) -> GameContextDetails;
}

#[starknet::interface]
pub trait IMetagameContextSVG<TState> {
    fn context_svg(self: @TState, token_id: u64) -> ByteArray;
}
