// Pure Cairo library for token state management
// Contains logic for token playability, metadata creation, and state transitions

use crate::structs::{TokenMetadata, Lifecycle};
use crate::libs::LifecycleTrait;

/// Checks if a token is playable based on its lifecycle, game state, and objectives
///
/// # Arguments
/// * `metadata` - The token metadata to check
/// * `current_time` - The current block timestamp
///
/// # Returns
/// * `bool` - True if the token is playable, false otherwise
#[inline(always)]
pub fn is_token_playable(metadata: @TokenMetadata, current_time: u64) -> bool {
    // Can't play if game is over
    if *metadata.game_over {
        return false;
    }

    // Can't play if all objectives are completed
    if *metadata.completed_all_objectives {
        return false;
    }

    // Check lifecycle constraints
    metadata.lifecycle.is_playable(current_time)
}

/// Ensures game_over state only transitions from false to true
///
/// # Arguments
/// * `old_state` - The previous game_over state
/// * `new_state` - The new game_over state
///
/// # Returns
/// * `bool` - The validated new state
#[inline(always)]
pub fn ensure_game_over_transition(old_state: bool, new_state: bool) -> bool {
    // If already true, must stay true
    if old_state {
        true
    } else {
        new_state
    }
}

/// Ensures completed_all_objectives state only transitions from false to true
///
/// # Arguments
/// * `old_state` - The previous completed_all_objectives state
/// * `new_state` - The new completed_all_objectives state
///
/// # Returns
/// * `bool` - The validated new state
#[inline(always)]
pub fn ensure_objectives_completion_transition(old_state: bool, new_state: bool) -> bool {
    // If already true, must stay true
    if old_state {
        true
    } else {
        new_state
    }
}

/// Creates metadata for a blank token (no game)
///
/// # Arguments
/// * `lifecycle` - The token lifecycle
/// * `minted_by` - The minter ID
/// * `soulbound` - Whether the token is soulbound
/// * `current_time` - The current block timestamp
///
/// # Returns
/// * `TokenMetadata` - The created metadata
#[inline(always)]
pub fn create_blank_token_metadata(
    lifecycle: Lifecycle, minted_by: u64, soulbound: bool, current_time: u64,
) -> TokenMetadata {
    TokenMetadata {
        // Game info
        game_id: 0,
        game_over: false,
        settings_id: 0,
        // Objectives
        objectives_count: 0,
        completed_all_objectives: false,
        // Metadata
        lifecycle,
        soulbound,
        minted_by,
        has_context: false,
        // State
        minted_at: current_time,
    }
}

/// Creates metadata for a game token
///
/// # Arguments
/// * `game_id` - The game ID (0 for single game, >0 for registry game)
/// * `settings_id` - The settings ID
/// * `lifecycle` - The token lifecycle
/// * `minted_by` - The minter ID
/// * `soulbound` - Whether the token is soulbound
/// * `has_context` - Whether the token has context
/// * `objectives_count` - The number of objectives
/// * `current_time` - The current block timestamp
///
/// # Returns
/// * `TokenMetadata` - The created metadata
#[inline(always)]
pub fn create_game_token_metadata(
    game_id: u64,
    settings_id: u32,
    lifecycle: Lifecycle,
    minted_by: u64,
    soulbound: bool,
    has_context: bool,
    objectives_count: u8,
    current_time: u64,
) -> TokenMetadata {
    TokenMetadata {
        // Game info
        game_id,
        game_over: false,
        settings_id,
        // Objectives
        objectives_count,
        completed_all_objectives: false,
        // Metadata
        lifecycle,
        soulbound,
        minted_by,
        has_context,
        // State
        minted_at: current_time,
    }
}

/// Creates a lifecycle with default values
///
/// # Arguments
/// * `start` - Optional start time
/// * `end` - Optional end time
///
/// # Returns
/// * `Lifecycle` - The created lifecycle
#[inline(always)]
pub fn create_lifecycle_with_defaults(start: Option<u64>, end: Option<u64>) -> Lifecycle {
    Lifecycle { start: start.unwrap_or(0), end: end.unwrap_or(0) }
}

/// Checks if a game ID represents a multi-game token
///
/// # Arguments
/// * `game_id` - The game ID to check
///
/// # Returns
/// * `bool` - True if multi-game (game_id != 0), false otherwise
#[inline(always)]
pub fn is_multi_game_token(game_id: u64) -> bool {
    game_id != 0
}

/// Checks if a game ID represents a single-game token
///
/// # Arguments
/// * `game_id` - The game ID to check
///
/// # Returns
/// * `bool` - True if single-game (game_id == 0), false otherwise
#[inline(always)]
pub fn is_single_game_token(game_id: u64) -> bool {
    game_id == 0
}
