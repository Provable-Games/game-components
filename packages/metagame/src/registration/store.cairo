// SPDX-License-Identifier: BUSL-1.1

/// Generic store trait for registration operations.
///
/// `token_state` is a single packed felt252 holding context_id (low 64 bits)
/// plus has_submitted/is_banned flag bits. Bit layout is described in
/// `structs.cairo`'s `TokenStateStorePacking`. Consumers should use the
/// per-field unpack helpers in `structs.cairo` rather than rebuilding the
/// full struct.
///
/// # Why token state is keyed by (context_id, token_id)
///
/// A game token id is only unique WITHIN the contract that minted it --
/// identity is `(game, id)`, never `id` alone. Keying this state on `token_id`
/// was safe only while every entry came from one shared token contract.
///
/// Ids are packed felts rather than counters, so two games do not collide by
/// default; a collision needs two ids that pack byte-identically. That is
/// reachable accidentally (one multicall minting into two games with the same
/// params and salt in the same block) and, more importantly, deliberately: an
/// attacker controls their own game contract and every packed field except
/// `minted_at`, a block timestamp they need only match to the second.
///
/// The consequence was severe because `set_entry` wrote the slot
/// unconditionally: the later registration overwrote the earlier token's
/// context and cleared its flags, locking that player out of the context they
/// had registered and paid for. A targeted griefing vector, for the price of
/// one entry on a game the attacker controls.
///
/// Keying on the pair makes the identity honest: `(context, token)` is the
/// entry, and every security-relevant call site already knows its context.
pub trait Store<T> {
    fn get_token_id(self: @T, context_id: u64, entry_id: u32) -> felt252;
    fn set_token_id(ref self: T, context_id: u64, entry_id: u32, token_id: felt252);
    fn get_entry_count(self: @T, context_id: u64) -> u32;
    fn set_entry_count(ref self: T, context_id: u64, count: u32);
    /// Packed token state: context_id (low 64 bits) | has_submitted (bit 64) | is_banned (bit 65).
    /// Returns 0 (= not registered for THIS context, no flags set) for unknown pairs.
    fn get_token_state_raw(self: @T, context_id: u64, token_id: felt252) -> felt252;
    fn set_token_state_raw(ref self: T, context_id: u64, token_id: felt252, state: felt252);
    /// Best-effort reverse index, `token_id -> context_id`. See
    /// `registration_component.cairo` for why this one CANNOT be exact and
    /// must never be used to authorize anything.
    fn get_token_last_context(self: @T, token_id: felt252) -> u64;
    fn set_token_last_context(ref self: T, token_id: felt252, context_id: u64);
}
