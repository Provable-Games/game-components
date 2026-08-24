// ============================================================================
// STRUCTS COVERAGE TESTS
// ============================================================================
// Tests for StorePacking implementations in structs.cairo
// - LifecycleStorePacking
// - TokenMutableStateStorePacking
// - TokenMetadataStorePacking
// - to_token_metadata helper function

use game_components_interfaces::structs::token::Lifecycle;
use crate::token_legacy::structs::{
    LifecycleStorePacking, PackedTokenId, TokenMutableState, TokenMutableStateStorePacking,
    extract_tx_hash_bits, pack_token_id, to_token_metadata, unpack_end_delay, unpack_game_id,
    unpack_has_context, unpack_metadata, unpack_minted_at, unpack_minted_by, unpack_objective_id,
    unpack_paymaster, unpack_salt, unpack_settings_id, unpack_soulbound, unpack_start_delay,
    unpack_token_id, unpack_tx_hash,
};

// ============================================================================
// LIFECYCLE STOREPACKING TESTS
// ============================================================================

#[test]
fn test_lifecycle_pack_unpack_roundtrip_zeros() {
    let lifecycle = Lifecycle { start: 0, end: 0 };
    let packed = LifecycleStorePacking::pack(lifecycle);
    let unpacked = LifecycleStorePacking::unpack(packed);

    assert!(unpacked.start == 0, "Start should be 0");
    assert!(unpacked.end == 0, "End should be 0");
}

#[test]
fn test_lifecycle_pack_unpack_roundtrip_basic() {
    let lifecycle = Lifecycle { start: 1000, end: 2000 };
    let packed = LifecycleStorePacking::pack(lifecycle);
    let unpacked = LifecycleStorePacking::unpack(packed);

    assert!(unpacked.start == 1000, "Start should be 1000");
    assert!(unpacked.end == 2000, "End should be 2000");
}

#[test]
fn test_lifecycle_pack_unpack_roundtrip_large_values() {
    // Test with large timestamps near the 64-bit boundary
    let start: u64 = 0xFFFFFFFFFFFFFFFF / 2;
    let end: u64 = 0xFFFFFFFFFFFFFFFF;

    let lifecycle = Lifecycle { start, end };
    let packed = LifecycleStorePacking::pack(lifecycle);
    let unpacked = LifecycleStorePacking::unpack(packed);

    assert!(unpacked.start == start, "Start should match large value");
    assert!(unpacked.end == end, "End should match large value");
}

#[test]
fn test_lifecycle_pack_unpack_roundtrip_start_only() {
    let lifecycle = Lifecycle { start: 12345678, end: 0 };
    let packed = LifecycleStorePacking::pack(lifecycle);
    let unpacked = LifecycleStorePacking::unpack(packed);

    assert!(unpacked.start == 12345678, "Start should be preserved");
    assert!(unpacked.end == 0, "End should be 0");
}

#[test]
fn test_lifecycle_pack_unpack_roundtrip_end_only() {
    let lifecycle = Lifecycle { start: 0, end: 87654321 };
    let packed = LifecycleStorePacking::pack(lifecycle);
    let unpacked = LifecycleStorePacking::unpack(packed);

    assert!(unpacked.start == 0, "Start should be 0");
    assert!(unpacked.end == 87654321, "End should be preserved");
}

#[test]
fn test_lifecycle_pack_different_values_produce_different_packed() {
    let lifecycle1 = Lifecycle { start: 100, end: 200 };
    let lifecycle2 = Lifecycle { start: 100, end: 300 };
    let lifecycle3 = Lifecycle { start: 200, end: 200 };

    let packed1 = LifecycleStorePacking::pack(lifecycle1);
    let packed2 = LifecycleStorePacking::pack(lifecycle2);
    let packed3 = LifecycleStorePacking::pack(lifecycle3);

    assert!(packed1 != packed2, "Different end values should produce different packed");
    assert!(packed1 != packed3, "Different start values should produce different packed");
    assert!(packed2 != packed3, "All three should be different");
}

// ============================================================================
// TOKEN MUTABLE STATE STOREPACKING TESTS
// ============================================================================

#[test]
fn test_token_mutable_state_default() {
    let state: TokenMutableState = Default::default();

    assert!(!state.game_over, "Default game_over should be false");
    assert!(!state.completed_objective, "Default completed_objective should be false");
}

#[test]
fn test_token_mutable_state_pack_unpack_both_false() {
    let state = TokenMutableState { game_over: false, completed_objective: false, completed_at: 0 };
    let packed = TokenMutableStateStorePacking::pack(state);
    let unpacked = TokenMutableStateStorePacking::unpack(packed);

    assert!(!unpacked.game_over, "game_over should be false");
    assert!(!unpacked.completed_objective, "completed_objective should be false");
}

#[test]
fn test_token_mutable_state_pack_unpack_both_true() {
    let state = TokenMutableState { game_over: true, completed_objective: true, completed_at: 0 };
    let packed = TokenMutableStateStorePacking::pack(state);
    let unpacked = TokenMutableStateStorePacking::unpack(packed);

    assert!(unpacked.game_over, "game_over should be true");
    assert!(unpacked.completed_objective, "completed_objective should be true");
}

#[test]
fn test_token_mutable_state_pack_unpack_game_over_only() {
    let state = TokenMutableState { game_over: true, completed_objective: false, completed_at: 0 };
    let packed = TokenMutableStateStorePacking::pack(state);
    let unpacked = TokenMutableStateStorePacking::unpack(packed);

    assert!(unpacked.game_over, "game_over should be true");
    assert!(!unpacked.completed_objective, "completed_objective should be false");
}

#[test]
fn test_token_mutable_state_pack_unpack_completed_objective_only() {
    let state = TokenMutableState { game_over: false, completed_objective: true, completed_at: 0 };
    let packed = TokenMutableStateStorePacking::pack(state);
    let unpacked = TokenMutableStateStorePacking::unpack(packed);

    assert!(!unpacked.game_over, "game_over should be false");
    assert!(unpacked.completed_objective, "completed_objective should be true");
}

#[test]
fn test_token_mutable_state_bit_isolation() {
    // Test that game_over and completed_objective bits don't interfere
    let states: Array<(bool, bool)> = array![
        (false, false), (false, true), (true, false), (true, true),
    ];

    let mut i = 0;
    while i < states.len() {
        let (game_over, completed_objective) = *states.at(i);
        let state = TokenMutableState { game_over, completed_objective, completed_at: 0 };
        let packed = TokenMutableStateStorePacking::pack(state);
        let unpacked = TokenMutableStateStorePacking::unpack(packed);

        assert!(unpacked.game_over == game_over, "game_over bit mismatch");
        assert!(
            unpacked.completed_objective == completed_objective, "completed_objective bit mismatch",
        );
        i += 1;
    }
}

