// `unpack_lifecycle` is the guard's hot path: it must agree with the full
// decoder for every felt, not just for ids the packer can produce.
use crate::token::packing::{
    PackedTokenId, SCHEMA_VERSION, pack_token_id, to_token_metadata, unpack_lifecycle,
    unpack_token_id,
};

fn assert_matches_full_decoder(id: felt252) {
    let projected = unpack_lifecycle(id);
    let reference = to_token_metadata(unpack_token_id(id)).lifecycle;
    assert!(projected.start == reference.start, "start projection differs from full decoder");
    assert!(projected.end == reference.end, "end projection differs from full decoder");
}

fn fields(minted_at_timestamp: u32, start_delay: u32, end_delay: u32) -> PackedTokenId {
    PackedTokenId {
        schema_version: SCHEMA_VERSION,
        has_context: true,
        soulbound: true,
        paymaster: true,
        tx_hash: 0xFFFF,
        tx_nonce: 0xFF,
        minted_at_block_number: 0xFFFFFFFF,
        minted_at_timestamp,
        start_delay,
        end_delay,
        settings_id: 0xFFFFF,
        objective_id: 0xFFFFF,
        minted_by: 0xFFFFFF,
        metadata: 0x7FFFFFFFFFFFFFF,
    }
}

#[test]
#[fuzzer(runs: 256)]
fn projection_matches_full_decoder_for_arbitrary_felts(id: felt252) {
    assert_matches_full_decoder(id);
}

#[test]
fn projection_matches_at_field_boundaries_and_maximum_felt() {
    // Low-half field edges: the top of the bottom word (bit 63), the
    // timestamp field (bits 64-90), start_delay (91-108), end_delay
    // (109-127), then the whole low half and the largest felts.
    for id in array![
        0, 1, 0xffffffffffffffff, 0x10000000000000000, 0x7ffffff0000000000000000,
        0x80000000000000000000000, 0x1ffffffffffffffffffffffffffff, 0x2000000000000000000000000000,
        0xffffffffffffffffffffffffffffffff,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x800000000000011000000000000000000000000000000000000000000000000,
    ] {
        assert_matches_full_decoder(id);
    }
}

#[test]
fn projection_reconstructs_maximum_relative_timestamps() {
    let id = pack_token_id(fields(0x7FFFFFF, 0x3FFFF, 0x7FFFF));
    let lifecycle = unpack_lifecycle(id);
    // (2^27 - 1 + 2^18 - 1) * 60 and + (2^19 - 1) * 60
    assert!(lifecycle.start == 8_068_792_200, "maximum start must include minted_at");
    assert!(lifecycle.end == 8_100_249_420, "maximum end must include both delays");
    assert_matches_full_decoder(id);
}

#[test]
fn zero_end_delay_remains_immortal_even_at_maximum_start() {
    let id = pack_token_id(fields(0x7FFFFFF, 0x3FFFF, 0));
    let lifecycle = unpack_lifecycle(id);
    assert!(lifecycle.start == 8_068_792_200, "maximum start must include minted_at");
    assert!(lifecycle.end == 0, "zero end delay must remain immortal");
}

#[test]
fn projection_scales_minutes_to_seconds() {
    let id = pack_token_id(fields(16_666_667, 1, 1));
    let lifecycle = unpack_lifecycle(id);
    assert!(lifecycle.start == 1_000_000_080, "start = (ts + start_delay) * 60");
    assert!(lifecycle.end == 1_000_000_140, "end = start + end_delay * 60");
}
