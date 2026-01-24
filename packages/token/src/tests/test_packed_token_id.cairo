// =============================================================================
// PACKED TOKEN ID UNIT TESTS
// =============================================================================
// Tests for the bit-packing functions that encode/decode immutable token
// metadata into the token_id (felt252).

use crate::structs::{
    extract_tx_hash_bits, pack_token_id, unpack_end_delay, unpack_game_id, unpack_has_context,
    unpack_metadata, unpack_minted_at, unpack_minted_by, unpack_objective_id, unpack_paymaster,
    unpack_salt, unpack_settings_id, unpack_soulbound, unpack_start_delay, unpack_token_id,
    unpack_tx_hash,
};

// =============================================================================
// ROUND-TRIP TESTS
// =============================================================================

#[test]
fn test_pack_unpack_roundtrip_basic() {
    // Test basic values
    let game_id: u32 = 42;
    let minted_by: u64 = 100;
    let settings_id: u32 = 5;
    let minted_at: u64 = 1704067200; // 2024-01-01 00:00:00 UTC
    let start_delay: u32 = 3600; // 1 hour
    let end_delay: u32 = 86400; // 24 hours
    let objective_id: u32 = 3;
    let soulbound: bool = true;
    let has_context: bool = false;
    let paymaster: bool = true;
    let tx_hash: u16 = 512; // 10 bits max = 1023
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
        soulbound,
        has_context,
        paymaster,
        tx_hash,
        salt,
        metadata,
    );

    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == game_id, "game_id mismatch");
    assert!(unpacked.minted_by == minted_by, "minted_by mismatch");
    assert!(unpacked.settings_id == settings_id, "settings_id mismatch");
    assert!(unpacked.minted_at == minted_at, "minted_at mismatch");
    assert!(unpacked.start_delay == start_delay, "start_delay mismatch");
    assert!(unpacked.end_delay == end_delay, "end_delay mismatch");
    assert!(unpacked.objective_id == objective_id, "objective_id mismatch");
    assert!(unpacked.soulbound == soulbound, "soulbound mismatch");
    assert!(unpacked.has_context == has_context, "has_context mismatch");
    assert!(unpacked.paymaster == paymaster, "paymaster mismatch");
    assert!(unpacked.tx_hash == tx_hash, "tx_hash mismatch");
    assert!(unpacked.salt == salt, "salt mismatch");
    assert!(unpacked.metadata == metadata, "metadata mismatch");
}

#[test]
fn test_pack_unpack_roundtrip_zeros() {
    // Test all zeros
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);

    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == 0, "game_id should be 0");
    assert!(unpacked.minted_by == 0, "minted_by should be 0");
    assert!(unpacked.settings_id == 0, "settings_id should be 0");
    assert!(unpacked.minted_at == 0, "minted_at should be 0");
    assert!(unpacked.start_delay == 0, "start_delay should be 0");
    assert!(unpacked.end_delay == 0, "end_delay should be 0");
    assert!(unpacked.objective_id == 0, "objective_id should be 0");
    assert!(!unpacked.soulbound, "soulbound should be false");
    assert!(!unpacked.has_context, "has_context should be false");
    assert!(!unpacked.paymaster, "paymaster should be false");
    assert!(unpacked.tx_hash == 0, "tx_hash should be 0");
    assert!(unpacked.salt == 0, "salt should be 0");
    assert!(unpacked.metadata == 0, "metadata should be 0");
}