// ============================================================================
// PACK_TOKEN_ID / UNPACK_TOKEN_ID TESTS (replaces TokenMetadataStorePacking)
// ============================================================================

#[test]
fn test_pack_unpack_token_id_zeros() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == 0, "game_id should be 0");
    assert!(unpacked.minted_at == 0, "minted_at should be 0");
    assert!(unpacked.settings_id == 0, "settings_id should be 0");
    assert!(unpacked.minted_by == 0, "minted_by should be 0");
    assert!(!unpacked.soulbound, "soulbound should be false");
    assert!(!unpacked.has_context, "has_context should be false");
    assert!(unpacked.objective_id == 0, "objective_id should be 0");
    assert!(unpacked.tx_hash == 0, "tx_hash should be 0");
    assert!(unpacked.salt == 0, "salt should be 0");
    assert!(unpacked.metadata == 0, "metadata should be 0");
}

#[test]
fn test_pack_unpack_token_id_basic_fields() {
    let packed = pack_token_id(42, 100, 5, 1000, 500, 1500, 7, false, false, false, 0, 0, 0);
    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == 42, "game_id should be 42");
    assert!(unpacked.minted_by == 100, "minted_by should be 100");
    assert!(unpacked.settings_id == 5, "settings_id should be 5");
    assert!(unpacked.minted_at == 1000, "minted_at should be 1000");
    assert!(unpacked.start_delay == 500, "start_delay should be 500");
    assert!(unpacked.end_delay == 1500, "end_delay should be 1500");
    assert!(unpacked.objective_id == 7, "objective_id should be 7");
    assert!(!unpacked.soulbound, "soulbound should be false");
    assert!(!unpacked.has_context, "has_context should be false");
}

#[test]
fn test_pack_unpack_token_id_booleans_isolation() {
    // Test each boolean flag in isolation
    let test_cases: Array<(bool, bool, bool)> = array![
        (true, false, false), // soulbound only
        (false, true, false), // has_context only
        (false, false, true) // paymaster only
    ];

    let mut i = 0;
    while i < test_cases.len() {
        let (soulbound, has_context, paymaster) = *test_cases.at(i);

        let packed = pack_token_id(
            1, 1, 1, 100, 10, 20, 1, soulbound, has_context, paymaster, 0, 0, 0,
        );
        let unpacked = unpack_token_id(packed);

        assert!(unpacked.soulbound == soulbound, "soulbound mismatch");
        assert!(unpacked.has_context == has_context, "has_context mismatch");
        assert!(unpacked.paymaster == paymaster, "paymaster mismatch");
        i += 1;
    }
}

#[test]
fn test_pack_unpack_token_id_max_values() {
    // Test with values at the bit boundaries
    let max_game_id: u32 = 0x3FFFFFFF; // 30 bits
    let max_minted_by: u64 = 0xFFFFFFFFFF; // 40 bits
    let max_settings_id: u32 = 0x3FFFFFFF; // 30 bits
    let max_minted_at: u64 = 0x7FFFFFFFF; // 35 bits
    let max_start_delay: u32 = 0x1FFFFFF; // 25 bits
    let max_end_delay: u32 = 0x1FFFFFF; // 25 bits
    let max_objective_id: u32 = 0x3FFFFFFF; // 30 bits
    let max_tx_hash: u16 = 0x3FF; // 10 bits
    let max_salt: u16 = 0x3FF; // 10 bits
    let max_metadata: u16 = 0x1FFF; // 13 bits

    let packed = pack_token_id(
        max_game_id,
        max_minted_by,
        max_settings_id,
        max_minted_at,
        max_start_delay,
        max_end_delay,
        max_objective_id,
        true,
        true,
        true,
        max_tx_hash,
        max_salt,
        max_metadata,
    );
    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == max_game_id, "max game_id mismatch");
    assert!(unpacked.minted_by == max_minted_by, "max minted_by mismatch");
    assert!(unpacked.settings_id == max_settings_id, "max settings_id mismatch");
    assert!(unpacked.minted_at == max_minted_at, "max minted_at mismatch");
    assert!(unpacked.start_delay == max_start_delay, "max start_delay mismatch");
    assert!(unpacked.end_delay == max_end_delay, "max end_delay mismatch");
    assert!(unpacked.objective_id == max_objective_id, "max objective_id mismatch");
    assert!(unpacked.tx_hash == max_tx_hash, "max tx_hash mismatch");
    assert!(unpacked.salt == max_salt, "max salt mismatch");
    assert!(unpacked.metadata == max_metadata, "max metadata mismatch");
}

// ============================================================================
// TO_TOKEN_METADATA HELPER TESTS
// ============================================================================

#[test]
fn test_to_token_metadata_conversion_zeros() {
    let packed_id = PackedTokenId {
        game_id: 0,
        minted_by: 0,
        settings_id: 0,
        minted_at: 0,
        start_delay: 0,
        end_delay: 0,
        objective_id: 0,
        soulbound: false,
        has_context: false,
        paymaster: false,
        tx_hash: 0,
        salt: 0,
        metadata: 0,
    };

    let mutable_state = TokenMutableState {
        game_over: false, completed_objective: false, completed_at: 0,
    };

    let metadata = to_token_metadata(packed_id, mutable_state);

    assert!(metadata.game_id == 0, "game_id should be 0");
    assert!(metadata.minted_at == 0, "minted_at should be 0");
    assert!(metadata.settings_id == 0, "settings_id should be 0");
    assert!(metadata.lifecycle.start == 0, "lifecycle.start should be 0");
    assert!(metadata.lifecycle.end == 0, "lifecycle.end should be 0");
    assert!(metadata.minted_by == 0, "minted_by should be 0");
    assert!(!metadata.soulbound, "soulbound should be false");
    assert!(!metadata.game_over, "game_over should be false");
    assert!(!metadata.completed_objective, "completed_objective should be false");
    assert!(!metadata.has_context, "has_context should be false");
}

