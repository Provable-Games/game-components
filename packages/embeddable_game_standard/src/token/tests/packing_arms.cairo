// REJECTED ARMS — accessor shapes that were measured and NOT shipped.
//
// Test-only. Each function computes the SAME field from the SAME bit layout as
// both the v2.7.0 arm and the shipped implementation; only the instruction mix
// differs. They are kept so the per-accessor gas table in the PR stays
// reproducible: `bench_packing.cairo` benches these next to the shipped code in
// the same snforge run, which is what turns "we rejected X" into a number
// anyone can re-derive rather than a claim.
//
// Summary of why each lost (sierra gas, probe row, scarb 2.16.1 / snforge
// 0.58.1):
//   *_a  all-u128 DivRem pairs .......... never better than the shipped
//                                          DivRem + mask form
//   minted_by_a/b/c ..................... 20,080 / 19,883 / 18,983 vs the
//                                          shipped 18,130 — minted_by returns
//                                          u64, so narrowing early is free
//   soulbound_a/b ....................... 16,333 / 16,630 vs the shipped
//                                          15,830 — a DivRem at bit 127
//                                          already yields 0/1
//   unpack_token_id_a/b/c/d ............. 71,210 / 69,800 / 70,600 / 72,546
//                                          vs the shipped 69,190 — the full
//                                          unpack has enough u64 DivRems after
//                                          its narrowing to amortise it

mod nz {
    pub const P1: NonZero<u128> = 0x2;
    pub const P10: NonZero<u128> = 0x400;
    pub const P16: NonZero<u128> = 0x10000;
    pub const P25: NonZero<u128> = 0x2000000;
    pub const P26: NonZero<u128> = 0x4000000;
    pub const P27: NonZero<u128> = 0x8000000;
    pub const P28: NonZero<u128> = 0x10000000;
    pub const P30: NonZero<u128> = 0x40000000;
    pub const P35: NonZero<u128> = 0x800000000;
    pub const P58: NonZero<u128> = 0x400000000000000;
    pub const P60: NonZero<u128> = 0x1000000000000000;
    pub const P85: NonZero<u128> = 0x2000000000000000000000;
    pub const P101: NonZero<u128> = 0x20000000000000000000000000;
    pub const P127: NonZero<u128> = 0x80000000000000000000000000000000;
}

mod mask {
    pub const M10: u128 = 0x3FF;
    pub const M16: u128 = 0xFFFF;
    pub const M25: u128 = 0x1FFFFFF;
    pub const M26: u128 = 0x3FFFFFF;
    pub const M30: u128 = 0x3FFFFFFF;
    pub const M35: u128 = 0x7FFFFFFFF;
    pub const M60: u128 = 0xFFFFFFFFFFFFFFF;
    pub const BIT26: u128 = 0x4000000;
    pub const BIT27: u128 = 0x8000000;
    pub const BIT127: u128 = 0x80000000000000000000000000000000;
}

// ---------------- minted_at (low 0-34) ----------------
#[inline(always)]
pub fn minted_at_a(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    (packed.low & mask::M35).try_into().unwrap()
}

// ---------------- start_delay (low 35-59) ----------------
#[inline(always)]
pub fn start_delay_a(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (rest, _) = DivRem::div_rem(packed.low, nz::P35);
    let (_, start_delay) = DivRem::div_rem(rest, nz::P25);
    start_delay.try_into().unwrap()
}

#[inline(always)]
pub fn start_delay_b(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (rest, _) = DivRem::div_rem(packed.low, nz::P35);
    (rest & mask::M25).try_into().unwrap()
}

#[inline(always)]
pub fn start_delay_c(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let word = packed.low & mask::M60;
    let (start_delay, _) = DivRem::div_rem(word, nz::P35);
    start_delay.try_into().unwrap()
}

// ---------------- end_delay (low 60-84) ----------------
#[inline(always)]
pub fn end_delay_b(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (rest, _) = DivRem::div_rem(packed.low, nz::P60);
    (rest & mask::M25).try_into().unwrap()
}

// ---------------- settings_id (low 85-100) ----------------
#[inline(always)]
pub fn settings_id_a(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (top, _) = DivRem::div_rem(packed.low, nz::P85);
    let (_, settings_id) = DivRem::div_rem(top, nz::P16);
    settings_id.try_into().unwrap()
}

#[inline(always)]
pub fn settings_id_b(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (top, _) = DivRem::div_rem(packed.low, nz::P85);
    (top & mask::M16).try_into().unwrap()
}

// ---------------- minted_by (low 101-126) ----------------
#[inline(always)]
pub fn minted_by_a(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (top, _) = DivRem::div_rem(packed.low, nz::P101);
    let (_, minted_by) = DivRem::div_rem(top, nz::P26);
    minted_by.try_into().unwrap()
}

#[inline(always)]
pub fn minted_by_b(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (top, _) = DivRem::div_rem(packed.low, nz::P101);
    (top & mask::M26).try_into().unwrap()
}

#[inline(always)]
pub fn minted_by_c(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (top, _) = DivRem::div_rem(packed.low, nz::P101);
    let top: u64 = top.try_into().unwrap();
    top & 0x3FFFFFF
}

