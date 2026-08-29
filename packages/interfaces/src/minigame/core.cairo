// The game's own data.
use crate::structs::minigame::GameMetadata;

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