#[test]
fn test_to_token_metadata_conversion_full() {
    let packed_id = PackedTokenId {
        game_id: 100,
        minted_by: 200,
        settings_id: 300,
        minted_at: 1000,
        start_delay: 500,
        end_delay: 1500,
        objective_id: 50,
        soulbound: true,
        has_context: true,
        paymaster: true,
        tx_hash: 512,
        salt: 123,
        metadata: 456,
    };

    let mutable_state = TokenMutableState {
        game_over: true, completed_objective: true, completed_at: 0,
    };

    let metadata = to_token_metadata(packed_id, mutable_state);

    assert!(metadata.game_id == 100, "game_id should be 100");
    assert!(metadata.minted_at == 1000, "minted_at should be 1000");
    assert!(metadata.settings_id == 300, "settings_id should be 300");
    assert!(metadata.lifecycle.start == 1500, "lifecycle.start should be minted_at + start_delay");
    assert!(
        metadata.lifecycle.end == 3000,
        "lifecycle.end should be minted_at + start_delay + end_delay",
    );
    assert!(metadata.minted_by == 200, "minted_by should be 200");
    assert!(metadata.soulbound, "soulbound should be true");
    assert!(metadata.game_over, "game_over should be true");
    assert!(metadata.completed_objective, "completed_objective should be true");
    assert!(metadata.has_context, "has_context should be true");
    assert!(metadata.objective_id == 50, "objective_id should be 50");
}

#[test]
fn test_to_token_metadata_mutable_state_independence() {
    // Test that mutable state values override packed_id for game_over and completed_objective
    let packed_id = PackedTokenId {
        game_id: 1,
        minted_by: 1,
        settings_id: 1,
        minted_at: 1,
        start_delay: 1,
        end_delay: 1,
        objective_id: 1,
        soulbound: true,
        has_context: true,
        paymaster: false,
        tx_hash: 1,
        salt: 1,
        metadata: 1,
    };

    // Test game_over = true, completed_objective = false
    let mutable_state1 = TokenMutableState {
        game_over: true, completed_objective: false, completed_at: 0,
    };
    let metadata1 = to_token_metadata(packed_id, mutable_state1);
    assert!(metadata1.game_over, "game_over should be true");
    assert!(!metadata1.completed_objective, "completed_objective should be false");

    // Test game_over = false, completed_objective = true
    let mutable_state2 = TokenMutableState {
        game_over: false, completed_objective: true, completed_at: 0,
    };
    let metadata2 = to_token_metadata(packed_id, mutable_state2);
    assert!(!metadata2.game_over, "game_over should be false");
    assert!(metadata2.completed_objective, "completed_objective should be true");
}

// ============================================================================
// PACKED TOKEN ID HELPER FUNCTION COVERAGE
// ============================================================================

#[test]
fn test_extract_tx_hash_bits_various_inputs() {
    // Test zero
    let bits0 = extract_tx_hash_bits(0);
    assert!(bits0 == 0, "Zero should extract to 0");

    // Test small value (no masking needed)
    let bits1 = extract_tx_hash_bits(100);
    assert!(bits1 == 100, "100 should extract to 100");

    // Test value at 10-bit boundary (1023)
    let bits2 = extract_tx_hash_bits(1023);
    assert!(bits2 == 1023, "1023 should extract to 1023 (max 10-bit)");

    // Test value exceeding 10-bit boundary (should be masked)
    let bits3 = extract_tx_hash_bits(1024);
    assert!(bits3 == 0, "1024 should extract to 0 (overflow)");

    // Test large value
    let large_hash: felt252 = 0x123456789ABCDEF;
    let bits4 = extract_tx_hash_bits(large_hash);
    // Last 10 bits of 0xDEF = 3567, masked to 10 bits = 3567 & 0x3FF = 495
    assert!(bits4 == 495, "Large hash should be masked correctly");
}

#[test]
fn test_individual_unpack_functions_comprehensive() {
    // Create a packed token with known values
    let packed = pack_token_id(
        42, // game_id
        100, // minted_by
        5, // settings_id
        1704067200, // minted_at
        3600, // start_delay
        86400, // end_delay
        7, // objective_id
        true, // soulbound
        true, // has_context
        false, // paymaster
        512, // tx_hash
        100, // salt
        255 // metadata
    );

    // Test each individual unpack function
    assert!(unpack_game_id(packed) == 42, "unpack_game_id failed");
    assert!(unpack_minted_by(packed) == 100, "unpack_minted_by failed");
    assert!(unpack_settings_id(packed) == 5, "unpack_settings_id failed");
    assert!(unpack_minted_at(packed) == 1704067200, "unpack_minted_at failed");
    assert!(unpack_start_delay(packed) == 3600, "unpack_start_delay failed");
    assert!(unpack_end_delay(packed) == 86400, "unpack_end_delay failed");
    assert!(unpack_objective_id(packed) == 7, "unpack_objective_id failed");
    assert!(unpack_soulbound(packed), "unpack_soulbound failed");
    assert!(unpack_has_context(packed), "unpack_has_context failed");
    assert!(!unpack_paymaster(packed), "unpack_paymaster failed");
    assert!(unpack_tx_hash(packed) == 512, "unpack_tx_hash failed");
    assert!(unpack_salt(packed) == 100, "unpack_salt failed");
    assert!(unpack_metadata(packed) == 255, "unpack_metadata failed");
}

// ============================================================================
// FUZZ TESTS FOR STOREPACKING
// ============================================================================

#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_lifecycle_pack_unpack(start: u64, end: u64) {
    let lifecycle = Lifecycle { start, end };
    let packed = LifecycleStorePacking::pack(lifecycle);
    let unpacked = LifecycleStorePacking::unpack(packed);

    assert!(unpacked.start == start, "Fuzzed start should match");
    assert!(unpacked.end == end, "Fuzzed end should match");
}

#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_token_mutable_state_pack_unpack(game_over: bool, completed_objective: bool) {
    let state = TokenMutableState { game_over, completed_objective, completed_at: 0 };
    let packed = TokenMutableStateStorePacking::pack(state);
    let unpacked = TokenMutableStateStorePacking::unpack(packed);

    assert!(unpacked.game_over == game_over, "Fuzzed game_over should match");
    assert!(
        unpacked.completed_objective == completed_objective,
        "Fuzzed completed_objective should match",
    );
}

