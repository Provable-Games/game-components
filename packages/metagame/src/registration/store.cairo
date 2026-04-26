// SPDX-License-Identifier: BUSL-1.1

/// Generic store trait for registration operations.
///
/// `token_state` is a single packed felt252 holding context_id (low 64 bits)
/// plus has_submitted/is_banned flag bits. Bit layout is described in
/// `structs.cairo`'s `TokenStateStorePacking`. Consumers should use the
/// per-field unpack helpers in `structs.cairo` rather than rebuilding the
/// full struct.
pub trait Store<T> {
    fn get_token_id(self: @T, context_id: u64, entry_id: u32) -> felt252;
    fn set_token_id(ref self: T, context_id: u64, entry_id: u32, token_id: felt252);
    fn get_entry_count(self: @T, context_id: u64) -> u32;
    fn set_entry_count(ref self: T, context_id: u64, count: u32);
    /// Packed token state: context_id (low 64 bits) | has_submitted (bit 64) | is_banned (bit 65).
    /// Returns 0 (= not registered, no flags set) for unknown tokens.
    fn get_token_state_raw(self: @T, token_id: felt252) -> felt252;
    fn set_token_state_raw(ref self: T, token_id: felt252, state: felt252);
}