#[test]
fn test_pack_unpack_roundtrip_max_values() {
    // Test maximum values for each field within their bit limits
    // game_id: 30 bits -> max 1,073,741,823
    // minted_by: 40 bits -> max 1,099,511,627,775
    // settings_id: 30 bits -> max 1,073,741,823
    // minted_at: 35 bits -> max 34,359,738,367
    // start_delay: 25 bits -> max 33,554,431
    // end_delay: 25 bits -> max 33,554,431
    // objective_id: 30 bits -> max 1,073,741,823
    // tx_hash: 10 bits -> max 1,023
    // salt: 10 bits -> max 1,023
    // metadata: 13 bits -> max 8,191

    let game_id: u32 = 1073741823;
    let minted_by: u64 = 1099511627775;
    let settings_id: u32 = 1073741823;
    let minted_at: u64 = 34359738367;
    let start_delay: u32 = 33554431;
    let end_delay: u32 = 33554431;
    let objective_id: u32 = 1073741823;
    let soulbound: bool = true;
    let has_context: bool = true;
    let paymaster: bool = true;
    let tx_hash: u16 = 1023; // 10 bits max
    let salt: u16 = 1023; // 10 bits max
    let metadata: u16 = 8191; // 13 bits max

    let packed = pack_token_id(
        game_id,
        minted_by,
        settings_id,
        minted_at,
        start_delay,
        end_delay,
        objective_id,
        soulbound,
        has_context,
        paymaster,
        tx_hash,
        salt,
        metadata,
    );

    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == game_id, "game_id max mismatch");
    assert!(unpacked.minted_by == minted_by, "minted_by max mismatch");
    assert!(unpacked.settings_id == settings_id, "settings_id max mismatch");
    assert!(unpacked.minted_at == minted_at, "minted_at max mismatch");
    assert!(unpacked.start_delay == start_delay, "start_delay max mismatch");
    assert!(unpacked.end_delay == end_delay, "end_delay max mismatch");
    assert!(unpacked.objective_id == objective_id, "objective_id max mismatch");
    assert!(unpacked.soulbound == soulbound, "soulbound max mismatch");
    assert!(unpacked.has_context == has_context, "has_context max mismatch");
    assert!(unpacked.paymaster == paymaster, "paymaster max mismatch");
    assert!(unpacked.tx_hash == tx_hash, "tx_hash max mismatch");
    assert!(unpacked.salt == salt, "salt max mismatch");
    assert!(unpacked.metadata == metadata, "metadata max mismatch");
}

// =============================================================================
// HELPER FUNCTION TESTS
// =============================================================================

#[test]
fn test_unpack_game_id_helper() {
    let packed = pack_token_id(12345, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    let game_id = unpack_game_id(packed);
    assert!(game_id == 12345, "unpack_game_id failed");
}

#[test]
fn test_unpack_minted_by_helper() {
    let packed = pack_token_id(0, 54321, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    let minted_by = unpack_minted_by(packed);
    assert!(minted_by == 54321, "unpack_minted_by failed");
}

#[test]
fn test_unpack_settings_id_helper() {
    let packed = pack_token_id(0, 0, 999, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    let settings_id = unpack_settings_id(packed);
    assert!(settings_id == 999, "unpack_settings_id failed");
}

#[test]
fn test_unpack_minted_at_helper() {
    let packed = pack_token_id(0, 0, 0, 1704067200, 0, 0, 0, false, false, false, 0, 0, 0);
    let minted_at = unpack_minted_at(packed);
    assert!(minted_at == 1704067200, "unpack_minted_at failed");
}

#[test]
fn test_unpack_start_delay_helper() {
    let packed = pack_token_id(0, 0, 0, 0, 3600, 0, 0, false, false, false, 0, 0, 0);
    let start_delay = unpack_start_delay(packed);
    assert!(start_delay == 3600, "unpack_start_delay failed");
}

#[test]
fn test_unpack_end_delay_helper() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 86400, 0, false, false, false, 0, 0, 0);
    let end_delay = unpack_end_delay(packed);
    assert!(end_delay == 86400, "unpack_end_delay failed");
}

#[test]
fn test_unpack_objective_id_helper() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 42, false, false, false, 0, 0, 0);
    let objective_id = unpack_objective_id(packed);
    assert!(objective_id == 42, "unpack_objective_id failed");
}

#[test]
fn test_unpack_soulbound_helper_true() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, true, false, false, 0, 0, 0);
    let soulbound = unpack_soulbound(packed);
    assert!(soulbound, "unpack_soulbound should be true");
}

#[test]
fn test_unpack_soulbound_helper_false() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    let soulbound = unpack_soulbound(packed);
    assert!(!soulbound, "unpack_soulbound should be false");
}

#[test]
fn test_unpack_has_context_helper() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, true, false, 0, 0, 0);
    let has_context = unpack_has_context(packed);
    assert!(has_context, "unpack_has_context should be true");
}

#[test]
fn test_unpack_paymaster_helper() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, true, 0, 0, 0);
    let paymaster = unpack_paymaster(packed);
    assert!(paymaster, "unpack_paymaster should be true");
}

