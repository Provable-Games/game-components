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

    /// Check if an entry is banned
    fn is_entry_banned(self: @TState, context_id: u64, entry_id: u32) -> bool;

    /// Get entry count for a context
    fn get_entry_count(self: @TState, context_id: u64) -> u32;
}
