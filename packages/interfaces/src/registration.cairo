#[derive(Copy, Drop, Serde)]
pub struct Registration {
    pub context_id: u64,
    pub entry_id: u32,
    pub game_token_id: felt252,
    pub has_submitted: bool,
    pub is_banned: bool,
}

#[starknet::interface]
pub trait IRegistration<TState> {
    /// Get entry by context and entry ID
    fn get_entry(self: @TState, context_id: u64, entry_id: u32) -> Registration;

    /// Check if an entry exists at (context_id, entry_id)
    fn entry_exists(self: @TState, context_id: u64, entry_id: u32) -> bool;

    /// Check if a token is banned in a given context.
    ///
    /// Takes `context_id` because a ban is per-context and a token id is only
    /// unique within the game that minted it -- two games both mint id 1.
    fn is_token_banned(self: @TState, context_id: u64, token_id: felt252) -> bool;

    /// Get entry count for a context
    fn get_entry_count(self: @TState, context_id: u64) -> u32;
}