// ---------------- soulbound (low 127) ----------------
#[inline(always)]
pub fn soulbound_a(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    (packed.low & mask::BIT127) != 0
}

#[inline(always)]
pub fn soulbound_b(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (soulbound, _) = DivRem::div_rem(packed.low, nz::P127);
    soulbound != 0
}

// ---------------- tx_hash (high 0-9) ----------------
#[inline(always)]
pub fn tx_hash_a(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    (packed.high & mask::M10).try_into().unwrap()
}

// ---------------- salt (high 10-25) ----------------
#[inline(always)]
pub fn salt_a(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    let (rest, _) = DivRem::div_rem(packed.high, nz::P10);
    let (_, salt) = DivRem::div_rem(rest, nz::P16);
    salt.try_into().unwrap()
}

#[inline(always)]
pub fn salt_b(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    let (rest, _) = DivRem::div_rem(packed.high, nz::P10);
    (rest & mask::M16).try_into().unwrap()
}

// ---------------- paymaster (high 26) ----------------
#[inline(always)]
pub fn paymaster_a(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (rest, _) = DivRem::div_rem(packed.high, nz::P26);
    let (_, paymaster) = DivRem::div_rem(rest, nz::P1);
    paymaster == 1
}

#[inline(always)]
pub fn paymaster_b(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    (packed.high & mask::BIT26) != 0
}

// ---------------- has_context (high 27) ----------------
#[inline(always)]
pub fn has_context_a(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (rest, _) = DivRem::div_rem(packed.high, nz::P27);
    let (_, has_context) = DivRem::div_rem(rest, nz::P1);
    has_context == 1
}

#[inline(always)]
pub fn has_context_b(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    (packed.high & mask::BIT27) != 0
}

// ---------------- objective_id (high 28-57) ----------------
#[inline(always)]
pub fn objective_id_a(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (rest, _) = DivRem::div_rem(packed.high, nz::P28);
    let (_, objective_id) = DivRem::div_rem(rest, nz::P30);
    objective_id.try_into().unwrap()
}

#[inline(always)]
pub fn objective_id_b(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (rest, _) = DivRem::div_rem(packed.high, nz::P28);
    (rest & mask::M30).try_into().unwrap()
}

// ---------------- extract_tx_hash_bits ----------------
#[inline(always)]
pub fn extract_tx_hash_bits_a(tx_hash: felt252) -> u16 {
    let hash_u256: u256 = tx_hash.into();
    let (_, bits) = DivRem::div_rem(hash_u256.low, nz::P10);
    bits.try_into().unwrap()
}

#[inline(always)]
pub fn extract_tx_hash_bits_b(tx_hash: felt252) -> u16 {
    let hash_u256: u256 = tx_hash.into();
    (hash_u256.low & mask::M10).try_into().unwrap()
}

// ---------------- full unpack variants ----------------
use super::packing_v270::PackedTokenId;

mod nz64 {
    pub const P1: NonZero<u64> = 0x2;
    pub const P10: NonZero<u64> = 0x400;
    pub const P16: NonZero<u64> = 0x10000;
    pub const P26: NonZero<u64> = 0x4000000;
    pub const P28: NonZero<u64> = 0x10000000;
    pub const P35: NonZero<u64> = 0x800000000;
}

/// Arm A: both halves as straight u128 DivRem chains (no narrowing at all).
#[inline(always)]
pub fn unpack_token_id_a(token_id: felt252) -> PackedTokenId {
    let packed: u256 = token_id.into();
    let (rest, minted_at) = DivRem::div_rem(packed.low, nz::P35);
    let (rest, start_delay) = DivRem::div_rem(rest, nz::P25);
    let (rest, end_delay) = DivRem::div_rem(rest, nz::P25);
    let (rest, settings_id) = DivRem::div_rem(rest, nz::P16);
    let (soulbound, minted_by) = DivRem::div_rem(rest, nz::P26);

    let (rest, tx_hash) = DivRem::div_rem(packed.high, nz::P10);
    let (rest, salt) = DivRem::div_rem(rest, nz::P16);
    let (rest, paymaster) = DivRem::div_rem(rest, nz::P1);
    let (rest, has_context) = DivRem::div_rem(rest, nz::P1);
    let (metadata, objective_id) = DivRem::div_rem(rest, nz::P30);

    PackedTokenId {
        minted_at: minted_at.try_into().unwrap(),
        start_delay: start_delay.try_into().unwrap(),
        end_delay: end_delay.try_into().unwrap(),
        settings_id: settings_id.try_into().unwrap(),
        minted_by: minted_by.try_into().unwrap(),
        soulbound: soulbound == 1,
        tx_hash: tx_hash.try_into().unwrap(),
        salt: salt.try_into().unwrap(),
        paymaster: paymaster == 1,
        has_context: has_context == 1,
        objective_id: objective_id.try_into().unwrap(),
        metadata,
    }
}

