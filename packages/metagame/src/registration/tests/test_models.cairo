use crate::registration::structs::RegistrationEntryData;

// ============================================================================
// RegistrationEntryData basic construction tests
// ============================================================================

#[test]
fn test_entry_data_default_values() {
    let data = RegistrationEntryData { game_token_id: 0, has_submitted: false, is_banned: false };
    assert!(data.game_token_id == 0, "game_token_id should be 0");
    assert!(!data.has_submitted, "has_submitted should be false");
    assert!(!data.is_banned, "is_banned should be false");
}

#[test]
fn test_entry_data_with_token() {
    let data = RegistrationEntryData {
        game_token_id: 0x1234ABCD, has_submitted: false, is_banned: false,
    };
    assert!(data.game_token_id == 0x1234ABCD, "game_token_id mismatch");
}

#[test]
fn test_entry_data_with_flags() {
    let data = RegistrationEntryData { game_token_id: 0xFF, has_submitted: true, is_banned: true };
    assert!(data.game_token_id == 0xFF, "game_token_id mismatch");
    assert!(data.has_submitted, "has_submitted should be true");
    assert!(data.is_banned, "is_banned should be true");
}

#[test]
fn test_entry_data_flags_independent() {
    let submitted_only = RegistrationEntryData {
        game_token_id: 0x1, has_submitted: true, is_banned: false,
    };
    let banned_only = RegistrationEntryData {
        game_token_id: 0x1, has_submitted: false, is_banned: true,
    };

    assert!(submitted_only.has_submitted, "should be submitted");
    assert!(!submitted_only.is_banned, "should not be banned");

    assert!(!banned_only.has_submitted, "should not be submitted");
    assert!(banned_only.is_banned, "should be banned");
}

#[test]
fn test_entry_data_large_token_id() {
    // felt252 can hold large values
    let data = RegistrationEntryData {
        game_token_id: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, has_submitted: false, is_banned: false,
    };
    assert!(
        data.game_token_id == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, "large game_token_id mismatch",
    );
}
