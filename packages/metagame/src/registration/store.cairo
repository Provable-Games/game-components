// SPDX-License-Identifier: BUSL-1.1

/// Generic store trait for registration operations
pub trait Store<T> {
    fn get_token_id(self: @T, context_id: u64, entry_id: u32) -> felt252;
    fn set_token_id(ref self: T, context_id: u64, entry_id: u32, token_id: felt252);
    fn get_flags(self: @T, context_id: u64, entry_id: u32) -> u8;
    fn set_flags(ref self: T, context_id: u64, entry_id: u32, flags: u8);
    fn get_entry_count(self: @T, context_id: u64) -> u32;
    fn set_entry_count(ref self: T, context_id: u64, count: u32);
    /// Reverse index: token_id -> context_id (0 if not registered)
    fn get_token_context(self: @T, token_id: felt252) -> u64;
    fn set_token_context(ref self: T, token_id: felt252, context_id: u64);
    /// Reverse index: token_id -> entry_id (0 if not registered)
    fn get_token_entry_id(self: @T, token_id: felt252) -> u32;
    fn set_token_entry_id(ref self: T, token_id: felt252, entry_id: u32);
}
