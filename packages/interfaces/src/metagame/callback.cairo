// ==============================================================================
// METAGAME CALLBACK INTERFACE
// ==============================================================================
// Interface for metagame contracts to receive automatic callbacks from token
// contracts when game state changes (score updates, game over, objectives
// completed). This enables tournament score aggregation without manual sync.

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - on_game_action((u128,u128),u64)
/// - on_game_over((u128,u128),u64)
/// - on_objective_complete((u128,u128))
pub const IMETAGAME_CALLBACK_ID: felt252 =
    0x3b4312c1422de8c35936cc79948381ab8ef9fd083d8c8e20317164690aa1600;

/// Interface for metagame contracts to receive callbacks from token contracts
#[starknet::interface]
pub trait IMetagameCallback<TState> {
    /// Called on every update_game() call to notify the metagame of a game action
    /// @param token_id The token ID (packed u256)
    /// @param score The current score value
    fn on_game_action(ref self: TState, token_id: u256, score: u64);

    /// Called when a game ends (game_over transitions to true)
    /// @param token_id The token ID (packed u256)
    /// @param final_score The final score when game ended
    fn on_game_over(ref self: TState, token_id: u256, final_score: u64);

    /// Called when the objective is completed
    /// @param token_id The token ID (packed u256)
    fn on_objective_complete(ref self: TState, token_id: u256);
}