#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_pack_token_id_roundtrip(
    game_id: u32,
    minted_by: u64,
    settings_id: u32,
    minted_at: u64,
    start_delay: u32,
    end_delay: u32,
    objective_id: u32,
    soulbound: bool,
    has_context: bool,
    paymaster: bool,
) {
    // Mask values to their respective bit widths
    let masked_game_id = game_id & 0x3FFFFFFF; // 30 bits
    let masked_minted_by = minted_by & 0xFFFFFFFFFF; // 40 bits
    let masked_settings_id = settings_id & 0x3FFFFFFF; // 30 bits
    let masked_minted_at = minted_at & 0x7FFFFFFFF; // 35 bits
    let masked_start_delay = start_delay & 0x1FFFFFF; // 25 bits
    let masked_end_delay = end_delay & 0x1FFFFFF; // 25 bits
    let masked_objective_id = objective_id & 0x3FFFFFFF; // 30 bits

    let packed = pack_token_id(
        masked_game_id,
        masked_minted_by,
        masked_settings_id,
        masked_minted_at,
        masked_start_delay,
        masked_end_delay,
        masked_objective_id,
        soulbound,
        has_context,
        paymaster,
        0, // tx_hash
        0, // salt
        0 // metadata
    );

    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == masked_game_id, "Fuzzed game_id roundtrip failed");
    assert!(unpacked.minted_by == masked_minted_by, "Fuzzed minted_by roundtrip failed");
    assert!(unpacked.settings_id == masked_settings_id, "Fuzzed settings_id roundtrip failed");
    assert!(unpacked.minted_at == masked_minted_at, "Fuzzed minted_at roundtrip failed");
    assert!(unpacked.start_delay == masked_start_delay, "Fuzzed start_delay roundtrip failed");
    assert!(unpacked.end_delay == masked_end_delay, "Fuzzed end_delay roundtrip failed");
    assert!(unpacked.objective_id == masked_objective_id, "Fuzzed objective_id roundtrip failed");
    assert!(unpacked.soulbound == soulbound, "Fuzzed soulbound roundtrip failed");
    assert!(unpacked.has_context == has_context, "Fuzzed has_context roundtrip failed");
    assert!(unpacked.paymaster == paymaster, "Fuzzed paymaster roundtrip failed");
}

// ============================================================================
// ADDITIONAL INDIVIDUAL UNPACK FUNCTION TESTS
// ============================================================================

#[test]
fn test_unpack_game_id_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(unpack_game_id(packed) == 0, "game_id should be 0");
}

#[test]
fn test_unpack_minted_by_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(unpack_minted_by(packed) == 0, "minted_by should be 0");
}

#[test]
fn test_unpack_settings_id_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(unpack_settings_id(packed) == 0, "settings_id should be 0");
}

#[test]
fn test_unpack_minted_at_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(unpack_minted_at(packed) == 0, "minted_at should be 0");
}

#[test]
fn test_unpack_start_delay_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(unpack_start_delay(packed) == 0, "start_delay should be 0");
}

#[test]
fn test_unpack_end_delay_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(unpack_end_delay(packed) == 0, "end_delay should be 0");
}

#[test]
fn test_unpack_objective_id_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(unpack_objective_id(packed) == 0, "objective_id should be 0");
}

#[test]
fn test_unpack_soulbound_false() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(!unpack_soulbound(packed), "soulbound should be false");
}

#[test]
fn test_unpack_soulbound_true() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, true, false, false, 0, 0, 0);
    assert!(unpack_soulbound(packed), "soulbound should be true");
}

#[test]
fn test_unpack_has_context_false() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(!unpack_has_context(packed), "has_context should be false");
}

#[test]
fn test_unpack_has_context_true() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, true, false, 0, 0, 0);
    assert!(unpack_has_context(packed), "has_context should be true");
}

#[test]
fn test_unpack_paymaster_false() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(!unpack_paymaster(packed), "paymaster should be false");
}

#[test]
fn test_unpack_paymaster_true() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, true, 0, 0, 0);
    assert!(unpack_paymaster(packed), "paymaster should be true");
}

#[test]
fn test_unpack_tx_hash_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(unpack_tx_hash(packed) == 0, "tx_hash should be 0");
}

#[test]
fn test_unpack_tx_hash_value() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 500, 0, 0);
    assert!(unpack_tx_hash(packed) == 500, "tx_hash should be 500");
}

#[test]
fn test_unpack_salt_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(unpack_salt(packed) == 0, "salt should be 0");
}

#[test]
fn test_unpack_salt_value() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 123, 0);
    assert!(unpack_salt(packed) == 123, "salt should be 123");
}

#[test]
fn test_unpack_metadata_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    assert!(unpack_metadata(packed) == 0, "metadata should be 0");
}

#[test]
fn test_unpack_metadata_value() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 255);
    assert!(unpack_metadata(packed) == 255, "metadata should be 255");
}

// ============================================================================
// COMPREHENSIVE PACK/UNPACK WITH NON-ZERO VALUES
// ============================================================================

#[test]
fn test_pack_unpack_all_non_zero() {
    let game_id: u32 = 12345;
    let minted_by: u64 = 99999;
    let settings_id: u32 = 42;
    let minted_at: u64 = 1704067200;
    let start_delay: u32 = 3600;
    let end_delay: u32 = 86400;
    let objective_id: u32 = 77;
    let tx_hash: u16 = 512;
    let salt: u16 = 100;
    let metadata: u16 = 255;

    let packed = pack_token_id(
        game_id,
        minted_by,
        settings_id,
        minted_at,
        start_delay,
        end_delay,
        objective_id,
        true,
        true,
        true,
        tx_hash,
        salt,
        metadata,
    );

    // Test all individual unpack functions with non-zero values
    assert!(unpack_game_id(packed) == game_id, "game_id roundtrip");
    assert!(unpack_minted_by(packed) == minted_by, "minted_by roundtrip");
    assert!(unpack_settings_id(packed) == settings_id, "settings_id roundtrip");
    assert!(unpack_minted_at(packed) == minted_at, "minted_at roundtrip");
    assert!(unpack_start_delay(packed) == start_delay, "start_delay roundtrip");
    assert!(unpack_end_delay(packed) == end_delay, "end_delay roundtrip");
    assert!(unpack_objective_id(packed) == objective_id, "objective_id roundtrip");
    assert!(unpack_soulbound(packed), "soulbound roundtrip");
    assert!(unpack_has_context(packed), "has_context roundtrip");
    assert!(unpack_paymaster(packed), "paymaster roundtrip");
    assert!(unpack_tx_hash(packed) == tx_hash, "tx_hash roundtrip");
    assert!(unpack_salt(packed) == salt, "salt roundtrip");
    assert!(unpack_metadata(packed) == metadata, "metadata roundtrip");
}

