// SPDX-License-Identifier: BUSL-1.1

//! Packed storage for dynamic-length `u16` share arrays.
//!
//! A single `felt252` slot holds up to `SHARES_PER_SLOT` (15) shares, each
//! occupying 16 bits. Multi-slot arrays are stored as
//! `Map<(key, slot_index: u8), CustomShares>` in the consuming component,
//! paired with a length counter. This yields ~15x fewer storage ops than a
//! plain `Vec<u16>` for typical payout-distribution sizes.
//!
//! This module is storage-agnostic: it exposes the pure packing math and the
//! `CustomShares` wrapper. Components wire up their own `Map` + length
//! counter.

/// Number of `u16` shares packed per `felt252` storage slot.
/// Each share = 16 bits; felt252 = 252 bits; 15 * 16 = 240 bits fits.
pub const SHARES_PER_SLOT: u8 = 15;

const MASK_16: u256 = 0xFFFF;

/// 2^exp for the exponents used in 16-bit share packing (0, 16, 32, ..., 224).
/// Returns an iterative fallback for unexpected inputs, but valid callers only
/// use index * 16 where index is 0..14.
pub fn pow_2_u256_16(exp: u256) -> u256 {
    if exp == 0 {
        return 1;
    }
    if exp == 16 {
        return 0x10000;
    }
    if exp == 32 {
        return 0x100000000;
    }
    if exp == 48 {
        return 0x1000000000000;
    }
    if exp == 64 {
        return 0x10000000000000000;
    }
    if exp == 80 {
        return 0x100000000000000000000;
    }
    if exp == 96 {
        return 0x1000000000000000000000000;
    }
    if exp == 112 {
        return 0x10000000000000000000000000000;
    }
    if exp == 128 {
        return 0x100000000000000000000000000000000;
    }
    if exp == 144 {
        return 0x1000000000000000000000000000000000000;
    }
    if exp == 160 {
        return 0x10000000000000000000000000000000000000000;
    }
    if exp == 176 {
        return 0x100000000000000000000000000000000000000000000;
    }
    if exp == 192 {
        return 0x1000000000000000000000000000000000000000000000000;
    }
    if exp == 208 {
        return 0x10000000000000000000000000000000000000000000000000000;
    }
    if exp == 224 {
        return 0x100000000000000000000000000000000000000000000000000000000;
    }
    let mut result: u256 = 1;
    let mut i: u256 = 0;
    while i < exp {
        result = result * 2;
        i += 1;
    }
    result
}

/// Extract the 16-bit share at `index` (0..14) from a packed `u256`.
pub fn get_packed_share(packed: u256, index: u8) -> u16 {
    assert!(index < SHARES_PER_SLOT, "Index out of bounds");
    let shift: u256 = (index.into() * 16_u32).into();
    let divisor: u256 = pow_2_u256_16(shift);
    let value: u256 = (packed / divisor) & MASK_16;
    value.try_into().unwrap()
}

/// Overwrite the 16-bit share at `index` (0..14) and return the new packed
/// value.
pub fn set_packed_share(packed: u256, index: u8, share: u16) -> u256 {
    assert!(index < SHARES_PER_SLOT, "Index out of bounds");
    let shift: u256 = (index.into() * 16_u32).into();
    let multiplier: u256 = pow_2_u256_16(shift);
    let mask: u256 = MASK_16 * multiplier;
    let shifted_value: u256 = share.into() * multiplier;
    (packed & ~mask) | shifted_value
}

/// Given a logical share index, return `(slot_index, index_within_slot)`.
pub fn calculate_slot_position(share_index: u32) -> (u8, u8) {
    let slot_index: u8 = (share_index / SHARES_PER_SLOT.into()).try_into().unwrap();
    let index_in_slot: u8 = (share_index % SHARES_PER_SLOT.into()).try_into().unwrap();
    (slot_index, index_in_slot)
}

/// Number of storage slots required for a dense array of `share_count` shares.
pub fn calculate_slots_needed(share_count: u32) -> u8 {
    if share_count == 0 {
        return 0;
    }
    let slots = (share_count + SHARES_PER_SLOT.into() - 1) / SHARES_PER_SLOT.into();
    slots.try_into().unwrap()
}

/// Packed holder for up to `SHARES_PER_SLOT` (15) `u16` shares in a single
/// `felt252` storage slot.
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct CustomShares {
    pub packed: felt252,
}

#[generate_trait]
pub impl CustomSharesImpl of CustomSharesTrait {
    fn new() -> CustomShares {
        CustomShares { packed: 0 }
    }

    fn get_share(self: @CustomShares, index: u8) -> u16 {
        get_packed_share((*self.packed).into(), index)
    }

    fn set_share(ref self: CustomShares, index: u8, share: u16) {
        let new_packed = set_packed_share(self.packed.into(), index, share);
        self.packed = new_packed.try_into().unwrap();
    }

