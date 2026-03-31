use crate::entry_requirement::structs::{EntryRequirementMeta, EntryRequirementMetaStorePacking};

// ============================================================================
// StorePacking roundtrip tests
// ============================================================================

#[test]
fn test_pack_unpack_token_type() {
    let meta = EntryRequirementMeta { entry_limit: 10, req_type: 0 };
    let packed = EntryRequirementMetaStorePacking::pack(meta);
    let unpacked = EntryRequirementMetaStorePacking::unpack(packed);
    assert!(unpacked.entry_limit == 10, "entry_limit mismatch");
    assert!(unpacked.req_type == 0, "req_type mismatch");
}

#[test]
fn test_pack_unpack_extension_type() {
    let meta = EntryRequirementMeta { entry_limit: 100, req_type: 1 };
    let packed = EntryRequirementMetaStorePacking::pack(meta);
    let unpacked = EntryRequirementMetaStorePacking::unpack(packed);
    assert!(unpacked.entry_limit == 100, "entry_limit mismatch");
    assert!(unpacked.req_type == 1, "req_type mismatch");
}

#[test]
fn test_pack_unpack_none_type() {
    let meta = EntryRequirementMeta { entry_limit: 0, req_type: 255 };
    let packed = EntryRequirementMetaStorePacking::pack(meta);
    let unpacked = EntryRequirementMetaStorePacking::unpack(packed);
    assert!(unpacked.entry_limit == 0, "entry_limit mismatch");
    assert!(unpacked.req_type == 255, "req_type mismatch");
}

#[test]
fn test_pack_unpack_max_entry_limit() {
    let meta = EntryRequirementMeta { entry_limit: 0xFFFFFFFF, req_type: 0 };
    let packed = EntryRequirementMetaStorePacking::pack(meta);
    let unpacked = EntryRequirementMetaStorePacking::unpack(packed);
    assert!(unpacked.entry_limit == 0xFFFFFFFF, "entry_limit mismatch");
    assert!(unpacked.req_type == 0, "req_type mismatch");
}

#[test]
fn test_pack_unpack_zero_values() {
    let meta = EntryRequirementMeta { entry_limit: 0, req_type: 0 };
    let packed = EntryRequirementMetaStorePacking::pack(meta);
    assert!(packed == 0, "packed zero values should be 0");
    let unpacked = EntryRequirementMetaStorePacking::unpack(packed);
    assert!(unpacked.entry_limit == 0, "entry_limit mismatch");
    assert!(unpacked.req_type == 0, "req_type mismatch");
}

#[test]
fn test_pack_format_token_type() {
    // Verify: packed = (entry_limit * 0x100) + req_type
    let meta = EntryRequirementMeta { entry_limit: 10, req_type: 0 };
    let packed = EntryRequirementMetaStorePacking::pack(meta);
    assert!(packed == 10 * 0x100 + 0, "packed format mismatch for token type");
}

#[test]
fn test_pack_format_extension_type() {
    let meta = EntryRequirementMeta { entry_limit: 5, req_type: 1 };
    let packed = EntryRequirementMetaStorePacking::pack(meta);
    assert!(packed == 5 * 0x100 + 1, "packed format mismatch for extension type");
}

#[test]
fn test_pack_format_none_type() {
    let meta = EntryRequirementMeta { entry_limit: 0, req_type: 255 };
    let packed = EntryRequirementMetaStorePacking::pack(meta);
    assert!(packed == 255, "packed format mismatch for none type");
}

#[test]
fn test_pack_unpack_max_values() {
    // Max entry_limit with max req_type
    let meta = EntryRequirementMeta { entry_limit: 0xFFFFFFFF, req_type: 255 };
    let packed = EntryRequirementMetaStorePacking::pack(meta);
    let unpacked = EntryRequirementMetaStorePacking::unpack(packed);
    assert!(unpacked.entry_limit == 0xFFFFFFFF, "entry_limit mismatch");
    assert!(unpacked.req_type == 255, "req_type mismatch");
}
