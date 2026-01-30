// Token renderer extension interface

pub const IMINIGAME_TOKEN_RENDERER_ID: felt252 =
    0x8f54cc9eac088fdd5b0e849eef269b521a434b60ff8f2d8ae60cac2fbcc33e;

#[starknet::interface]
pub trait IMinigameTokenRenderer<TState> {
    fn get_renderer(self: @TState, token_id: felt252) -> starknet::ContractAddress;
    fn has_custom_renderer(self: @TState, token_id: felt252) -> bool;
    fn reset_token_renderer(ref self: TState, token_id: felt252);

    // Batch operations
    fn reset_token_renderer_batch(ref self: TState, token_ids: Span<felt252>);
    fn get_renderer_batch(
        self: @TState, token_ids: Span<felt252>,
    ) -> Array<starknet::ContractAddress>;
}
