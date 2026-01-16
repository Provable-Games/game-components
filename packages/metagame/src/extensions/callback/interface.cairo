// ==============================================================================
// METAGAME CALLBACK INTERFACE
// ==============================================================================
// Interface for metagame contracts to receive automatic callbacks from token
// contracts when game state changes (score updates, game over, objectives
// completed). This enables tournament score aggregation without manual sync.

/// Interface ID for IMetagameCallback (SRC5 compliant)
/// Computed as: H(on_score_update) XOR H(on_game_over) XOR H(on_objectives_completed)
pub const IMETAGAME_CALLBACK_ID: felt252 =
    0x04d4f4758b99dcb4f1e2dc37c3a6e8c7a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6;

/// Interface for metagame contracts to receive callbacks from token contracts
#[starknet::interface]
pub trait IMetagameCallback<TState> {
    /// Called when a token's score is updated
    /// @param token_id The token ID (packed u256)
    /// @param score The new score value
    fn on_score_update(ref self: TState, token_id: u256, score: u32);

    /// Called when a game ends (game_over transitions to true)
    /// @param token_id The token ID (packed u256)
    /// @param final_score The final score when game ended
    fn on_game_over(ref self: TState, token_id: u256, final_score: u32);

    /// Called when all objectives are completed
    /// @param token_id The token ID (packed u256)
    fn on_objectives_completed(ref self: TState, token_id: u256);
}
