// Re-export Distribution from game_components_interfaces
pub use game_components_interfaces::distribution::{Distribution, TieredConfig};
use starknet::storage_access::StorePacking;

/// Basis points constant: 10000 = 100%
pub const BASIS_POINTS: u16 = 10000;

// Distribution type tag used by `PackedDistribution` to record which
// `Distribution` variant a context was configured with. There is no blanket
// `StorePacking<Distribution>` impl — a single-felt252 pack is lossy for
// `Distribution::Custom(Span<u16>)`, so callers persist the custom shares
// out-of-band via `packed_shares::CustomShares` and store the type tag +
// scalar params via `PackedDistribution`.
pub const DIST_TYPE_LINEAR: u8 = 0;
pub const DIST_TYPE_EXPONENTIAL: u8 = 1;
pub const DIST_TYPE_UNIFORM: u8 = 2;
pub const DIST_TYPE_CUSTOM: u8 = 3;
/// `Geometric(a, b)` packs both ratio terms into the single u16 param slot as
/// `a * 256 + b`, which is why `supports_exact_payout` caps them at 255. That
/// keeps the packed layout — one u8 tag plus one u16 param — unchanged.
pub const DIST_TYPE_GEOMETRIC: u8 = 4;
/// `Tiered` carries three u16s: the head ratio (packed `a * 256 + b`, as for
/// Geometric) in `dist_param`, then `head_count` and `head_share_bps` in the
/// two extra param slots added for it.
pub const DIST_TYPE_TIERED: u8 = 5;

// Constants for PackedDistribution bit-packing.
const TWO_POW_8: u128 = 0x100; // 2^8
const TWO_POW_24: u128 = 0x1000000; // 2^24
const TWO_POW_56: u128 = 0x100000000000000; // 2^56
const TWO_POW_72: u128 = 0x1000000000000000000; // 2^72
const MASK_8: u128 = 0xFF;
const MASK_16: u128 = 0xFFFF;
const MASK_32: u128 = 0xFFFFFFFF;

/// Distribution configuration packed into a single `felt252`.
///
/// Layout: `dist_type(8) | dist_param(16) | positions(32) | dist_param2(16) |
/// dist_param3(16)` = 88 bits.
///
/// - `dist_type` — one of `DIST_TYPE_LINEAR` / `DIST_TYPE_EXPONENTIAL` /
///   `DIST_TYPE_UNIFORM` / `DIST_TYPE_CUSTOM`.
/// - `dist_param` — weight for `Linear`/`Exponential`; 0 otherwise.
/// - `positions` — fixed paid-places count. `0` means "dynamic — use the
///   actual leaderboard size at payout time". For `Custom`, this always
///   equals the backing shares array length.
/// - `dist_param2` / `dist_param3` — `head_count` and `head_share_bps` for
///   `Tiered`; 0 for every other variant. Appended above the original 56-bit
///   layout, so pre-existing packed values unpack unchanged (their high bits
///   are zero).
///
/// This struct is the packed companion to `Distribution`; consumers
/// rehydrate the full enum by pairing it with a `CustomShares` Vec when
/// `dist_type == DIST_TYPE_CUSTOM`. Custom distributions enforce
/// `sum(shares) == available_share` at creation, so there is no rounding
/// remainder ("dust") to track at claim time.
#[derive(Copy, Drop, Serde)]
pub struct PackedDistribution {
    pub dist_type: u8,
    pub dist_param: u16,
    pub positions: u32,
    pub dist_param2: u16,
    pub dist_param3: u16,
}

pub impl PackedDistributionStorePacking of StorePacking<PackedDistribution, felt252> {
    fn pack(value: PackedDistribution) -> felt252 {
        let packed: felt252 = value.dist_type.into()
            + (value.dist_param.into() * TWO_POW_8.into())
            + (value.positions.into() * TWO_POW_24.into())
            + (value.dist_param2.into() * TWO_POW_56.into())
            + (value.dist_param3.into() * TWO_POW_72.into());
        packed
    }

    fn unpack(value: felt252) -> PackedDistribution {
        let value_u128: u128 = value.try_into().unwrap();

        let dist_type: u8 = (value_u128 & MASK_8).try_into().unwrap();
        let dist_param: u16 = ((value_u128 / TWO_POW_8) & MASK_16).try_into().unwrap();
        let positions: u32 = ((value_u128 / TWO_POW_24) & MASK_32).try_into().unwrap();
        let dist_param2: u16 = ((value_u128 / TWO_POW_56) & MASK_16).try_into().unwrap();
        let dist_param3: u16 = ((value_u128 / TWO_POW_72) & MASK_16).try_into().unwrap();

        PackedDistribution { dist_type, dist_param, positions, dist_param2, dist_param3 }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        DIST_TYPE_EXPONENTIAL, DIST_TYPE_LINEAR, PackedDistribution, PackedDistributionStorePacking,
    };

    #[test]
    fn test_packed_distribution_roundtrip() {
        let original = PackedDistribution {
            dist_type: DIST_TYPE_EXPONENTIAL,
            dist_param: 15,
            positions: 0,
            dist_param2: 0,
            dist_param3: 0,
        };
        let packed = PackedDistributionStorePacking::pack(original);
        let unpacked = PackedDistributionStorePacking::unpack(packed);
        assert!(unpacked.dist_type == DIST_TYPE_EXPONENTIAL, "dist_type");
        assert!(unpacked.dist_param == 15, "dist_param");
        assert!(unpacked.positions == 0, "positions");
    }

    #[test]
    fn test_packed_distribution_with_positions() {
        let original = PackedDistribution {
            dist_type: DIST_TYPE_LINEAR,
            dist_param: 10,
            positions: 5,
            dist_param2: 0,
            dist_param3: 0,
        };
        let packed = PackedDistributionStorePacking::pack(original);
        let unpacked = PackedDistributionStorePacking::unpack(packed);
        assert!(unpacked.dist_type == DIST_TYPE_LINEAR, "dist_type");
        assert!(unpacked.dist_param == 10, "dist_param");
        assert!(unpacked.positions == 5, "positions");
    }

    #[test]
    fn test_packed_distribution_max_values() {
        let original = PackedDistribution {
            dist_type: 255,
            dist_param: 65535,
            positions: 4294967295,
            dist_param2: 0,
            dist_param3: 0,
        };
        let packed = PackedDistributionStorePacking::pack(original);
        let unpacked = PackedDistributionStorePacking::unpack(packed);
        assert!(unpacked.dist_type == 255, "dist_type max");
        assert!(unpacked.dist_param == 65535, "dist_param max");
        assert!(unpacked.positions == 4294967295, "positions max");
    }
}
