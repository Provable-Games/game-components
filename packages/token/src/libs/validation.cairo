// Pure Cairo library for validation utilities
// Contains general validation and state transition helpers

/// Validates that a boolean state transition is valid (false -> true only)
///
/// # Arguments
/// * `old_state` - The previous state
/// * `new_state` - The proposed new state
///
/// # Returns
/// * `bool` - True if transition is valid, false otherwise
#[inline(always)]
pub fn is_valid_boolean_transition(old_state: bool, new_state: bool) -> bool {
    // Valid transitions:
    // false -> false (no change)
    // false -> true (progression)
    // true -> true (no change)
    // Invalid: true -> false (regression)
    !old_state || new_state
}

/// Validates that a value is within a range (inclusive)
///
/// # Arguments
/// * `value` - The value to check
/// * `min` - Minimum allowed value (inclusive)
/// * `max` - Maximum allowed value (inclusive)
///
/// # Returns
/// * `bool` - True if value is within range, false otherwise
#[inline(always)]
pub fn is_within_range_u64(value: u64, min: u64, max: u64) -> bool {
    value >= min && value <= max
}

/// Validates that a value is within a range (inclusive) for u32
///
/// # Arguments
/// * `value` - The value to check
/// * `min` - Minimum allowed value (inclusive)
/// * `max` - Maximum allowed value (inclusive)
///
/// # Returns
/// * `bool` - True if value is within range, false otherwise
#[inline(always)]
pub fn is_within_range_u32(value: u32, min: u32, max: u32) -> bool {
    value >= min && value <= max
}

/// Validates that a percentage value is valid (0-100)
///
/// # Arguments
/// * `percentage` - The percentage value to check
///
/// # Returns
/// * `bool` - True if valid percentage, false otherwise
#[inline(always)]
pub fn is_valid_percentage(percentage: u8) -> bool {
    percentage <= 100
}

/// Ensures a value doesn't exceed a maximum
///
/// # Arguments
/// * `value` - The value to cap
/// * `max` - Maximum allowed value
///
/// # Returns
/// * `u64` - The capped value
#[inline(always)]
pub fn cap_value_u64(value: u64, max: u64) -> u64 {
    if value > max {
        max
    } else {
        value
    }
}

/// Ensures a value doesn't exceed a maximum for u32
///
/// # Arguments
/// * `value` - The value to cap
/// * `max` - Maximum allowed value
///
/// # Returns
/// * `u32` - The capped value
#[inline(always)]
pub fn cap_value_u32(value: u32, max: u32) -> u32 {
    if value > max {
        max
    } else {
        value
    }
}

/// Validates that a timestamp represents a future time
///
/// # Arguments
/// * `timestamp` - The timestamp to check
/// * `current_time` - The current time to compare against
///
/// # Returns
/// * `bool` - True if timestamp is in the future, false otherwise
#[inline(always)]
pub fn is_future_timestamp(timestamp: u64, current_time: u64) -> bool {
    timestamp > current_time
}

/// Validates that a timestamp represents a past time
///
/// # Arguments
/// * `timestamp` - The timestamp to check
/// * `current_time` - The current time to compare against
///
/// # Returns
/// * `bool` - True if timestamp is in the past, false otherwise
#[inline(always)]
pub fn is_past_timestamp(timestamp: u64, current_time: u64) -> bool {
    timestamp < current_time && timestamp > 0
}

/// Validates that a span is not empty
///
/// # Arguments
/// * `span` - The span to check
///
/// # Returns
/// * `bool` - True if span has elements, false if empty
#[inline(always)]
pub fn is_non_empty_span<T>(span: Span<T>) -> bool {
    span.len() > 0
}

/// Validates that an array is not empty
///
/// # Arguments
/// * `array` - The array to check
///
/// # Returns
/// * `bool` - True if array has elements, false if empty
#[inline(always)]
pub fn is_non_empty_array<T>(array: @Array<T>) -> bool {
    array.len() > 0
}

/// Validates that a ByteArray is not empty
///
/// # Arguments
/// * `bytes` - The ByteArray to check
///
/// # Returns
/// * `bool` - True if ByteArray has content, false if empty
#[inline(always)]
pub fn is_non_empty_bytearray(bytes: @ByteArray) -> bool {
    bytes.len() > 0
}
