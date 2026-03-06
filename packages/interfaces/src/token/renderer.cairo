// Token renderer extension interface

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - get_renderer(felt252)->ContractAddress
/// - has_custom_renderer(felt252)->E((),())
/// - reset_token_renderer(felt252)
/// - reset_token_renderer_batch((@Array<felt252>))
/// - get_renderer_batch((@Array<felt252>))->Array<ContractAddress>
pub const IMINIGAME_TOKEN_RENDERER_ID: felt252 =
    0x2899a752da88d6acf4ed54cc644238f3956b4db3c9885d3ad94f6149f0ec465;

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