    /// Pack up to `SHARES_PER_SLOT` shares from `shares` into a new slot.
    /// Shares past the first `SHARES_PER_SLOT` are ignored; callers split
    /// longer arrays across multiple slots themselves.
    fn from_array(shares: Span<u16>) -> CustomShares {
        let mut packed = Self::new();
        let len: u32 = if shares.len() > SHARES_PER_SLOT.into() {
            SHARES_PER_SLOT.into()
        } else {
            shares.len()
        };
        let mut i: u32 = 0;
        while i < len {
            packed.set_share(i.try_into().unwrap(), *shares.at(i));
            i += 1;
        }
        packed
    }

    /// Unpack the first `count` shares (clamped to `SHARES_PER_SLOT`).
    fn to_array(self: @CustomShares, count: u8) -> Array<u16> {
        let mut result = ArrayTrait::new();
        let len: u8 = if count > SHARES_PER_SLOT {
            SHARES_PER_SLOT
        } else {
            count
        };
        let mut i: u8 = 0;
        while i < len {
            result.append(self.get_share(i));
            i += 1;
        }
        result
    }
}

#[cfg(test)]
mod tests {
    use super::{
        CustomSharesImpl, CustomSharesTrait, SHARES_PER_SLOT, calculate_slot_position,
        calculate_slots_needed, get_packed_share, pow_2_u256_16, set_packed_share,
    };

    #[test]
    fn test_pow_2_common_values() {
        assert!(pow_2_u256_16(0) == 1, "2^0 should be 1");
        assert!(pow_2_u256_16(16) == 0x10000, "2^16 mismatch");
        assert!(pow_2_u256_16(32) == 0x100000000, "2^32 mismatch");
        assert!(pow_2_u256_16(64) == 0x10000000000000000, "2^64 mismatch");
    }

    #[test]
    fn test_get_set_packed_share() {
        let packed: u256 = 0;
        let packed = set_packed_share(packed, 0, 1000);
        assert!(get_packed_share(packed, 0) == 1000, "share 0 mismatch");

        let packed = set_packed_share(packed, 5, 5000);
        assert!(get_packed_share(packed, 5) == 5000, "share 5 mismatch");
        assert!(get_packed_share(packed, 0) == 1000, "share 0 should be unchanged");

        let packed = set_packed_share(packed, 14, 14000);
        assert!(get_packed_share(packed, 14) == 14000, "share 14 mismatch");
    }

    #[test]
    fn test_calculate_slot_position() {
        let (slot, pos) = calculate_slot_position(0);
        assert!(slot == 0 && pos == 0, "index 0 should be slot 0, pos 0");

        let (slot, pos) = calculate_slot_position(14);
        assert!(slot == 0 && pos == 14, "index 14 should be slot 0, pos 14");

        let (slot, pos) = calculate_slot_position(15);
        assert!(slot == 1 && pos == 0, "index 15 should be slot 1, pos 0");

        let (slot, pos) = calculate_slot_position(30);
        assert!(slot == 2 && pos == 0, "index 30 should be slot 2, pos 0");
    }

    #[test]
    fn test_calculate_slots_needed() {
        assert!(calculate_slots_needed(0) == 0, "0 shares = 0 slots");
        assert!(calculate_slots_needed(1) == 1, "1 share = 1 slot");
        assert!(calculate_slots_needed(15) == 1, "15 shares = 1 slot");
        assert!(calculate_slots_needed(16) == 2, "16 shares = 2 slots");
        assert!(calculate_slots_needed(30) == 2, "30 shares = 2 slots");
        assert!(calculate_slots_needed(31) == 3, "31 shares = 3 slots");
    }

    #[test]
    fn test_shares_per_slot_constant() {
        assert!(SHARES_PER_SLOT == 15, "SHARES_PER_SLOT should be 15");
    }

    #[test]
    fn test_custom_shares_from_to_array() {
        let shares = array![100_u16, 200_u16, 300_u16, 400_u16, 500_u16];
        let packed = CustomSharesImpl::from_array(shares.span());
        let decoded = packed.to_array(5);
        assert!(decoded.len() == 5, "decoded length mismatch");
        assert!(*decoded.at(0) == 100, "share 0");
        assert!(*decoded.at(1) == 200, "share 1");
        assert!(*decoded.at(2) == 300, "share 2");
        assert!(*decoded.at(3) == 400, "share 3");
        assert!(*decoded.at(4) == 500, "share 4");
    }

    #[test]
    fn test_custom_shares_full_slot_roundtrip() {
        let shares = array![
            1_u16, 2_u16, 3_u16, 4_u16, 5_u16, 6_u16, 7_u16, 8_u16, 9_u16, 10_u16, 11_u16, 12_u16,
            13_u16, 14_u16, 15_u16,
        ];
        let packed = CustomSharesImpl::from_array(shares.span());
        let decoded = packed.to_array(15);
        let mut i: u32 = 0;
        while i < 15 {
            let expected: u16 = (i + 1).try_into().unwrap();
            assert!(*decoded.at(i) == expected, "share mismatch");
            i += 1;
        }
    }
}
