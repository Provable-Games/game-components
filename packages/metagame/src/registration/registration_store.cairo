// SPDX-License-Identifier: BUSL-1.1

use game_components_interfaces::registration::Registration;
use game_components_metagame::registration::registration::registration::RegistrationValidationImpl;
use game_components_metagame::registration::store::Store;
use game_components_metagame::registration::structs::{
    TokenState, TokenStateStorePacking, unpack_token_context_id, unpack_token_has_submitted,
    unpack_token_is_banned,
};

/// Stored sentinel for the display-only reverse index: this token id has been
/// seen in more than one context and no longer resolves to a single one.
///
/// It must NOT share the encoding of "never seen" (0). Readers can treat the
/// two alike -- both mean "no answer" -- but the WRITER cannot: it has three
/// states to tell apart (never seen / exactly one / ambiguous) and only two
/// encodings to do it with. Collapsing them let a third registration read 0,
/// mistake "ambiguous" for "never seen", and confidently name a context again.
/// Ambiguity is monotonic: once an id is ambiguous it stays ambiguous.
///
/// Mapped back to 0 at the read boundary, so consumers keep the "unknown ==
/// absent" ergonomics without the writer losing the distinction.
/// Stored OUTSIDE the u64 range so no real `context_id` can ever equal it.
///
/// The previous value, `u64::MAX`, is itself a perfectly legal `context_id`
/// and nothing bounds the range, so a context numbered `u64::MAX` stored a
/// value indistinguishable from the sentinel: its single unambiguous
/// registration was reported as "cannot say", and every later `set_entry` for
/// that token read the sentinel and made it permanently sticky-ambiguous.
/// That is precisely the confidently-wrong read the sentinel exists to
/// prevent, reintroduced for one context value.
///
/// Reserving a `context_id` by assertion would have worked, but it makes a
/// legal id illegal and puts a check on the registration path. Widening the
/// stored type instead means the sentinel simply is not expressible as a
/// context, so the collision cannot be written down.
pub const AMBIGUOUS_CONTEXT: felt252 = 0x10000000000000000; // 2^64

/// Store bridge: composes Store<T> reads with pure lib operations
pub trait RegistrationStoreTrait<T> {
    /// Get a full registration entry
    fn get_entry(self: @T, context_id: u64, entry_id: u32) -> Registration;
    /// Write a registration entry to storage
    fn set_entry(ref self: T, registration: @Registration);
    /// Check if an entry exists (token_id at slot != 0)
    fn entry_exists(self: @T, context_id: u64, entry_id: u32) -> bool;
    /// Read context_id for a token IN `context_id` (0 if not registered there).
    /// Returns the context back only when the pair is really registered, so
    /// callers keep the existing `== my_context` idiom.
    fn get_token_context(self: @T, context_id: u64, token_id: felt252) -> u64;
    /// Check if a token has submitted (per-field unpack — single SLOAD)
    fn is_token_submitted(self: @T, context_id: u64, token_id: felt252) -> bool;
    /// Check if a token is banned (per-field unpack — single SLOAD)
    fn is_token_banned(self: @T, context_id: u64, token_id: felt252) -> bool;
    /// Mark a token as having submitted a score (RMW on packed slot)
    fn mark_token_submitted(ref self: T, context_id: u64, token_id: felt252);
    /// Ban a token (RMW on packed slot)
    fn ban_token(ref self: T, context_id: u64, token_id: felt252);
    /// Increment entry count and return new count
    fn increment_entry_count(ref self: T, context_id: u64) -> u32;
    /// Validate registration for score submission
    fn validate_for_submission(self: @T, context_id: u64, entry_id: u32);
}

pub impl RegistrationStoreImpl<T, +Store<T>, +Drop<T>> of RegistrationStoreTrait<T> {
    fn get_entry(self: @T, context_id: u64, entry_id: u32) -> Registration {
        let game_token_id = self.get_token_id(context_id, entry_id);
        let packed = self.get_token_state_raw(context_id, game_token_id);
        let state = TokenStateStorePacking::unpack(packed);
        Registration {
            context_id,
            entry_id,
            game_token_id,
            has_submitted: state.has_submitted,
            is_banned: state.is_banned,
        }
    }