#[test]
fn test_pack_preserves_all_fields_independently() {
    // Test that changing one field doesn't affect others
    let with_game_id = pack_token_id(1, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);

    // game_id changed
    assert!(unpack_game_id(with_game_id) == 1, "game_id should be 1");
    // others unchanged
    assert!(unpack_minted_by(with_game_id) == 0, "minted_by should be 0");
    assert!(unpack_settings_id(with_game_id) == 0, "settings_id should be 0");
    assert!(!unpack_soulbound(with_game_id), "soulbound should be false");
}

// ============================================================================
// DIVREM U128-ALIGNED LAYOUT OPTIMIZATION TESTS
// ============================================================================

// ----------------------------------------------------------------------------
// 1. Zero packed value
// ----------------------------------------------------------------------------

#[test]
fn test_divrem_zero_packed_value_is_zero() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    let packed_u256: u256 = packed.into();
    assert!(packed_u256.low == 0, "zero pack: low u128 should be 0");
    assert!(packed_u256.high == 0, "zero pack: high u128 should be 0");
    assert!(packed == 0, "zero pack: felt252 should be 0");
}

// ----------------------------------------------------------------------------
// 2. u128 boundary - low half only (game_id, minted_by, settings_id, start_delay, flags)
// ----------------------------------------------------------------------------

#[test]
fn test_divrem_low_half_only_high_is_zero() {
    // Set all low-half fields to non-zero, all high-half fields to zero
    // Low half: game_id, minted_by, settings_id, start_delay, soulbound, has_context, paymaster
    let packed = pack_token_id(
        999, // game_id (low)
        54321, // minted_by (low)
        42, // settings_id (low)
        0, // minted_at (high)
        8000, // start_delay (low)
        0, // end_delay (high)
        0, // objective_id (high)
        true, // soulbound (low)
        true, // has_context (low)
        true, // paymaster (low)
        0, // tx_hash (high)
        0, // salt (high)
        0 // metadata (high)
    );
    let packed_u256: u256 = packed.into();
    assert!(packed_u256.high == 0, "low-half only: high u128 must be 0");
    assert!(packed_u256.low != 0, "low-half only: low u128 must be non-zero");

    // Verify fields round-trip correctly
    let unpacked = unpack_token_id(packed);
    assert!(unpacked.game_id == 999, "low-half: game_id");
    assert!(unpacked.minted_by == 54321, "low-half: minted_by");
    assert!(unpacked.settings_id == 42, "low-half: settings_id");
    assert!(unpacked.start_delay == 8000, "low-half: start_delay");
    assert!(unpacked.soulbound, "low-half: soulbound");
    assert!(unpacked.has_context, "low-half: has_context");
    assert!(unpacked.paymaster, "low-half: paymaster");
}

// ----------------------------------------------------------------------------
// 3. u128 boundary - high half only (minted_at, end_delay, objective_id, tx_hash, salt, metadata)
// ----------------------------------------------------------------------------

#[test]
fn test_divrem_high_half_only_low_is_zero() {
    // Set all high-half fields to non-zero, all low-half fields to zero
    // High half: minted_at, end_delay, objective_id, tx_hash, salt, metadata
    // Flags (soulbound, has_context, paymaster) are in low half now
    let packed = pack_token_id(
        0, // game_id (low)
        0, // minted_by (low)
        0, // settings_id (low)
        1704067200, // minted_at (high)
        0, // start_delay (low)
        86400, // end_delay (high)
        7, // objective_id (high)
        false, // soulbound (low - must be false for low=0)
        false, // has_context (low - must be false for low=0)
        false, // paymaster (low - must be false for low=0)
        512, // tx_hash (high)
        100, // salt (high)
        255 // metadata (high)
    );
    let packed_u256: u256 = packed.into();
    assert!(packed_u256.low == 0, "high-half only: low u128 must be 0");
    assert!(packed_u256.high != 0, "high-half only: high u128 must be non-zero");

    // Verify fields round-trip correctly
    let unpacked = unpack_token_id(packed);
    assert!(unpacked.minted_at == 1704067200, "high-half: minted_at");
    assert!(unpacked.end_delay == 86400, "high-half: end_delay");
    assert!(unpacked.objective_id == 7, "high-half: objective_id");
    assert!(!unpacked.soulbound, "high-half: soulbound should be false");
    assert!(!unpacked.has_context, "high-half: has_context should be false");
    assert!(!unpacked.paymaster, "high-half: paymaster should be false");
    assert!(unpacked.tx_hash == 512, "high-half: tx_hash");
    assert!(unpacked.salt == 100, "high-half: salt");
    assert!(unpacked.metadata == 255, "high-half: metadata");
}

// ----------------------------------------------------------------------------
// 4. Alternating max/zero for adjacent fields
// ----------------------------------------------------------------------------

#[test]
fn test_divrem_alternating_max_zero_pattern_a() {
    // Pattern A: odd fields max, even fields zero
    // game_id=max, minted_by=0, settings_id=max, minted_at=0, start_delay=max,
    // end_delay=0, objective_id=max, soulbound=true, has_context=false, paymaster=true,
    // tx_hash=0, salt=max, metadata=0
    let packed = pack_token_id(
        0x3FFFFFFF, 0, 0x3FFFFFFF, 0, 0x1FFFFFF, 0, 0x3FFFFFFF, true, false, true, 0, 0x3FF, 0,
    );
    let u = unpack_token_id(packed);
    assert!(u.game_id == 0x3FFFFFFF, "alt_a: game_id");
    assert!(u.minted_by == 0, "alt_a: minted_by");
    assert!(u.settings_id == 0x3FFFFFFF, "alt_a: settings_id");
    assert!(u.minted_at == 0, "alt_a: minted_at");
    assert!(u.start_delay == 0x1FFFFFF, "alt_a: start_delay");
    assert!(u.end_delay == 0, "alt_a: end_delay");
    assert!(u.objective_id == 0x3FFFFFFF, "alt_a: objective_id");
    assert!(u.soulbound, "alt_a: soulbound");
    assert!(!u.has_context, "alt_a: has_context");
    assert!(u.paymaster, "alt_a: paymaster");
    assert!(u.tx_hash == 0, "alt_a: tx_hash");
    assert!(u.salt == 0x3FF, "alt_a: salt");
    assert!(u.metadata == 0, "alt_a: metadata");
}

