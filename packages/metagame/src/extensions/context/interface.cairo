use crate::extensions::context::structs::GameContextDetails;

pub const IMETAGAME_CONTEXT_ID: felt252 =
    0x0c2e78065b81a310a1cb470d14a7b88875542ad05286b3263cf3c254082386e;

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