/// Arm B: v2.7.0 low half, all-u128 high half.
#[inline(always)]
pub fn unpack_token_id_b(token_id: felt252) -> PackedTokenId {
    let packed: u256 = token_id.into();
    let (low_rest, low_word) = DivRem::div_rem(packed.low, nz::P60);
    let low_word: u64 = low_word.try_into().unwrap();
    let (start_delay, minted_at) = DivRem::div_rem(low_word, nz64::P35);
    let (low_top, end_delay) = DivRem::div_rem(low_rest, nz::P25);
    let low_top: u64 = low_top.try_into().unwrap();
    let (rest, settings_id) = DivRem::div_rem(low_top, nz64::P16);
    let (soulbound_u64, minted_by) = DivRem::div_rem(rest, nz64::P26);

    let (rest, tx_hash) = DivRem::div_rem(packed.high, nz::P10);
    let (rest, salt) = DivRem::div_rem(rest, nz::P16);
    let (rest, paymaster) = DivRem::div_rem(rest, nz::P1);
    let (rest, has_context) = DivRem::div_rem(rest, nz::P1);
    let (metadata, objective_id) = DivRem::div_rem(rest, nz::P30);

    PackedTokenId {
        minted_at,
        start_delay: start_delay.try_into().unwrap(),
        end_delay: end_delay.try_into().unwrap(),
        settings_id: settings_id.try_into().unwrap(),
        minted_by,
        soulbound: soulbound_u64 == 1,
        tx_hash: tx_hash.try_into().unwrap(),
        salt: salt.try_into().unwrap(),
        paymaster: paymaster == 1,
        has_context: has_context == 1,
        objective_id: objective_id.try_into().unwrap(),
        metadata,
    }
}

/// Arm C: all-u128 low half, v2.7.0 high half.
#[inline(always)]
pub fn unpack_token_id_c(token_id: felt252) -> PackedTokenId {
    let packed: u256 = token_id.into();
    let (rest, minted_at) = DivRem::div_rem(packed.low, nz::P35);
    let (rest, start_delay) = DivRem::div_rem(rest, nz::P25);
    let (rest, end_delay) = DivRem::div_rem(rest, nz::P25);
    let (rest, settings_id) = DivRem::div_rem(rest, nz::P16);
    let (soulbound, minted_by) = DivRem::div_rem(rest, nz::P26);

    let (metadata, high_word) = DivRem::div_rem(packed.high, nz::P58);
    let high_word: u64 = high_word.try_into().unwrap();
    let (hrest, tx_hash) = DivRem::div_rem(high_word, nz64::P10);
    let (hrest, salt) = DivRem::div_rem(hrest, nz64::P16);
    let (hrest, paymaster_u64) = DivRem::div_rem(hrest, nz64::P1);
    let (objective_id, has_context_u64) = DivRem::div_rem(hrest, nz64::P1);

    PackedTokenId {
        minted_at: minted_at.try_into().unwrap(),
        start_delay: start_delay.try_into().unwrap(),
        end_delay: end_delay.try_into().unwrap(),
        settings_id: settings_id.try_into().unwrap(),
        minted_by: minted_by.try_into().unwrap(),
        soulbound: soulbound == 1,
        tx_hash: tx_hash.try_into().unwrap(),
        salt: salt.try_into().unwrap(),
        paymaster: paymaster_u64 == 1,
        has_context: has_context_u64 == 1,
        objective_id: objective_id.try_into().unwrap(),
        metadata,
    }
}

/// Arm D: v2.7.0 shape, but the two 1-bit flag DivRems replaced by masks.
#[inline(always)]
pub fn unpack_token_id_d(token_id: felt252) -> PackedTokenId {
    let packed: u256 = token_id.into();
    let (low_rest, low_word) = DivRem::div_rem(packed.low, nz::P60);
    let low_word: u64 = low_word.try_into().unwrap();
    let (start_delay, minted_at) = DivRem::div_rem(low_word, nz64::P35);
    let (low_top, end_delay) = DivRem::div_rem(low_rest, nz::P25);
    let low_top: u64 = low_top.try_into().unwrap();
    let (rest, settings_id) = DivRem::div_rem(low_top, nz64::P16);
    let (soulbound_u64, minted_by) = DivRem::div_rem(rest, nz64::P26);

    let (metadata, high_word) = DivRem::div_rem(packed.high, nz::P58);
    let high_word: u64 = high_word.try_into().unwrap();
    let (hrest, tx_hash) = DivRem::div_rem(high_word, nz64::P10);
    let (hrest, salt) = DivRem::div_rem(hrest, nz64::P16);
    let (objective_id, flags) = DivRem::div_rem(hrest, 0x4);

    PackedTokenId {
        minted_at,
        start_delay: start_delay.try_into().unwrap(),
        end_delay: end_delay.try_into().unwrap(),
        settings_id: settings_id.try_into().unwrap(),
        minted_by,
        soulbound: soulbound_u64 == 1,
        tx_hash: tx_hash.try_into().unwrap(),
        salt: salt.try_into().unwrap(),
        paymaster: (flags & 0x1) != 0,
        has_context: (flags & 0x2) != 0,
        objective_id: objective_id.try_into().unwrap(),
        metadata,
    }
}
