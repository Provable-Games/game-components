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

/// `2^n` as a u256, built by repeated multiplication so no shift constant is
/// shared with the code under test.
///
/// * `n` — exponent; must be <= 255, or the u256 multiply overflows and panics.
///   Call sites pass field offsets and widths from the table above (max 251).
///
/// Returns `2^n`. Deliberately O(n) — this is a reference, not production code.
///
/// ```
/// assert!(two_pow(0) == 1);
/// assert!(two_pow(10) == 0x400);
/// ```
pub fn two_pow(n: u32) -> u256 {
    let mut result: u256 = 1;
    let mut i: u32 = 0;
    while i < n {
        result = result * 2;
        i += 1;
    }
    result
}

/// The whole point: `(id >> offset) & ((1 << width) - 1)`, written the slow way
/// as division and modulo over the WHOLE 251-bit value — no u128 half-split, so
/// it cannot repeat a half-splitting mistake made by the code under test.
///
/// * `token_id` — any felt252; no validity precondition, arbitrary bit patterns
///   are meaningful input.
/// * `spec` — `(offset, width)` from the constants above; `offset + width` must
///   be <= 251.
///
/// Returns the field's value, zero-extended into a u256.
///
/// ```
/// // salt lives at bits 138..153
/// let salt: u16 = field(token_id, SALT).try_into().unwrap();
/// ```
pub fn field(token_id: felt252, spec: (u32, u32)) -> u256 {
    let (offset, width) = spec;
    let value: u256 = token_id.into();
    (value / two_pow(offset)) % two_pow(width)
}

/// `field`, for the three single-bit fields.
///
/// * `token_id` — any felt252.
/// * `spec` — a `(offset, 1)` spec: `SOULBOUND`, `PAYMASTER` or `HAS_CONTEXT`.
///
/// Returns true when the bit is set.
pub fn flag(token_id: felt252, spec: (u32, u32)) -> bool {
    field(token_id, spec) == 1
}

/// Naive packer: place each field at its absolute offset and add, in u256.
/// Independent of the shipped packer's felt252 accumulation.
///
/// Unlike `packing::pack_token_id` this asserts nothing and masks nothing — an
/// over-wide field simply collides with its neighbour and the result diverges,
/// which is what makes it useful as a differential reference. Callers must
/// therefore respect every width themselves:
///
/// * `minted_at` <= 2^35-1, `start_delay` / `end_delay` <= 2^25-1,
///   `settings_id` <= 2^16-1, `minted_by` <= 2^26-1, `tx_hash` <= 2^10-1,
///   `salt` <= 2^16-1, `objective_id` <= 2^30-1, `metadata` <= 2^65-1.
/// * `soulbound`, `paymaster`, `has_context` — one bit each.
///
/// Returns the packed 251-bit id as a felt252; panics if the accumulated value
/// does not fit felt252, which can only happen if a width was violated.
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