#[test]
fn test_unpack_tx_hash_helper() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 777, 0, 0);
    let tx_hash = unpack_tx_hash(packed);
    assert!(tx_hash == 777, "unpack_tx_hash failed");
}

#[test]
fn test_unpack_salt_helper() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 888, 0);
    let salt = unpack_salt(packed);
    assert!(salt == 888, "unpack_salt failed");
}

#[test]
fn test_unpack_metadata_helper() {
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 3000);
    let metadata = unpack_metadata(packed);
    assert!(metadata == 3000, "unpack_metadata failed");
}

#[test]
fn test_extract_tx_hash_bits() {
    // Test that extract_tx_hash_bits correctly extracts last 10 bits
    let tx_hash: felt252 = 0x12345678ABCDEF; // Some arbitrary hash
    let bits = extract_tx_hash_bits(tx_hash);
    // Last 10 bits of 0xABCDEF = 0xDEF & 0x3FF = 0x1EF = 495
    assert!(bits == 495, "extract_tx_hash_bits failed");

    // Test with a value that uses all 10 bits
    let tx_hash_max: felt252 = 0x3FF; // 1023
    let bits_max = extract_tx_hash_bits(tx_hash_max);
    assert!(bits_max == 1023, "extract_tx_hash_bits max failed");

    // Test with zero
    let tx_hash_zero: felt252 = 0;
    let bits_zero = extract_tx_hash_bits(tx_hash_zero);
    assert!(bits_zero == 0, "extract_tx_hash_bits zero failed");
}

// =============================================================================
// BIT ISOLATION TESTS
// =============================================================================
// Verify that setting one field doesn't affect others

#[test]
fn test_bit_isolation_game_id() {
    // Set only game_id to max, verify other fields are zero
    let packed = pack_token_id(1073741823, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, 0);
    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == 1073741823, "game_id should be max");
    assert!(unpacked.minted_by == 0, "minted_by should be 0");
    assert!(unpacked.settings_id == 0, "settings_id should be 0");
    assert!(unpacked.minted_at == 0, "minted_at should be 0");
    assert!(!unpacked.soulbound, "soulbound should be false");
    assert!(unpacked.tx_hash == 0, "tx_hash should be 0");
    assert!(unpacked.salt == 0, "salt should be 0");
    assert!(unpacked.metadata == 0, "metadata should be 0");
}

#[test]
fn test_bit_isolation_tx_hash() {
    // Set only tx_hash to max, verify other fields are zero
    let max_tx_hash: u16 = 1023;
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, max_tx_hash, 0, 0);
    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == 0, "game_id should be 0");
    assert!(unpacked.minted_by == 0, "minted_by should be 0");
    assert!(unpacked.tx_hash == max_tx_hash, "tx_hash should be max");
    assert!(unpacked.salt == 0, "salt should be 0");
    assert!(unpacked.metadata == 0, "metadata should be 0");
}

#[test]
fn test_bit_isolation_salt() {
    // Set only salt to max, verify other fields are zero
    let max_salt: u16 = 1023;
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, max_salt, 0);
    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == 0, "game_id should be 0");
    assert!(unpacked.tx_hash == 0, "tx_hash should be 0");
    assert!(unpacked.salt == max_salt, "salt should be max");
    assert!(unpacked.metadata == 0, "metadata should be 0");
}

#[test]
fn test_bit_isolation_metadata() {
    // Set only metadata to max (13 bits = 8191), verify other fields are zero
    let max_metadata: u16 = 8191;
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, max_metadata);
    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == 0, "game_id should be 0");
    assert!(unpacked.tx_hash == 0, "tx_hash should be 0");
    assert!(unpacked.salt == 0, "salt should be 0");
    assert!(unpacked.metadata == max_metadata, "metadata should be max");
}

