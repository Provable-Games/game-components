// NAIVE REFERENCE DECODER — deliberately slow, deliberately obvious.
//
// It shares NO constants, no helper module and no structural idea with
// `crate::token::packing`: every field is addressed by its ABSOLUTE bit offset
// in the 251-bit word, extracted with whole-u256 shift-and-modulo, and every
// power of two is computed at runtime by repeated multiplication instead of
// being written down as a hex literal. There is no low/high split here, so a
// mistake in the shipped codec's half-splitting or masking cannot be mirrored
// by a matching mistake here.
//
// This never ships. It exists to disagree with the implementation.

/// Absolute bit offsets and widths, read straight off the layout table in
/// `packing.cairo`. (offset, width)
pub const MINTED_AT: (u32, u32) = (0, 35);
pub const START_DELAY: (u32, u32) = (35, 25);
pub const END_DELAY: (u32, u32) = (60, 25);
pub const SETTINGS_ID: (u32, u32) = (85, 16);
pub const MINTED_BY: (u32, u32) = (101, 26);
pub const SOULBOUND: (u32, u32) = (127, 1);
pub const TX_HASH: (u32, u32) = (128, 10);
pub const SALT: (u32, u32) = (138, 16);
pub const PAYMASTER: (u32, u32) = (154, 1);
pub const HAS_CONTEXT: (u32, u32) = (155, 1);
pub const OBJECTIVE_ID: (u32, u32) = (156, 30);
pub const METADATA: (u32, u32) = (186, 65);

/// 2^n as a u256, built by repeated multiplication so no shift constant is
/// shared with the code under test.
pub fn two_pow(n: u32) -> u256 {
    let mut result: u256 = 1;
    let mut i: u32 = 0;
    while i < n {
        result = result * 2;
        i += 1;
    }
    result
}

/// The whole point: `(id >> offset) & ((1 << width) - 1)`, written the slow way.
pub fn field(token_id: felt252, spec: (u32, u32)) -> u256 {
    let (offset, width) = spec;
    let value: u256 = token_id.into();
    (value / two_pow(offset)) % two_pow(width)
}

pub fn flag(token_id: felt252, spec: (u32, u32)) -> bool {
    field(token_id, spec) == 1
}

/// Naive packer: place each field at its absolute offset and add. Independent
/// of the shipped packer's felt252 accumulation.
pub fn pack(
    minted_at: u64,
    start_delay: u32,
    end_delay: u32,
    settings_id: u32,
    minted_by: u64,
    soulbound: bool,
    tx_hash: u16,
    salt: u16,
    paymaster: bool,
    has_context: bool,
    objective_id: u32,
    metadata: u128,
) -> felt252 {
    let b = |flag: bool| -> u256 {
        if flag {
            1
        } else {
            0
        }
    };
    let (o, _) = MINTED_AT;
    let mut acc: u256 = minted_at.into() * two_pow(o);
    let (o, _) = START_DELAY;
    acc += start_delay.into() * two_pow(o);
    let (o, _) = END_DELAY;
    acc += end_delay.into() * two_pow(o);
    let (o, _) = SETTINGS_ID;
    acc += settings_id.into() * two_pow(o);
    let (o, _) = MINTED_BY;
    acc += minted_by.into() * two_pow(o);
    let (o, _) = SOULBOUND;
    acc += b(soulbound) * two_pow(o);
    let (o, _) = TX_HASH;
    acc += tx_hash.into() * two_pow(o);
    let (o, _) = SALT;
    acc += salt.into() * two_pow(o);
    let (o, _) = PAYMASTER;
    acc += b(paymaster) * two_pow(o);
    let (o, _) = HAS_CONTEXT;
    acc += b(has_context) * two_pow(o);
    let (o, _) = OBJECTIVE_ID;
    acc += objective_id.into() * two_pow(o);
    let (o, _) = METADATA;
    acc += metadata.into() * two_pow(o);
    acc.try_into().unwrap()
}
