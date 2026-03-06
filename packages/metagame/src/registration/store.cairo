// SPDX-License-Identifier: BUSL-1.1

/// Generic store trait for registration operations
pub trait Store<T> {
    fn get_token_id(self: @T, context_id: u64, entry_id: u32) -> felt252;
    fn set_token_id(ref self: T, context_id: u64, entry_id: u32, token_id: felt252);
    fn get_flags(self: @T, context_id: u64, entry_id: u32) -> u8;
    fn set_flags(ref self: T, context_id: u64, entry_id: u32, flags: u8);
    fn get_entry_count(self: @T, context_id: u64) -> u32;
    fn set_entry_count(ref self: T, context_id: u64, count: u32);
}
