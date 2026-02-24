/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - get_renderer(u64)->ContractAddress
/// - has_custom_renderer(u64)->E((),())
/// - reset_token_renderer(u64)
pub const IMINIGAME_TOKEN_RENDERER_ID: felt252 =
    0x2bc00de28cb2b5453b10d164d36b0a0d95bdd318b822cea5d64ddbeec72c3e4;

#[starknet::interface]
pub trait IMinigameTokenRenderer<TState> {
    fn get_renderer(self: @TState, token_id: u64) -> starknet::ContractAddress;
    fn has_custom_renderer(self: @TState, token_id: u64) -> bool;
    fn reset_token_renderer(ref self: TState, token_id: u64);
}
