// Pure Cairo library for objectives-related logic
// Contains functions for processing objectives and calculating completion

use crate::extensions::objectives::interface::TokenObjective;

/// Counts the number of completed objectives
///
/// # Arguments
/// * `objectives` - Span of token objectives to check
///
/// # Returns
/// * `u32` - Number of completed objectives
#[inline(always)]
pub fn count_completed_objectives(objectives: Span<TokenObjective>) -> u32 {
    let mut count: u32 = 0;
    let mut i: u32 = 0;

    while i < objectives.len() {
        let objective = objectives.at(i);
        if *objective.completed {
            count += 1;
        }
        i += 1;
    };

    count
}

/// Checks if all objectives are completed
///
/// # Arguments
/// * `objectives` - Span of token objectives to check
///
/// # Returns
/// * `bool` - True if all objectives are completed, false otherwise
#[inline(always)]
pub fn are_all_objectives_completed(objectives: Span<TokenObjective>) -> bool {
    // Empty objectives means no objectives to complete
    if objectives.is_empty() {
        return false;
    }

    let mut i: u32 = 0;
    let mut all_completed = true;

    while i < objectives.len() {
        let objective = objectives.at(i);
        if !*objective.completed {
            all_completed = false;
            break;
        }
        i += 1;
    };

    all_completed
}

/// Calculates the completion percentage of objectives
///
/// # Arguments
/// * `completed` - Number of completed objectives
/// * `total` - Total number of objectives
///
/// # Returns
/// * `u8` - Completion percentage (0-100)
#[inline(always)]
pub fn calculate_completion_percentage(completed: u32, total: u32) -> u8 {
    if total == 0 {
        return 0;
    }

    let percentage = (completed * 100) / total;

    // Ensure it doesn't exceed 100
    if percentage > 100 {
        100
    } else {
        percentage.try_into().unwrap_or(100)
    }
}

/// Filters and returns the IDs of completed objectives
///
/// # Arguments
/// * `objectives` - Span of token objectives to filter
///
/// # Returns
/// * `Array<u32>` - Array of completed objective IDs
#[inline(always)]
pub fn filter_completed_objectives(objectives: Span<TokenObjective>) -> Array<u32> {
    let mut completed_ids: Array<u32> = array![];
    let mut i: u32 = 0;

    while i < objectives.len() {
        let objective = objectives.at(i);
        if *objective.completed {
            completed_ids.append(*objective.objective_id);
        }
        i += 1;
    };

    completed_ids
}

/// Gets objective by ID from a span of objectives
///
/// # Arguments
/// * `objectives` - Span of token objectives
/// * `objective_id` - The ID to search for
///
/// # Returns
/// * `Option<TokenObjective>` - The found objective or None
#[inline(always)]
pub fn get_objective_by_id(
    objectives: Span<TokenObjective>, objective_id: u32,
) -> Option<TokenObjective> {
    let mut i: u32 = 0;
    let mut result: Option<TokenObjective> = Option::None;

    while i < objectives.len() {
        let objective = objectives.at(i);
        if *objective.objective_id == objective_id {
            result = Option::Some(*objective);
            break;
        }
        i += 1;
    };

    result
}

/// Checks if a specific objective is completed
///
/// # Arguments
/// * `objectives` - Span of token objectives
/// * `objective_id` - The ID to check
///
/// # Returns
/// * `bool` - True if the objective exists and is completed, false otherwise
#[inline(always)]
pub fn is_objective_completed(objectives: Span<TokenObjective>, objective_id: u32) -> bool {
    match get_objective_by_id(objectives, objective_id) {
        Option::Some(objective) => objective.completed,
        Option::None => false,
    }
}

/// Creates an array of objective IDs from a span of objectives
///
/// # Arguments
/// * `objectives` - Span of token objectives
///
/// # Returns
/// * `Array<u32>` - Array of objective IDs
#[inline(always)]
pub fn extract_objective_ids(objectives: Span<TokenObjective>) -> Array<u32> {
    let mut ids: Array<u32> = array![];
    let mut i: u32 = 0;

    while i < objectives.len() {
        let objective = objectives.at(i);
        ids.append(*objective.objective_id);
        i += 1;
    };

    ids
}
