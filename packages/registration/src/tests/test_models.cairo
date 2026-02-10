use crate::models::{RegistrationData, RegistrationDataStorePacking};

// ============================================================================
// StorePacking roundtrip tests
// ============================================================================

#[test]
fn test_pack_unpack_roundtrip_basic() {
    let data = RegistrationData {
        context_id: 42, entry_number: 7, has_submitted: false, is_banned: false,
    };

    let packed = RegistrationDataStorePacking::pack(data);
    let unpacked = RegistrationDataStorePacking::unpack(packed);

    assert!(unpacked.context_id == 42, "context_id mismatch");
    assert!(unpacked.entry_number == 7, "entry_number mismatch");
    assert!(!unpacked.has_submitted, "has_submitted should be false");
    assert!(!unpacked.is_banned, "is_banned should be false");
}

#[test]
fn test_pack_unpack_roundtrip_with_flags() {
    let data = RegistrationData {
        context_id: 100, entry_number: 50, has_submitted: true, is_banned: true,
    };

    let packed = RegistrationDataStorePacking::pack(data);
    let unpacked = RegistrationDataStorePacking::unpack(packed);

    assert!(unpacked.context_id == 100, "context_id mismatch");
    assert!(unpacked.entry_number == 50, "entry_number mismatch");
    assert!(unpacked.has_submitted, "has_submitted should be true");
    assert!(unpacked.is_banned, "is_banned should be true");
}

#[test]
fn test_pack_unpack_roundtrip_max_values() {
    let max_u64: u64 = 0xFFFFFFFFFFFFFFFF;
    let max_u32: u32 = 0xFFFFFFFF;

    let data = RegistrationData {
        context_id: max_u64, entry_number: max_u32, has_submitted: true, is_banned: true,
    };

    let packed = RegistrationDataStorePacking::pack(data);
    let unpacked = RegistrationDataStorePacking::unpack(packed);

    assert!(unpacked.context_id == max_u64, "context_id max mismatch");
    assert!(unpacked.entry_number == max_u32, "entry_number max mismatch");
    assert!(unpacked.has_submitted, "has_submitted should be true");
    assert!(unpacked.is_banned, "is_banned should be true");
}

#[test]
fn test_pack_unpack_only_submitted() {
    let data = RegistrationData {
        context_id: 999, entry_number: 1, has_submitted: true, is_banned: false,
    };

    let packed = RegistrationDataStorePacking::pack(data);
    let unpacked = RegistrationDataStorePacking::unpack(packed);

    assert!(unpacked.context_id == 999, "context_id mismatch");
    assert!(unpacked.entry_number == 1, "entry_number mismatch");
    assert!(unpacked.has_submitted, "has_submitted should be true");
    assert!(!unpacked.is_banned, "is_banned should be false");
}

#[test]
fn test_pack_unpack_only_banned() {
    let data = RegistrationData {
        context_id: 888, entry_number: 3, has_submitted: false, is_banned: true,
    };

    let packed = RegistrationDataStorePacking::pack(data);
    let unpacked = RegistrationDataStorePacking::unpack(packed);

    assert!(unpacked.context_id == 888, "context_id mismatch");
    assert!(unpacked.entry_number == 3, "entry_number mismatch");
    assert!(!unpacked.has_submitted, "has_submitted should be false");
    assert!(unpacked.is_banned, "is_banned should be true");
}

#[test]
fn test_pack_unpack_zero_values() {
    let data = RegistrationData {
        context_id: 0, entry_number: 0, has_submitted: false, is_banned: false,
    };

    let packed = RegistrationDataStorePacking::pack(data);
    assert!(packed == 0, "packed zero data should be 0");

    let unpacked = RegistrationDataStorePacking::unpack(packed);

    assert!(unpacked.context_id == 0, "context_id should be 0");
    assert!(unpacked.entry_number == 0, "entry_number should be 0");
    assert!(!unpacked.has_submitted, "has_submitted should be false");
    assert!(!unpacked.is_banned, "is_banned should be false");
}

// ============================================================================
// Bit layout verification tests
// ============================================================================

#[test]
fn test_pack_bit_layout_context_id_in_low_bits() {
    // context_id occupies bits 0..63
    let data = RegistrationData {
        context_id: 1, entry_number: 0, has_submitted: false, is_banned: false,
    };
    let packed = RegistrationDataStorePacking::pack(data);
    assert!(packed == 1, "context_id=1 should pack to 1");
}

#[test]
fn test_pack_bit_layout_entry_number_offset() {
    // entry_number occupies bits 64..95 (shifted by TWO_POW_64)
    let data = RegistrationData {
        context_id: 0, entry_number: 1, has_submitted: false, is_banned: false,
    };
    let packed = RegistrationDataStorePacking::pack(data);
    // 1 * 2^64 = 0x10000000000000000
    assert!(packed == 0x10000000000000000, "entry_number=1 should be at bit 64");
}

#[test]
fn test_pack_bit_layout_has_submitted_offset() {
    // has_submitted at bit 96 (TWO_POW_64 * TWO_POW_32)
    let data = RegistrationData {
        context_id: 0, entry_number: 0, has_submitted: true, is_banned: false,
    };
    let packed = RegistrationDataStorePacking::pack(data);
    // 2^96 = 0x1000000000000000000000000
    assert!(packed == 0x1000000000000000000000000, "has_submitted should be at bit 96");
}

#[test]
fn test_pack_bit_layout_is_banned_offset() {
    // is_banned at bit 97 (TWO_POW_64 * TWO_POW_32 * 2)
    let data = RegistrationData {
        context_id: 0, entry_number: 0, has_submitted: false, is_banned: true,
    };
    let packed = RegistrationDataStorePacking::pack(data);
    // 2^97 = 0x2000000000000000000000000
    assert!(packed == 0x2000000000000000000000000, "is_banned should be at bit 97");
}

#[test]
fn test_pack_flags_are_independent() {
    // Verify that has_submitted and is_banned bits do not interfere
    let submitted_only = RegistrationData {
        context_id: 0, entry_number: 0, has_submitted: true, is_banned: false,
    };
    let banned_only = RegistrationData {
        context_id: 0, entry_number: 0, has_submitted: false, is_banned: true,
    };
    let both = RegistrationData {
        context_id: 0, entry_number: 0, has_submitted: true, is_banned: true,
    };

    let packed_submitted = RegistrationDataStorePacking::pack(submitted_only);
    let packed_banned = RegistrationDataStorePacking::pack(banned_only);
    let packed_both = RegistrationDataStorePacking::pack(both);

    assert!(
        packed_both == packed_submitted + packed_banned,
        "both flags packed should equal sum of individual flag packs",
    );
}
