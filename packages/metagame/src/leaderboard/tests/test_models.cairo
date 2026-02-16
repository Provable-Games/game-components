// ==============================================================================
// LEADERBOARD MODELS TESTS
// ==============================================================================
// Tests for the Leaderboard struct in models.cairo
// Covers struct creation, field access, and Serde (serialization/deserialization)

use game_components_metagame::leaderboard::models::Leaderboard;
use game_components_testing::constants::MAX_U64;

// ==============================================================================
// STRUCT CREATION TESTS
// ==============================================================================

#[test]
fn test_leaderboard_creation_empty_token_ids() {
    let leaderboard = Leaderboard { tournament_id: 1, token_ids: array![] };

    assert!(leaderboard.tournament_id == 1, "Tournament ID should be 1");
    assert!(leaderboard.token_ids.len() == 0, "Token IDs should be empty");
}

#[test]
fn test_leaderboard_creation_with_single_token() {
    let leaderboard = Leaderboard { tournament_id: 42, token_ids: array![100] };

    assert!(leaderboard.tournament_id == 42, "Tournament ID should be 42");
    assert!(leaderboard.token_ids.len() == 1, "Token IDs should have 1 element");
    assert!(*leaderboard.token_ids.at(0) == 100, "First token should be 100");
}

#[test]
fn test_leaderboard_creation_with_multiple_tokens() {
    let leaderboard = Leaderboard { tournament_id: 1, token_ids: array![1, 2, 3, 4, 5] };

    assert!(leaderboard.tournament_id == 1, "Tournament ID should be 1");
    assert!(leaderboard.token_ids.len() == 5, "Token IDs should have 5 elements");
    assert!(*leaderboard.token_ids.at(0) == 1, "First token should be 1");
    assert!(*leaderboard.token_ids.at(4) == 5, "Last token should be 5");
}

#[test]
fn test_leaderboard_creation_with_zero_tournament_id() {
    let leaderboard = Leaderboard { tournament_id: 0, token_ids: array![1] };

    assert!(leaderboard.tournament_id == 0, "Tournament ID should be 0");
}

// ==============================================================================
// FIELD ACCESS TESTS
// ==============================================================================

#[test]
fn test_leaderboard_tournament_id_access_max() {
    let leaderboard = Leaderboard { tournament_id: MAX_U64, token_ids: array![] };

    assert!(leaderboard.tournament_id == MAX_U64, "Tournament ID should be MAX_U64");
}

#[test]
fn test_leaderboard_token_ids_access() {
    let leaderboard = Leaderboard { tournament_id: 1, token_ids: array![10, 20, 30] };

    assert!(leaderboard.token_ids.len() == 3, "Should have 3 tokens");
    assert!(*leaderboard.token_ids.at(0) == 10, "First should be 10");
    assert!(*leaderboard.token_ids.at(1) == 20, "Second should be 20");
    assert!(*leaderboard.token_ids.at(2) == 30, "Third should be 30");
}

#[test]
fn test_leaderboard_token_ids_max_values() {
    let max_id: felt252 = MAX_U64.into();
    let max_id_minus_1: felt252 = (MAX_U64 - 1).into();
    let leaderboard = Leaderboard { tournament_id: 1, token_ids: array![max_id, max_id_minus_1] };

    assert!(*leaderboard.token_ids.at(0) == max_id, "First should be MAX_U64");
    assert!(*leaderboard.token_ids.at(1) == max_id_minus_1, "Second should be MAX_U64 - 1");
}

// ==============================================================================
// SERIALIZATION TESTS (Serde)
// ==============================================================================

#[test]
fn test_leaderboard_serialize_empty() {
    let leaderboard = Leaderboard { tournament_id: 1, token_ids: array![] };

    let mut output = array![];
    leaderboard.serialize(ref output);

    // Should serialize: tournament_id (2 felt252 for u64) + array length (1 felt252) = 3 elements
    // min
    assert!(output.len() >= 2, "Should have at least tournament_id and array length");
}

#[test]
fn test_leaderboard_serialize_with_tokens() {
    let leaderboard = Leaderboard { tournament_id: 5, token_ids: array![1, 2, 3] };

    let mut output = array![];
    leaderboard.serialize(ref output);

    // Should contain tournament_id, array length, and token values
    assert!(output.len() > 1, "Should have serialized data");
}