#[test]
fn test_bit_isolation_booleans() {
    // Test soulbound=true, has_context=false, paymaster=false
    let packed1 = pack_token_id(0, 0, 0, 0, 0, 0, 0, true, false, false, 0, 0, 0);
    let unpacked1 = unpack_token_id(packed1);
    assert!(unpacked1.soulbound, "soulbound should be true");
    assert!(!unpacked1.has_context, "has_context should be false");
    assert!(!unpacked1.paymaster, "paymaster should be false");

    // Test soulbound=false, has_context=true, paymaster=false
    let packed2 = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, true, false, 0, 0, 0);
    let unpacked2 = unpack_token_id(packed2);
    assert!(!unpacked2.soulbound, "soulbound should be false");
    assert!(unpacked2.has_context, "has_context should be true");
    assert!(!unpacked2.paymaster, "paymaster should be false");

    // Test soulbound=false, has_context=false, paymaster=true
    let packed3 = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, true, 0, 0, 0);
    let unpacked3 = unpack_token_id(packed3);
    assert!(!unpacked3.soulbound, "soulbound should be false");
    assert!(!unpacked3.has_context, "has_context should be false");
    assert!(unpacked3.paymaster, "paymaster should be true");

    // Test all true
    let packed4 = pack_token_id(0, 0, 0, 0, 0, 0, 0, true, true, true, 0, 0, 0);
    let unpacked4 = unpack_token_id(packed4);
    assert!(unpacked4.soulbound, "soulbound should be true");
    assert!(unpacked4.has_context, "has_context should be true");
    assert!(unpacked4.paymaster, "paymaster should be true");
}

// =============================================================================
// COLLISION PROTECTION TESTS
// =============================================================================

#[test]
fn test_different_tx_hash_different_ids() {
    // Same parameters except tx_hash should produce different token IDs
    let packed1 = pack_token_id(1, 1, 1, 1000, 0, 0, 0, false, false, false, 100, 0, 0);
    let packed2 = pack_token_id(1, 1, 1, 1000, 0, 0, 0, false, false, false, 200, 0, 0);

    assert!(packed1 != packed2, "Different tx_hash should produce different token IDs");
}

#[test]
fn test_different_salt_different_ids() {
    // Same parameters except salt should produce different token IDs (multicall scenario)
    let packed1 = pack_token_id(1, 1, 1, 1000, 0, 0, 0, false, false, false, 100, 0, 0);
    let packed2 = pack_token_id(1, 1, 1, 1000, 0, 0, 0, false, false, false, 100, 1, 0);
    let packed3 = pack_token_id(1, 1, 1, 1000, 0, 0, 0, false, false, false, 100, 2, 0);

    assert!(packed1 != packed2, "Different salt should produce different token IDs");
    assert!(packed2 != packed3, "Different salt should produce different token IDs");
    assert!(packed1 != packed3, "Different salt should produce different token IDs");
}

#[test]
fn test_multicall_simulation() {
    // Simulate minting 10 tokens in one transaction (same tx_hash, different salts)
    let tx_hash: u16 = 512;
    let game_id: u32 = 1;
    let minted_by: u64 = 1;
    let minted_at: u64 = 1704067200;

    let mut token_ids: Array<felt252> = array![];
    let mut i: u16 = 0;
    while i < 10 {
        let token_id = pack_token_id(
            game_id, minted_by, 0, minted_at, 0, 0, 0, false, false, false, tx_hash, i, // salt
            0,
        );
        token_ids.append(token_id);
        i += 1;
    }

    // Verify all token IDs are unique
    let mut j: u32 = 0;
    while j < 10 {
        let mut k: u32 = j + 1;
        while k < 10 {
            assert!(
                *token_ids.at(j) != *token_ids.at(k), "Token IDs should be unique within multicall",
            );
            k += 1;
        }
        j += 1;
    };
}

// =============================================================================
// EDGE CASES
// =============================================================================

#[test]
fn test_all_fields_set() {
    // Set all fields to non-zero values
    let packed = pack_token_id(
        1, // game_id
        2, // minted_by
        3, // settings_id
        4, // minted_at
        5, // start_delay
        6, // end_delay
        7, // objective_id
        true, // soulbound
        true, // has_context
        true, // paymaster
        8, // tx_hash
        9, // salt
        10 // metadata
    );

    let unpacked = unpack_token_id(packed);

    assert!(unpacked.game_id == 1, "game_id mismatch");
    assert!(unpacked.minted_by == 2, "minted_by mismatch");
    assert!(unpacked.settings_id == 3, "settings_id mismatch");
    assert!(unpacked.minted_at == 4, "minted_at mismatch");
    assert!(unpacked.start_delay == 5, "start_delay mismatch");
    assert!(unpacked.end_delay == 6, "end_delay mismatch");
    assert!(unpacked.objective_id == 7, "objective_id mismatch");
    assert!(unpacked.soulbound, "soulbound mismatch");
    assert!(unpacked.has_context, "has_context mismatch");
    assert!(unpacked.paymaster, "paymaster mismatch");
    assert!(unpacked.tx_hash == 8, "tx_hash mismatch");
    assert!(unpacked.salt == 9, "salt mismatch");
    assert!(unpacked.metadata == 10, "metadata mismatch");
}