#[test]
fn test_divrem_alternating_max_zero_pattern_b() {
    // Pattern B: even fields max, odd fields zero (inverse of pattern A)
    let packed = pack_token_id(
        0, 0xFFFFFFFFFF, 0, 0x7FFFFFFFF, 0, 0x1FFFFFF, 0, false, true, false, 0x3FF, 0, 0x1FFF,
    );
    let u = unpack_token_id(packed);
    assert!(u.game_id == 0, "alt_b: game_id");
    assert!(u.minted_by == 0xFFFFFFFFFF, "alt_b: minted_by");
    assert!(u.settings_id == 0, "alt_b: settings_id");
    assert!(u.minted_at == 0x7FFFFFFFF, "alt_b: minted_at");
    assert!(u.start_delay == 0, "alt_b: start_delay");
    assert!(u.end_delay == 0x1FFFFFF, "alt_b: end_delay");
    assert!(u.objective_id == 0, "alt_b: objective_id");
    assert!(!u.soulbound, "alt_b: soulbound");
    assert!(u.has_context, "alt_b: has_context");
    assert!(!u.paymaster, "alt_b: paymaster");
    assert!(u.tx_hash == 0x3FF, "alt_b: tx_hash");
    assert!(u.salt == 0, "alt_b: salt");
    assert!(u.metadata == 0x1FFF, "alt_b: metadata");
}

// ----------------------------------------------------------------------------
// 5. Near-max values (2^N - 2 for each field)
// ----------------------------------------------------------------------------

#[test]
fn test_divrem_near_max_values() {
    let packed = pack_token_id(
        0x3FFFFFFF - 1, // game_id: 30-bit near-max
        0xFFFFFFFFFF - 1, // minted_by: 40-bit near-max
        0x3FFFFFFF - 1, // settings_id: 30-bit near-max
        0x7FFFFFFFF - 1, // minted_at: 35-bit near-max
        0x1FFFFFF - 1, // start_delay: 25-bit near-max
        0x1FFFFFF - 1, // end_delay: 25-bit near-max
        0x3FFFFFFF - 1, // objective_id: 30-bit near-max
        true,
        true,
        true,
        0x3FF - 1, // tx_hash: 10-bit near-max
        0x3FF - 1, // salt: 10-bit near-max
        0x1FFF - 1 // metadata: 13-bit near-max
    );
    let u = unpack_token_id(packed);

    assert!(u.game_id == 0x3FFFFFFE, "near_max: game_id");
    assert!(u.minted_by == 0xFFFFFFFFFE, "near_max: minted_by");
    assert!(u.settings_id == 0x3FFFFFFE, "near_max: settings_id");
    assert!(u.minted_at == 0x7FFFFFFFE, "near_max: minted_at");
    assert!(u.start_delay == 0x1FFFFFE, "near_max: start_delay");
    assert!(u.end_delay == 0x1FFFFFE, "near_max: end_delay");
    assert!(u.objective_id == 0x3FFFFFFE, "near_max: objective_id");
    assert!(u.soulbound, "near_max: soulbound");
    assert!(u.has_context, "near_max: has_context");
    assert!(u.paymaster, "near_max: paymaster");
    assert!(u.tx_hash == 0x3FE, "near_max: tx_hash");
    assert!(u.salt == 0x3FE, "near_max: salt");
    assert!(u.metadata == 0x1FFE, "near_max: metadata");
}

// ----------------------------------------------------------------------------
// 6. Single field isolation for ALL 13 fields
// ----------------------------------------------------------------------------

#[test]
fn test_divrem_isolate_game_id() {
    let packed = pack_token_id(777, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.game_id == 777, "isolate: game_id value");
    assert!(u.minted_by == 0, "isolate: game_id -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: game_id -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: game_id -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: game_id -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: game_id -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: game_id -> objective_id clean");
    assert!(!u.soulbound, "isolate: game_id -> soulbound clean");
    assert!(!u.has_context, "isolate: game_id -> has_context clean");
    assert!(!u.paymaster, "isolate: game_id -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: game_id -> tx_hash clean");
    assert!(u.salt == 0, "isolate: game_id -> salt clean");
    assert!(u.metadata == 0, "isolate: game_id -> metadata clean");
}

#[test]
fn test_divrem_isolate_minted_by() {
    let packed = pack_token_id(0, 123456789, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.minted_by == 123456789, "isolate: minted_by value");
    assert!(u.game_id == 0, "isolate: minted_by -> game_id clean");
    assert!(u.settings_id == 0, "isolate: minted_by -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: minted_by -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: minted_by -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: minted_by -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: minted_by -> objective_id clean");
    assert!(!u.soulbound, "isolate: minted_by -> soulbound clean");
    assert!(!u.has_context, "isolate: minted_by -> has_context clean");
    assert!(!u.paymaster, "isolate: minted_by -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: minted_by -> tx_hash clean");
    assert!(u.salt == 0, "isolate: minted_by -> salt clean");
    assert!(u.metadata == 0, "isolate: minted_by -> metadata clean");
}

#[test]
fn test_divrem_isolate_settings_id() {
    let packed = pack_token_id(0, 0, 55555, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.settings_id == 55555, "isolate: settings_id value");
    assert!(u.game_id == 0, "isolate: settings_id -> game_id clean");
    assert!(u.minted_by == 0, "isolate: settings_id -> minted_by clean");
    assert!(u.minted_at == 0, "isolate: settings_id -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: settings_id -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: settings_id -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: settings_id -> objective_id clean");
    assert!(!u.soulbound, "isolate: settings_id -> soulbound clean");
    assert!(!u.has_context, "isolate: settings_id -> has_context clean");
    assert!(!u.paymaster, "isolate: settings_id -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: settings_id -> tx_hash clean");
    assert!(u.salt == 0, "isolate: settings_id -> salt clean");
    assert!(u.metadata == 0, "isolate: settings_id -> metadata clean");
}

#[test]
fn test_divrem_isolate_minted_at() {
    let packed = pack_token_id(0, 0, 0, 1704067200, 0, 0, 0, false, false, false, 0, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.minted_at == 1704067200, "isolate: minted_at value");
    assert!(u.game_id == 0, "isolate: minted_at -> game_id clean");
    assert!(u.minted_by == 0, "isolate: minted_at -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: minted_at -> settings_id clean");
    assert!(u.start_delay == 0, "isolate: minted_at -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: minted_at -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: minted_at -> objective_id clean");
    assert!(!u.soulbound, "isolate: minted_at -> soulbound clean");
    assert!(!u.has_context, "isolate: minted_at -> has_context clean");
    assert!(!u.paymaster, "isolate: minted_at -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: minted_at -> tx_hash clean");
    assert!(u.salt == 0, "isolate: minted_at -> salt clean");
    assert!(u.metadata == 0, "isolate: minted_at -> metadata clean");
}