    fn set_entry(ref self: T, registration: @Registration) {
        RegistrationValidationImpl::assert_valid_token_id(*registration.game_token_id);
        // If this slot was previously held by a different token, zero its packed
        // state so the displaced token no longer claims this slot.
        let prev_token = self.get_token_id(*registration.context_id, *registration.entry_id);
        if prev_token != 0 && prev_token != *registration.game_token_id {
            self.set_token_state_raw(*registration.context_id, prev_token, 0);
            // The displaced token no longer has an entry HERE, so the reverse
            // index must stop naming this context -- otherwise it reports a
            // context the token was evicted from, and a later registration
            // elsewhere reads a stale value and poisons a token that was never
            // actually ambiguous. Only clear when it names THIS context: a
            // sentinel stays sticky, and a different context is not ours to
            // erase.
            let displaced: felt252 = self.get_token_last_context(prev_token);
            if displaced == (*registration.context_id).into() {
                self.set_token_last_context(prev_token, 0);
            }
        }
        self
            .set_token_id(
                *registration.context_id, *registration.entry_id, *registration.game_token_id,
            );
        let state = TokenState {
            context_id: *registration.context_id,
            has_submitted: *registration.has_submitted,
            is_banned: *registration.is_banned,
        };
        self
            .set_token_state_raw(
                *registration.context_id,
                *registration.game_token_id,
                TokenStateStorePacking::pack(state),
            );
        // Display-only reverse index. A bare token id cannot identify one
        // context once ids are not globally unique, so rather than silently
        // pick a winner this POISONS the entry to 0 ("unknown") the moment the
        // same id turns up in a second context. Read surfaces then degrade to
        // "I cannot tell you" instead of confidently naming the wrong context.
        // Costs one extra SLOAD on the registration path; the alternative is a
        // read surface that lies.
        let prev_context = Store::get_token_last_context(@self, *registration.game_token_id);
        let this_context: felt252 = (*registration.context_id).into();
        let resolved = if prev_context == AMBIGUOUS_CONTEXT {
            // Sticky: already ambiguous, and nothing can undo that.
            AMBIGUOUS_CONTEXT
        } else if prev_context == 0 || prev_context == this_context {
            this_context
        } else {
            AMBIGUOUS_CONTEXT
        };
        // Re-registering in the same context is the common path, and it leaves
        // this value unchanged -- elide the store rather than pay for it.
        if resolved != prev_context {
            self.set_token_last_context(*registration.game_token_id, resolved);
        }
    }

    fn entry_exists(self: @T, context_id: u64, entry_id: u32) -> bool {
        self.get_token_id(context_id, entry_id) != 0
    }

    fn get_token_context(self: @T, context_id: u64, token_id: felt252) -> u64 {
        unpack_token_context_id(self.get_token_state_raw(context_id, token_id))
    }

    fn is_token_submitted(self: @T, context_id: u64, token_id: felt252) -> bool {
        unpack_token_has_submitted(self.get_token_state_raw(context_id, token_id))
    }

    fn is_token_banned(self: @T, context_id: u64, token_id: felt252) -> bool {
        unpack_token_is_banned(self.get_token_state_raw(context_id, token_id))
    }

    fn mark_token_submitted(ref self: T, context_id: u64, token_id: felt252) {
        let mut state = TokenStateStorePacking::unpack(
            self.get_token_state_raw(context_id, token_id),
        );
        state.has_submitted = true;
        self.set_token_state_raw(context_id, token_id, TokenStateStorePacking::pack(state));
    }

    fn ban_token(ref self: T, context_id: u64, token_id: felt252) {
        let mut state = TokenStateStorePacking::unpack(
            self.get_token_state_raw(context_id, token_id),
        );
        state.is_banned = true;
        self.set_token_state_raw(context_id, token_id, TokenStateStorePacking::pack(state));
    }


    fn increment_entry_count(ref self: T, context_id: u64) -> u32 {
        let current = self.get_entry_count(context_id);
        let new_count = current + 1;
        self.set_entry_count(context_id, new_count);
        new_count
    }

    fn validate_for_submission(self: @T, context_id: u64, entry_id: u32) {
        let entry = self.get_entry(context_id, entry_id);
        RegistrationValidationImpl::assert_valid_for_submission(@entry, context_id);
    }
}
