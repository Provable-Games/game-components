pub const IMINIGAME_TOKEN_RENDERER_ID: felt252 =
    0x8f54cc9eac088fdd5b0e849eef269b521a434b60ff8f2d8ae60cac2fbcc33e;

#[starknet::interface]
pub trait IMinigameTokenRenderer<TState> {
    fn get_renderer(self: @TState, token_id: u64) -> starknet::ContractAddress;
    fn has_custom_renderer(self: @TState, token_id: u64) -> bool;
    fn reset_token_renderer(ref self: TState, token_id: u64);
}