#[test]
fn test_divrem_isolate_start_delay() {
    let packed = pack_token_id(0, 0, 0, 0, 7200, 0, 0, false, false, false, 0, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.start_delay == 7200, "isolate: start_delay value");
    assert!(u.game_id == 0, "isolate: start_delay -> game_id clean");
    assert!(u.minted_by == 0, "isolate: start_delay -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: start_delay -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: start_delay -> minted_at clean");
    assert!(u.end_delay == 0, "isolate: start_delay -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: start_delay -> objective_id clean");
    assert!(!u.soulbound, "isolate: start_delay -> soulbound clean");
    assert!(!u.has_context, "isolate: start_delay -> has_context clean");
    assert!(!u.paymaster, "isolate: start_delay -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: start_delay -> tx_hash clean");
    assert!(u.salt == 0, "isolate: start_delay -> salt clean");
    assert!(u.metadata == 0, "isolate: start_delay -> metadata clean");
}

#[test]
fn test_divrem_isolate_end_delay() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 43200, 0, false, false, false, 0, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.end_delay == 43200, "isolate: end_delay value");
    assert!(u.game_id == 0, "isolate: end_delay -> game_id clean");
    assert!(u.minted_by == 0, "isolate: end_delay -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: end_delay -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: end_delay -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: end_delay -> start_delay clean");
    assert!(u.objective_id == 0, "isolate: end_delay -> objective_id clean");
    assert!(!u.soulbound, "isolate: end_delay -> soulbound clean");
    assert!(!u.has_context, "isolate: end_delay -> has_context clean");
    assert!(!u.paymaster, "isolate: end_delay -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: end_delay -> tx_hash clean");
    assert!(u.salt == 0, "isolate: end_delay -> salt clean");
    assert!(u.metadata == 0, "isolate: end_delay -> metadata clean");
}

#[test]
fn test_divrem_isolate_objective_id() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 999999, false, false, false, 0, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.objective_id == 999999, "isolate: objective_id value");
    assert!(u.game_id == 0, "isolate: objective_id -> game_id clean");
    assert!(u.minted_by == 0, "isolate: objective_id -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: objective_id -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: objective_id -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: objective_id -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: objective_id -> end_delay clean");
    assert!(!u.soulbound, "isolate: objective_id -> soulbound clean");
    assert!(!u.has_context, "isolate: objective_id -> has_context clean");
    assert!(!u.paymaster, "isolate: objective_id -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: objective_id -> tx_hash clean");
    assert!(u.salt == 0, "isolate: objective_id -> salt clean");
    assert!(u.metadata == 0, "isolate: objective_id -> metadata clean");
}

#[test]
fn test_divrem_isolate_soulbound() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, true, false, false, 0, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.soulbound, "isolate: soulbound value");
    assert!(u.game_id == 0, "isolate: soulbound -> game_id clean");
    assert!(u.minted_by == 0, "isolate: soulbound -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: soulbound -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: soulbound -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: soulbound -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: soulbound -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: soulbound -> objective_id clean");
    assert!(!u.has_context, "isolate: soulbound -> has_context clean");
    assert!(!u.paymaster, "isolate: soulbound -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: soulbound -> tx_hash clean");
    assert!(u.salt == 0, "isolate: soulbound -> salt clean");
    assert!(u.metadata == 0, "isolate: soulbound -> metadata clean");
}

#[test]
fn test_divrem_isolate_has_context() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, true, false, 0, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.has_context, "isolate: has_context value");
    assert!(u.game_id == 0, "isolate: has_context -> game_id clean");
    assert!(u.minted_by == 0, "isolate: has_context -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: has_context -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: has_context -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: has_context -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: has_context -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: has_context -> objective_id clean");
    assert!(!u.soulbound, "isolate: has_context -> soulbound clean");
    assert!(!u.paymaster, "isolate: has_context -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: has_context -> tx_hash clean");
    assert!(u.salt == 0, "isolate: has_context -> salt clean");
    assert!(u.metadata == 0, "isolate: has_context -> metadata clean");
}

#[test]
fn test_divrem_isolate_paymaster() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, true, 0, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.paymaster, "isolate: paymaster value");
    assert!(u.game_id == 0, "isolate: paymaster -> game_id clean");
    assert!(u.minted_by == 0, "isolate: paymaster -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: paymaster -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: paymaster -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: paymaster -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: paymaster -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: paymaster -> objective_id clean");
    assert!(!u.soulbound, "isolate: paymaster -> soulbound clean");
    assert!(!u.has_context, "isolate: paymaster -> has_context clean");
    assert!(u.tx_hash == 0, "isolate: paymaster -> tx_hash clean");
    assert!(u.salt == 0, "isolate: paymaster -> salt clean");
    assert!(u.metadata == 0, "isolate: paymaster -> metadata clean");
}

#[test]
fn test_divrem_isolate_tx_hash() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 777, 0, 0);
    let u = unpack_token_id(packed);
    assert!(u.tx_hash == 777, "isolate: tx_hash value");
    assert!(u.game_id == 0, "isolate: tx_hash -> game_id clean");
    assert!(u.minted_by == 0, "isolate: tx_hash -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: tx_hash -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: tx_hash -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: tx_hash -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: tx_hash -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: tx_hash -> objective_id clean");
    assert!(!u.soulbound, "isolate: tx_hash -> soulbound clean");
    assert!(!u.has_context, "isolate: tx_hash -> has_context clean");
    assert!(!u.paymaster, "isolate: tx_hash -> paymaster clean");
    assert!(u.salt == 0, "isolate: tx_hash -> salt clean");
    assert!(u.metadata == 0, "isolate: tx_hash -> metadata clean");
}

#[test]
fn test_divrem_isolate_salt() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 555, 0);
    let u = unpack_token_id(packed);
    assert!(u.salt == 555, "isolate: salt value");
    assert!(u.game_id == 0, "isolate: salt -> game_id clean");
    assert!(u.minted_by == 0, "isolate: salt -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: salt -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: salt -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: salt -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: salt -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: salt -> objective_id clean");
    assert!(!u.soulbound, "isolate: salt -> soulbound clean");
    assert!(!u.has_context, "isolate: salt -> has_context clean");
    assert!(!u.paymaster, "isolate: salt -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: salt -> tx_hash clean");
    assert!(u.metadata == 0, "isolate: salt -> metadata clean");
}

