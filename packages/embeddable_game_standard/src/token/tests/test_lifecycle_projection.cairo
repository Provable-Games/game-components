use crate::token::packing::{pack_token_id, to_token_metadata, unpack_lifecycle, unpack_token_id};

fn assert_matches_full_decoder(id: felt252) {
    let projected = unpack_lifecycle(id);
    let reference = to_token_metadata(unpack_token_id(id)).lifecycle;
    assert!(projected.start == reference.start, "start projection differs from full decoder");
    assert!(projected.end == reference.end, "end projection differs from full decoder");
}

#[test]
#[fuzzer(runs: 256)]
fn projection_matches_full_decoder_for_arbitrary_felts(id: felt252) {
    assert_matches_full_decoder(id);
}

#[test]
fn projection_matches_at_field_boundaries_and_maximum_felt() {
    for id in array![
        0, 1, 0x7ffffffff, 0x800000000, 0xfffffffffffffff, 0x1000000000000000,
        0x1fffffffffffffffffffff, 0x2000000000000000000000, 0xffffffffffffffffffffffffffffffff,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x800000000000011000000000000000000000000000000000000000000000000,
    ] {
        assert_matches_full_decoder(id);
    }
}

#[test]
fn projection_reconstructs_maximum_relative_timestamps() {
    let id = pack_token_id(
        0x7ffffffff,
        0x1ffffff,
        0x1ffffff,
        0xffff,
        0x3ffffff,
        true,
        0x3ff,
        0xffff,
        true,
        true,
        0x3fffffff,
        0x1ffffffffffffffff,
    );
    let lifecycle = unpack_lifecycle(id);
    assert!(lifecycle.start == 34_393_292_798, "maximum start must include minted_at");
    assert!(lifecycle.end == 34_426_847_229, "maximum end must include both delays");
    assert_matches_full_decoder(id);
}

#[test]
fn zero_end_delay_remains_immortal_even_at_maximum_start() {
    let id = pack_token_id(0x7ffffffff, 0x1ffffff, 0, 1, 1, false, 0, 0, false, false, 0, 0);
    let lifecycle = unpack_lifecycle(id);
    assert!(lifecycle.start == 34_393_292_798, "maximum start must include minted_at");
    assert!(lifecycle.end == 0, "zero end delay must remain immortal");
}
