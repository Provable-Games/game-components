// Metagame context extension interface
use crate::structs::metagame::GameContextDetails;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - has_context(felt252)->E((),())
pub const IMETAGAME_CONTEXT_ID: felt252 =
    0x1633419b5abcc4c0bbed8bd37a363fbe6de5bd25908761ab6dcda6a9b598ca9;

#[starknet::interface]
pub trait IMetagameContext<TState> {
    fn has_context(self: @TState, token_id: felt252) -> bool;
}

#[starknet::interface]
pub trait IMetagameContextDetails<TState> {
    fn context_details(self: @TState, token_id: felt252) -> GameContextDetails;
}

#[starknet::interface]
pub trait IMetagameContextSVG<TState> {
    fn context_svg(self: @TState, token_id: felt252) -> ByteArray;
}
