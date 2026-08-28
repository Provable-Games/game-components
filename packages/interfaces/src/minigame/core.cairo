// Core minigame interfaces
use crate::structs::minigame::GameDetail;

#[starknet::interface]
pub trait IMinigameTokenData<TState> {
    fn score(self: @TState, token_id: felt252) -> u64;
    fn game_over(self: @TState, token_id: felt252) -> bool;

    // Batch operations
    fn score_batch(self: @TState, token_ids: Span<felt252>) -> Array<u64>;
    fn game_over_batch(self: @TState, token_ids: Span<felt252>) -> Array<bool>;
}

#[starknet::interface]
pub trait IMinigameDetails<TState> {
    /// The game's display name. Game-level, NOT per-token: every token of a
    /// game shares it, and implementations that took a `token_id` ignored it.
    fn token_name(self: @TState) -> ByteArray;
    /// The game's description. Game-level, same reasoning as `token_name`.
    fn token_description(self: @TState) -> ByteArray;
    /// Per-token detail rows — the only genuinely token-keyed method here.
    fn game_details(self: @TState, token_id: felt252) -> Span<GameDetail>;
    fn game_details_batch(self: @TState, token_ids: Span<felt252>) -> Array<Span<GameDetail>>;
}

#[starknet::interface]
pub trait IMinigameDetailsSVG<TState> {
    fn game_details_svg(self: @TState, token_id: felt252) -> ByteArray;
}
