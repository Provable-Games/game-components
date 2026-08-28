// Core minigame interfaces

#[starknet::interface]
pub trait IMinigameTokenData<TState> {
    fn score(self: @TState, token_id: felt252) -> u64;
    fn game_over(self: @TState, token_id: felt252) -> bool;

    // Batch operations
    fn score_batch(self: @TState, token_ids: Span<felt252>) -> Array<u64>;
    fn game_over_batch(self: @TState, token_ids: Span<felt252>) -> Array<bool>;
}

