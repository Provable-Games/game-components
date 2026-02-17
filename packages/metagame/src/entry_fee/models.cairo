// Import types from interface for component trait implementation
pub use game_components_interfaces::entry_fee::{
    AdditionalShare, EntryFee, EntryFeeConfig, EntryFeeDeposit,
};
use starknet::storage_access::StorePacking;

/// Basis points constant: 10000 = 100%
pub const BASIS_POINTS: u16 = 10000;

// Note: The public EntryFee struct is imported from game_components_interfaces::entry_fee above
// The following internal types are for storage and implementation details only

/// NonZero<u128> constants for DivRem-based unpacking.
/// Each constant is a power of 2 matching the field width.
/// DivRem extracts field (remainder) and shifts (quotient) in one operation.
mod nz128 {
    pub const TWO_POW_1: NonZero<u128> = 0x2;
    pub const TWO_POW_8: NonZero<u128> = 0x100;
    pub const TWO_POW_14: NonZero<u128> = 0x4000;
}

// Re-export SHARES_PER_SLOT for backward compatibility
pub use crate::entry_fee::libs::share_math::SHARES_PER_SLOT;
use crate::entry_fee::libs::share_math::{get_packed_share, set_packed_share};

/// Packed entry fee data for storage
/// Packs: amount (128) | game_creator_share (14) | refund_share (14) | game_creator_claimed (1) |
/// additional_count (8)
/// Total: 128 + 14 + 14 + 1 + 8 = 165 bits fits in felt252 (252 bits)
/// Additional shares are stored separately in arrays
#[derive(Copy, Drop, Serde)]
pub struct EntryFeeData {
    pub amount: u128,
    pub game_creator_share: u16, // 14 bits, 0 = None, basis points (10000 = 100%)
    pub refund_share: u16, // 14 bits, 0 = None, basis points (10000 = 100%)
    pub game_creator_claimed: bool, // 1 bit
    pub additional_count: u8 // 8 bits, number of additional shares
}

/// u128-aligned StorePacking for EntryFeeData.
///
/// Bit layout (165 bits total, no field straddles the u128 boundary):
///
/// Low u128 (128 bits):
///   amount(128)
///
/// High u128 (37 bits):
///   game_creator_share(14) | refund_share(14) | game_creator_claimed(1) | additional_count(8)
///
/// All DivRem operations use native u128_safe_divmod Sierra hints.
pub impl EntryFeeDataStorePacking of StorePacking<EntryFeeData, felt252> {
    fn pack(value: EntryFeeData) -> felt252 {
        let low: u128 = value.amount;

        let game_creator_claimed_u128: u128 = if value.game_creator_claimed {
            1
        } else {
            0
        };

        let high: u128 = value.game_creator_share.into()
            + value.refund_share.into() * 0x4000_u128 // shift 14
            + game_creator_claimed_u128 * 0x10000000_u128 // shift 28
            + value.additional_count.into() * 0x20000000_u128; // shift 29

        let packed = u256 { low, high };
        packed.try_into().unwrap()
    }

    fn unpack(value: felt252) -> EntryFeeData {
        let packed: u256 = value.into();

        let amount: u128 = packed.low;

        let high = packed.high;
        let (hi, game_creator_share) = DivRem::div_rem(high, nz128::TWO_POW_14);
        let (hi, refund_share) = DivRem::div_rem(hi, nz128::TWO_POW_14);
        let (additional_count, game_creator_claimed_u128) = DivRem::div_rem(hi, nz128::TWO_POW_1);
        let game_creator_claimed: bool = game_creator_claimed_u128 == 1;

        EntryFeeData {
            amount,
            game_creator_share: game_creator_share.try_into().unwrap(),
            refund_share: refund_share.try_into().unwrap(),
            game_creator_claimed,
            additional_count: additional_count.try_into().unwrap(),
        }
    }
}

/// Stored additional share data with claim status
/// Packs: share_bps (14 bits) | claimed (1 bit) = 15 bits
#[derive(Copy, Drop, Serde)]
pub struct StoredAdditionalShare {
    pub share_bps: u16, // 14 bits, basis points (10000 = 100%)
    pub claimed: bool // 1 bit
}

/// Packed additional shares - stores up to 16 shares in a single felt252
/// Each share = 15 bits (14 bits share_bps + 1 bit claimed)
/// Layout: [share0(15)] | [share1(15)] | ... | [share15(15)] = 240 bits fits in felt252 (252 bits)
/// This reduces storage operations from 2*N reads to 1 read + N recipient reads
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PackedAdditionalShares {
    pub packed: felt252,
}

/// Helper functions for packing/unpacking additional shares
#[generate_trait]
pub impl PackedAdditionalSharesImpl of PackedAdditionalSharesTrait {
    /// Create an empty packed shares struct
    fn new() -> PackedAdditionalShares {
        PackedAdditionalShares { packed: 0 }
    }

