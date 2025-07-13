#[starknet::interface]
pub trait IMinigameTokenRenderer<TState> {
    fn get_renderer(self: @TState, token_id: u64) -> starknet::ContractAddress;
    fn has_custom_renderer(self: @TState, token_id: u64) -> bool;
}