#[test]
fn test_leaderboard_serialize_max_values() {
    let max_id: felt252 = MAX_U64.into();
    let leaderboard = Leaderboard { tournament_id: MAX_U64, token_ids: array![max_id] };

    let mut output = array![];
    leaderboard.serialize(ref output);

    // Serialization should not panic with max values
    assert!(output.len() > 0, "Should serialize without panic");
}

// ==============================================================================
// DESERIALIZATION TESTS (Serde)
// ==============================================================================

#[test]
fn test_leaderboard_deserialize_empty() {
    let original = Leaderboard { tournament_id: 1, token_ids: array![] };

    let mut output = array![];
    original.serialize(ref output);

    let mut span = output.span();
    let deserialized: Leaderboard = Serde::deserialize(ref span).unwrap();

    assert!(deserialized.tournament_id == 1, "Tournament ID should match");
    assert!(deserialized.token_ids.len() == 0, "Token IDs should be empty");
}

#[test]
fn test_leaderboard_deserialize_with_tokens() {
    let original = Leaderboard { tournament_id: 42, token_ids: array![10, 20, 30] };

    let mut output = array![];
    original.serialize(ref output);

    let mut span = output.span();
    let deserialized: Leaderboard = Serde::deserialize(ref span).unwrap();

    assert!(deserialized.tournament_id == 42, "Tournament ID should match");
    assert!(deserialized.token_ids.len() == 3, "Should have 3 tokens");
    assert!(*deserialized.token_ids.at(0) == 10, "First should be 10");
    assert!(*deserialized.token_ids.at(1) == 20, "Second should be 20");
    assert!(*deserialized.token_ids.at(2) == 30, "Third should be 30");
}

#[test]
fn test_leaderboard_roundtrip_serialization() {
    // Test with various configurations
    let max_id: felt252 = MAX_U64.into();
    let configs: Array<Leaderboard> = array![
        Leaderboard { tournament_id: 0, token_ids: array![] },
        Leaderboard { tournament_id: 1, token_ids: array![1] },
        Leaderboard { tournament_id: 100, token_ids: array![1, 2, 3, 4, 5] },
        Leaderboard { tournament_id: MAX_U64, token_ids: array![max_id] },
    ];

    let mut i = 0_u32;
    loop {
        if i >= configs.len() {
            break;
        }

        let original = configs.at(i);

        let mut output = array![];
        original.serialize(ref output);

        let mut span = output.span();
        let deserialized: Leaderboard = Serde::deserialize(ref span).unwrap();

        assert!(deserialized.tournament_id == *original.tournament_id, "Tournament ID mismatch");
        assert!(
            deserialized.token_ids.len() == original.token_ids.len(), "Token IDs length mismatch",
        );

        // Verify each token
        let mut j = 0_u32;
        loop {
            if j >= original.token_ids.len() {
                break;
            }
            assert!(
                *deserialized.token_ids.at(j) == *original.token_ids.at(j), "Token value mismatch",
            );
            j += 1;
        }

        i += 1;
    }
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer]
fn test_fuzz_leaderboard_creation(tournament_id: u64) {
    // Fuzz test: struct creation never panics with random tournament_id
    let leaderboard = Leaderboard { tournament_id, token_ids: array![] };
    assert!(leaderboard.tournament_id == tournament_id, "Tournament ID should match");
}

#[test]
#[fuzzer]
fn test_fuzz_leaderboard_serialization_roundtrip(tournament_id: u64) {
    // Fuzz test: serialization roundtrip always preserves data
    let original = Leaderboard { tournament_id, token_ids: array![1, 2, 3] };

    let mut output = array![];
    original.serialize(ref output);

    let mut span = output.span();
    let deserialized: Leaderboard = Serde::deserialize(ref span).unwrap();

    assert!(deserialized.tournament_id == tournament_id, "Tournament ID should be preserved");
    assert!(deserialized.token_ids.len() == 3, "Token count should be preserved");
}

// ==============================================================================
// LARGE ARRAY TEST
// ==============================================================================

#[test]
fn test_leaderboard_creation_large_array() {
    // Create a leaderboard with 50 token IDs
    let mut token_ids: Array<felt252> = array![];
    let mut i: u64 = 1;
    loop {
        if i > 50 {
            break;
        }
        token_ids.append(i.into());
        i += 1;
    }

    let leaderboard = Leaderboard { tournament_id: 1, token_ids };

    assert!(leaderboard.token_ids.len() == 50, "Should have 50 tokens");
    assert!(*leaderboard.token_ids.at(0) == 1, "First should be 1");
    assert!(*leaderboard.token_ids.at(49) == 50, "Last should be 50");
}
