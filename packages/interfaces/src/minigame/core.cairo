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
    fn token_name(self: @TState, token_id: felt252) -> ByteArray;
    fn token_description(self: @TState, token_id: felt252) -> ByteArray;
    fn game_details(self: @TState, token_id: felt252) -> Span<GameDetail>;

    // Batch operations
    fn token_name_batch(self: @TState, token_ids: Span<felt252>) -> Array<ByteArray>;
    fn token_description_batch(self: @TState, token_ids: Span<felt252>) -> Array<ByteArray>;
    fn game_details_batch(self: @TState, token_ids: Span<felt252>) -> Array<Span<GameDetail>>;
}

#[starknet::interface]
pub trait IMinigameDetailsSVG<TState> {
    fn game_details_svg(self: @TState, token_id: felt252) -> ByteArray;
}