#[test]
fn test_divrem_isolate_metadata() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 4095);
    let u = unpack_token_id(packed);
    assert!(u.metadata == 4095, "isolate: metadata value");
    assert!(u.game_id == 0, "isolate: metadata -> game_id clean");
    assert!(u.minted_by == 0, "isolate: metadata -> minted_by clean");
    assert!(u.settings_id == 0, "isolate: metadata -> settings_id clean");
    assert!(u.minted_at == 0, "isolate: metadata -> minted_at clean");
    assert!(u.start_delay == 0, "isolate: metadata -> start_delay clean");
    assert!(u.end_delay == 0, "isolate: metadata -> end_delay clean");
    assert!(u.objective_id == 0, "isolate: metadata -> objective_id clean");
    assert!(!u.soulbound, "isolate: metadata -> soulbound clean");
    assert!(!u.has_context, "isolate: metadata -> has_context clean");
    assert!(!u.paymaster, "isolate: metadata -> paymaster clean");
    assert!(u.tx_hash == 0, "isolate: metadata -> tx_hash clean");
    assert!(u.salt == 0, "isolate: metadata -> salt clean");
}

// ----------------------------------------------------------------------------
// 7. Idempotency test (double pack/unpack)
// ----------------------------------------------------------------------------

#[test]
fn test_divrem_idempotency_double_roundtrip() {
    let packed1 = pack_token_id(
        42, 99999, 7, 1704067200, 3600, 86400, 13, true, false, true, 512, 100, 255,
    );
    let u1 = unpack_token_id(packed1);

    // Re-pack the unpacked values
    let packed2 = pack_token_id(
        u1.game_id,
        u1.minted_by,
        u1.settings_id,
        u1.minted_at,
        u1.start_delay,
        u1.end_delay,
        u1.objective_id,
        u1.soulbound,
        u1.has_context,
        u1.paymaster,
        u1.tx_hash,
        u1.salt,
        u1.metadata,
    );

    // packed1 and packed2 must be identical
    assert!(packed1 == packed2, "idempotency: double roundtrip must produce same packed value");

    // Unpack again and verify all fields
    let u2 = unpack_token_id(packed2);
    assert!(u2.game_id == u1.game_id, "idempotency: game_id");
    assert!(u2.minted_by == u1.minted_by, "idempotency: minted_by");
    assert!(u2.settings_id == u1.settings_id, "idempotency: settings_id");
    assert!(u2.minted_at == u1.minted_at, "idempotency: minted_at");
    assert!(u2.start_delay == u1.start_delay, "idempotency: start_delay");
    assert!(u2.end_delay == u1.end_delay, "idempotency: end_delay");
    assert!(u2.objective_id == u1.objective_id, "idempotency: objective_id");
    assert!(u2.soulbound == u1.soulbound, "idempotency: soulbound");
    assert!(u2.has_context == u1.has_context, "idempotency: has_context");
    assert!(u2.paymaster == u1.paymaster, "idempotency: paymaster");
    assert!(u2.tx_hash == u1.tx_hash, "idempotency: tx_hash");
    assert!(u2.salt == u1.salt, "idempotency: salt");
    assert!(u2.metadata == u1.metadata, "idempotency: metadata");
}

// ----------------------------------------------------------------------------
// 8. Realistic game scenario values
// ----------------------------------------------------------------------------

#[test]
fn test_divrem_realistic_tournament_scenario() {
    // Realistic tournament: game #3, player #50000, settings #1,
    // minted Jan 1 2025 (Unix 1735689600), 1 hour start delay, 24 hour end delay,
    // objective #2, soulbound tournament token, no context, paymaster-sponsored,
    // tx_hash bits, salt for multicall
    let packed = pack_token_id(
        3, // game_id
        50000, // minted_by (player index)
        1, // settings_id
        1735689600, // minted_at (Jan 1 2025 00:00:00 UTC)
        3600, // start_delay (1 hour)
        86400, // end_delay (24 hours)
        2, // objective_id
        true, // soulbound
        false, // has_context
        true, // paymaster
        42, // tx_hash bits
        7, // salt
        100 // metadata
    );

    let u = unpack_token_id(packed);
    assert!(u.game_id == 3, "tournament: game_id");
    assert!(u.minted_by == 50000, "tournament: minted_by");
    assert!(u.settings_id == 1, "tournament: settings_id");
    assert!(u.minted_at == 1735689600, "tournament: minted_at");
    assert!(u.start_delay == 3600, "tournament: start_delay");
    assert!(u.end_delay == 86400, "tournament: end_delay");
    assert!(u.objective_id == 2, "tournament: objective_id");
    assert!(u.soulbound, "tournament: soulbound");
    assert!(!u.has_context, "tournament: has_context");
    assert!(u.paymaster, "tournament: paymaster");
    assert!(u.tx_hash == 42, "tournament: tx_hash");
    assert!(u.salt == 7, "tournament: salt");
    assert!(u.metadata == 100, "tournament: metadata");

    // Verify the u128 boundary: both halves should be populated
    let packed_u256: u256 = packed.into();
    assert!(packed_u256.low != 0, "tournament: low half should be populated");
    assert!(packed_u256.high != 0, "tournament: high half should be populated");
}

#[test]
fn test_divrem_realistic_casual_game_scenario() {
    // Casual free-to-play game: large game_id, transferable, no paymaster,
    // with context, no delays, no objective
    let packed = pack_token_id(
        1000000, // game_id (large game registry)
        999999999, // minted_by
        50, // settings_id
        1735776000, // minted_at (Jan 2 2025)
        0, // start_delay (immediate)
        0, // end_delay (no expiry)
        0, // objective_id (no objective)
        false, // soulbound (transferable)
        true, // has_context
        false, // paymaster (self-pay)
        999, // tx_hash bits
        0, // salt (single mint)
        8191 // metadata (max 13-bit)
    );

    let u = unpack_token_id(packed);
    assert!(u.game_id == 1000000, "casual: game_id");
    assert!(u.minted_by == 999999999, "casual: minted_by");
    assert!(u.settings_id == 50, "casual: settings_id");
    assert!(u.minted_at == 1735776000, "casual: minted_at");
    assert!(u.start_delay == 0, "casual: start_delay");
    assert!(u.end_delay == 0, "casual: end_delay");
    assert!(u.objective_id == 0, "casual: objective_id");
    assert!(!u.soulbound, "casual: soulbound");
    assert!(u.has_context, "casual: has_context");
    assert!(!u.paymaster, "casual: paymaster");
    assert!(u.tx_hash == 999, "casual: tx_hash");
    assert!(u.salt == 0, "casual: salt");
    assert!(u.metadata == 8191, "casual: metadata");
}
