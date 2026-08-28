// Core minigame interfaces
use crate::structs::minigame::GameMetadata;

#[starknet::interface]
pub trait IMinigameTokenData<TState> {
    fn score(self: @TState, token_id: felt252) -> u64;
    fn game_over(self: @TState, token_id: felt252) -> bool;

    // Batch operations
    fn score_batch(self: @TState, token_ids: Span<felt252>) -> Array<u64>;
    fn game_over_batch(self: @TState, token_ids: Span<felt252>) -> Array<bool>;
}

/// A game's own identity, for indexers and clients.
///
/// Deliberately NOT derived from a token's rendered URI: reading a game's name
/// should not require minting a token, rendering it, and parsing traits back
/// out of the document. Per-contract and constant, so a consumer reads it once
/// rather than once per token.
#[starknet::interface]
pub trait IMinigameGameMetadata<TState> {
    fn game_metadata(self: @TState) -> GameMetadata;
}