#[test]
fn test_realistic_token_id() {
    // Simulate a realistic token creation scenario
    let game_id: u32 = 1; // First registered game
    let minted_by: u64 = 1; // First minter (metagame contract)
    let settings_id: u32 = 0; // Default settings
    let minted_at: u64 = 1704067200; // Jan 1, 2024
    let start_delay: u32 = 0; // Start immediately
    let end_delay: u32 = 31536000; // 1 year duration
    let objective_id: u32 = 5;
    let soulbound: bool = false;
    let has_context: bool = true; // Part of a tournament
    let paymaster: bool = false;
    let tx_hash: u16 = 512; // From transaction hash
    let salt: u16 = 0; // First mint in this tx
    let metadata: u16 = 0;

    let packed = pack_token_id(
        game_id,
        minted_by,
        settings_id,
        minted_at,
        start_delay,
        end_delay,
        objective_id,
        soulbound,
        has_context,
        paymaster,
        tx_hash,
        salt,
        metadata,
    );

    // Verify all fields can be retrieved correctly
    assert!(unpack_game_id(packed) == game_id, "game_id lookup failed");
    assert!(unpack_minted_by(packed) == minted_by, "minted_by lookup failed");
    assert!(unpack_settings_id(packed) == settings_id, "settings_id lookup failed");
    assert!(unpack_minted_at(packed) == minted_at, "minted_at lookup failed");
    assert!(unpack_start_delay(packed) == start_delay, "start_delay lookup failed");
    assert!(unpack_end_delay(packed) == end_delay, "end_delay lookup failed");
    assert!(unpack_objective_id(packed) == objective_id, "objective_id lookup failed");
    assert!(unpack_soulbound(packed) == soulbound, "soulbound lookup failed");
    assert!(unpack_has_context(packed) == has_context, "has_context lookup failed");
    assert!(unpack_paymaster(packed) == paymaster, "paymaster lookup failed");
    assert!(unpack_tx_hash(packed) == tx_hash, "tx_hash lookup failed");
    assert!(unpack_salt(packed) == salt, "salt lookup failed");
    assert!(unpack_metadata(packed) == metadata, "metadata lookup failed");
}

#[test]
fn test_tx_hash_overflow_masked() {
    // Verify that values larger than 10 bits are properly masked
    let large_tx_hash: u16 = 2048; // 11 bits (larger than 10-bit max)
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, large_tx_hash, 0, 0);
    let unpacked = unpack_token_id(packed);

    // Should be masked to 10 bits: 2048 & 0x3FF = 0
    assert!(unpacked.tx_hash == 0, "tx_hash should be masked to 10 bits");
}

#[test]
fn test_salt_overflow_masked() {
    // Verify that values larger than 10 bits are properly masked
    let large_salt: u16 = 1500; // Larger than 10-bit max (1023)
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, large_salt, 0);
    let unpacked = unpack_token_id(packed);

    // Should be masked to 10 bits: 1500 & 0x3FF = 476
    assert!(unpacked.salt == 476, "salt should be masked to 10 bits");
}

#[test]
fn test_metadata_overflow_masked() {
    // Verify that values larger than 13 bits are properly masked
    let large_metadata: u16 = 10000; // Larger than 13-bit max (8191)
    let packed = pack_token_id(0, 0, 0, 0, 0, 0, 0, false, false, false, 0, 0, large_metadata);
    let unpacked = unpack_token_id(packed);

    // Should be masked to 13 bits: 10000 & 0x1FFF = 1808
    assert!(unpacked.metadata == 1808, "metadata should be masked to 13 bits");
}
