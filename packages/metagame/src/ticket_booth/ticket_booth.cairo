/// Pure Cairo library for ticket booth operations.
/// These functions operate on inputs only without storage access.
use crate::ticket_booth::structs::{GameExpiration, GoldenPass};

/// Checks if a golden pass is configured (cooldown > 0).
pub fn is_golden_pass_configured(pass: @GoldenPass) -> bool {
    *pass.cooldown > 0_u64
}

/// Checks if a golden pass is usable based on cooldown and expiration.
pub fn is_golden_pass_usable(pass: @GoldenPass, last_used: u64, current_time: u64) -> bool {
    if *pass.cooldown == 0_u64 {
        return false;
    }

    // Check if the pass is expired
    if *pass.pass_expiration > 0_u64 && current_time >= *pass.pass_expiration {
        return false;
    }

    // Check cooldown
    current_time >= last_used + *pass.cooldown
}

/// Calculates ticket expiration by adding duration to current time.
pub fn calculate_ticket_expiration(duration: Option<u64>, current_time: u64) -> Option<u64> {
    match duration {
        Option::Some(d) => Option::Some(current_time + d),
        Option::None => Option::None,
    }
}

/// Calculates golden pass expiration based on GameExpiration variant.
pub fn calculate_golden_pass_expiration(
    game_expiration: @GameExpiration, current_time: u64,
) -> Option<u64> {
    match game_expiration {
        GameExpiration::None => Option::None,
        GameExpiration::Fixed(expiration_time) => Option::Some(*expiration_time),
        GameExpiration::Dynamic(duration) => Option::Some(current_time + *duration),
    }
}