    /// Get a single share from the packed value at the given index (0-15)
    fn get_share(self: @PackedAdditionalShares, index: u8) -> StoredAdditionalShare {
        let (share_bps, claimed) = get_packed_share((*self.packed).into(), index);
        StoredAdditionalShare { share_bps, claimed }
    }

    /// Set a single share in the packed value at the given index (0-15)
    fn set_share(ref self: PackedAdditionalShares, index: u8, share: StoredAdditionalShare) {
        let new_packed = set_packed_share(
            self.packed.into(), index, share.share_bps, share.claimed,
        );
        self.packed = new_packed.try_into().unwrap();
    }

    /// Pack an array of shares (up to 16) into a PackedAdditionalShares
    fn from_array(shares: Span<StoredAdditionalShare>) -> PackedAdditionalShares {
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

    /// Unpack shares to an array (returns shares up to count)
    fn to_array(self: @PackedAdditionalShares, count: u8) -> Array<StoredAdditionalShare> {
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

/// Entry fee claim types for non-position-based shares
/// Position-based distribution claims are handled separately
#[allow(starknet::store_no_default_variant)]
#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub enum EntryFeeClaimType {
    /// Claim the game creator's share
    GameCreator,
    /// Claim refund share for a specific token_id
    Refund: felt252,
    /// Claim an additional share by index
    AdditionalShare: u8,
}

// =============================================================================
// TESTS
// =============================================================================

#[cfg(test)]
mod tests {
    use super::{EntryFeeData, EntryFeeDataStorePacking};

    // =========================================================================
    // Helpers
    // =========================================================================

    fn build_entry_fee_data(
        amount: u128,
        game_creator_share: u16,
        refund_share: u16,
        game_creator_claimed: bool,
        additional_count: u8,
    ) -> EntryFeeData {
        EntryFeeData {
            amount, game_creator_share, refund_share, game_creator_claimed, additional_count,
        }
    }

    fn assert_roundtrip(data: EntryFeeData) {
        let packed = EntryFeeDataStorePacking::pack(data);
        let unpacked = EntryFeeDataStorePacking::unpack(packed);
        assert!(unpacked.amount == data.amount, "amount mismatch");
        assert!(
            unpacked.game_creator_share == data.game_creator_share, "game_creator_share mismatch",
        );
        assert!(unpacked.refund_share == data.refund_share, "refund_share mismatch");
        assert!(
            unpacked.game_creator_claimed == data.game_creator_claimed,
            "game_creator_claimed mismatch",
        );
        assert!(unpacked.additional_count == data.additional_count, "additional_count mismatch");
    }

    // =========================================================================
    // 1. Zero values roundtrip
    // =========================================================================

    #[test]
    fn test_zero_values_roundtrip() {
        let data = build_entry_fee_data(0, 0, 0, false, 0);
        let packed = EntryFeeDataStorePacking::pack(data);
        assert!(packed == 0, "packed zero values should be 0");
        assert_roundtrip(data);
    }

    // =========================================================================
    // 2. Max values (each field at 2^N - 1)
    // =========================================================================

    #[test]
    fn test_max_values_roundtrip() {
        let data = build_entry_fee_data(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, // u128::MAX
            0x3FFF, // 14-bit max
            0x3FFF, // 14-bit max
            true, // 1-bit max
            0xFF // 8-bit max
        );
        assert_roundtrip(data);
    }

    // =========================================================================
    // 3. Near-max values (2^N - 2)
    // =========================================================================

    #[test]
    fn test_near_max_values_roundtrip() {
        let data = build_entry_fee_data(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE_u128, // u128::MAX - 1
            0x3FFE, // 14-bit max - 1
            0x3FFE, // 14-bit max - 1
            false, // only 0 or 1
            0xFE // 8-bit max - 1
        );
        assert_roundtrip(data);
    }

    // =========================================================================
    // 4. Mixed realistic values
    // =========================================================================

    #[test]
    fn test_realistic_tournament_entry() {
        // 0.1 ETH = 10^17 wei, creator gets 10% (1000 bps), refund 5% (500 bps), 3 additional
        let data = build_entry_fee_data(100000000000000000_u128, 1000, 500, false, 3);
        assert_roundtrip(data);
    }

    #[test]
    fn test_realistic_claimed_entry() {
        // 1 USDC = 10^6, creator 50% (5000 bps), no refund, claimed, 0 additional
        let data = build_entry_fee_data(1000000_u128, 5000, 0, true, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_realistic_full_shares() {
        // All shares configured, 16 additional shares (max packed in one slot)
        let data = build_entry_fee_data(500000000000000000_u128, 2500, 2500, false, 16);
        assert_roundtrip(data);
    }

    // =========================================================================
    // 5. Single field isolation (each field solo, others zero/false)
    // =========================================================================

    #[test]
    fn test_isolation_amount_only() {
        let data = build_entry_fee_data(123456789_u128, 0, 0, false, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_isolation_amount_max() {
        let data = build_entry_fee_data(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, 0, 0, false, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_isolation_game_creator_share_only() {
        let data = build_entry_fee_data(0, 0x3FFF, 0, false, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_isolation_refund_share_only() {
        let data = build_entry_fee_data(0, 0, 0x3FFF, false, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_isolation_game_creator_claimed_only() {
        let data = build_entry_fee_data(0, 0, 0, true, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_isolation_additional_count_only() {
        let data = build_entry_fee_data(0, 0, 0, false, 0xFF);
        assert_roundtrip(data);
    }

    // =========================================================================
    // 6. Alternating max/zero patterns
    // =========================================================================

    #[test]
    fn test_alternating_max_zero_pattern_a() {
        // amount=MAX, gc_share=0, refund_share=MAX, claimed=false, count=MAX
        let data = build_entry_fee_data(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, 0, 0x3FFF, false, 0xFF,
        );
        assert_roundtrip(data);
    }

    #[test]
    fn test_alternating_max_zero_pattern_b() {
        // amount=0, gc_share=MAX, refund_share=0, claimed=true, count=0
        let data = build_entry_fee_data(0, 0x3FFF, 0, true, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_alternating_max_zero_pattern_c() {
        // amount=MAX, gc_share=MAX, refund_share=0, claimed=true, count=0
        let data = build_entry_fee_data(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, 0x3FFF, 0, true, 0,
        );
        assert_roundtrip(data);
    }

    #[test]
    fn test_alternating_max_zero_pattern_d() {
        // amount=0, gc_share=0, refund_share=MAX, claimed=false, count=MAX
        let data = build_entry_fee_data(0, 0, 0x3FFF, false, 0xFF);
        assert_roundtrip(data);
    }

    // =========================================================================
    // 7. Idempotency (double pack/unpack)
    // =========================================================================

    #[test]
    fn test_idempotency_double_roundtrip() {
        let data = build_entry_fee_data(999999999_u128, 7500, 2500, true, 5);
        let packed_1 = EntryFeeDataStorePacking::pack(data);
        let unpacked_1 = EntryFeeDataStorePacking::unpack(packed_1);
        let packed_2 = EntryFeeDataStorePacking::pack(unpacked_1);
        let unpacked_2 = EntryFeeDataStorePacking::unpack(packed_2);

        assert!(packed_1 == packed_2, "packed values should be identical after double roundtrip");
        assert!(unpacked_2.amount == data.amount, "amount mismatch after double roundtrip");
        assert!(
            unpacked_2.game_creator_share == data.game_creator_share,
            "game_creator_share mismatch after double roundtrip",
        );
        assert!(
            unpacked_2.refund_share == data.refund_share,
            "refund_share mismatch after double roundtrip",
        );
        assert!(
            unpacked_2.game_creator_claimed == data.game_creator_claimed,
            "game_creator_claimed mismatch after double roundtrip",
        );
        assert!(
            unpacked_2.additional_count == data.additional_count,
            "additional_count mismatch after double roundtrip",
        );
    }

    #[test]
    fn test_idempotency_max_values() {
        let data = build_entry_fee_data(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, 0x3FFF, 0x3FFF, true, 0xFF,
        );
        let packed_1 = EntryFeeDataStorePacking::pack(data);
        let unpacked_1 = EntryFeeDataStorePacking::unpack(packed_1);
        let packed_2 = EntryFeeDataStorePacking::pack(unpacked_1);

        assert!(packed_1 == packed_2, "max values should be idempotent");
    }

    // =========================================================================
    // 8. Fuzz roundtrip with bounded inputs
    // =========================================================================

    #[test]
    #[fuzzer(runs: 100)]
    fn test_fuzz_roundtrip(
        amount: u128,
        raw_gc_share: u16,
        raw_refund_share: u16,
        raw_claimed: u8,
        additional_count: u8,
    ) {
        // Bound inputs to valid bit widths
        let game_creator_share: u16 = raw_gc_share % 0x4000; // 14 bits: 0..16383
        let refund_share: u16 = raw_refund_share % 0x4000; // 14 bits: 0..16383
        let game_creator_claimed: bool = (raw_claimed % 2) == 1; // 1 bit

        let data = build_entry_fee_data(
            amount, game_creator_share, refund_share, game_creator_claimed, additional_count,
        );
        assert_roundtrip(data);
    }

    #[test]
    #[fuzzer(runs: 100)]
    fn test_fuzz_idempotency(
        amount: u128,
        raw_gc_share: u16,
        raw_refund_share: u16,
        raw_claimed: u8,
        additional_count: u8,
    ) {
        let game_creator_share: u16 = raw_gc_share % 0x4000;
        let refund_share: u16 = raw_refund_share % 0x4000;
        let game_creator_claimed: bool = (raw_claimed % 2) == 1;

        let data = build_entry_fee_data(
            amount, game_creator_share, refund_share, game_creator_claimed, additional_count,
        );

        let packed_1 = EntryFeeDataStorePacking::pack(data);
        let unpacked_1 = EntryFeeDataStorePacking::unpack(packed_1);
        let packed_2 = EntryFeeDataStorePacking::pack(unpacked_1);

        assert!(packed_1 == packed_2, "fuzz: packed values should be idempotent");
    }
}
