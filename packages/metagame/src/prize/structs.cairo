// Re-export all types from game_components_interfaces
pub use game_components_interfaces::distribution::Distribution;
pub use game_components_interfaces::prize::{
    ERC20Data, ERC721Data, Prize, PrizeConfig, PrizeData, PrizeType, TokenTypeData,
};
// Re-export CustomShares machinery from utilities so existing consumers that
// import from `crate::prize::structs` continue to work.
pub use game_components_utilities::distribution::packed_shares::{
    CustomShares, CustomSharesImpl, CustomSharesTrait, SHARES_PER_SLOT as CUSTOM_SHARES_PER_SLOT,
};
use starknet::ContractAddress;
use starknet::storage_access::StorePacking;

/// NonZero<u128> constants for DivRem-based unpacking.
mod nz128 {
    pub const TWO_POW_8: NonZero<u128> = 0x100;
    pub const TWO_POW_16: NonZero<u128> = 0x10000;
}

// Payout type constants for storage
pub const PAYOUT_TYPE_POSITION: u8 = 0;
pub const PAYOUT_TYPE_LINEAR: u8 = 1;
pub const PAYOUT_TYPE_EXPONENTIAL: u8 = 2;
pub const PAYOUT_TYPE_UNIFORM: u8 = 3;
pub const PAYOUT_TYPE_CUSTOM: u8 = 4;

/// Internal packed representation for ERC20 data storage
/// Layout: [amount: 128 bits][payout_type: 8 bits][param: 16 bits][count: 32 bits] = 184 bits
/// This is used internally by StorePacking and not exposed in the API
#[derive(Copy, Drop)]
struct PackedERC20Data {
    amount: u128,
    payout_type: u8,
    param: u16,
    count: u32,
}

/// u128-aligned StorePacking for PackedERC20Data.
///
/// Bit layout (184 bits total, no field straddles the u128 boundary):
///
/// Low u128 (128 bits):
///   amount(128)
///
/// High u128 (56 bits):
///   payout_type(8) | param(16) | count(32)
///
/// All DivRem operations use native u128_safe_divmod Sierra hints.
impl PackedERC20DataPacking of StorePacking<PackedERC20Data, felt252> {
    fn pack(value: PackedERC20Data) -> felt252 {
        let low: u128 = value.amount;

        let high: u128 = value.payout_type.into()
            + value.param.into() * 0x100_u128 // shift 8
            + value.count.into() * 0x1000000_u128; // shift 24

        let packed = u256 { low, high };
        packed.try_into().unwrap()
    }

    fn unpack(value: felt252) -> PackedERC20Data {
        let packed: u256 = value.into();

        let amount: u128 = packed.low;

        let high = packed.high;
        let (hi, payout_type) = DivRem::div_rem(high, nz128::TWO_POW_8);
        let (count, param) = DivRem::div_rem(hi, nz128::TWO_POW_16);

        PackedERC20Data {
            amount,
            payout_type: payout_type.try_into().unwrap(),
            param: param.try_into().unwrap(),
            count: count.try_into().unwrap(),
        }
    }
}

/// Internal enum for storing TokenTypeData with packing
#[allow(starknet::store_no_default_variant)]
#[derive(Copy, Drop, Serde, starknet::Store)]
enum PackedTokenTypeData {
    erc20: felt252, // Packed ERC20Data
    erc721: ERC721Data,
}

/// Internal storage representation of Prize with Store trait
/// This is what actually gets stored in contract storage
#[derive(Drop, Serde)]
pub struct StoredPrize {
    pub context_id: u64,
    pub token_address: ContractAddress,
    pub token_type: PackedTokenTypeData,
    pub sponsor_address: ContractAddress,
}

/// StorePacking for StoredPrize - handles efficient packing into storage
/// Packs into: (context_id, token_address, packed_token_type, sponsor_address)
pub impl StoredPrizeStorePacking of StorePacking<
    StoredPrize, (u64, ContractAddress, PackedTokenTypeData, ContractAddress),
> {
    fn pack(value: StoredPrize) -> (u64, ContractAddress, PackedTokenTypeData, ContractAddress) {
        (value.context_id, value.token_address, value.token_type, value.sponsor_address)
    }

    fn unpack(value: (u64, ContractAddress, PackedTokenTypeData, ContractAddress)) -> StoredPrize {
        let (context_id, token_address, token_type, sponsor_address) = value;
        StoredPrize { context_id, token_address, token_type, sponsor_address }
    }
}

/// Helper to pack TokenTypeData from Prize API format
fn pack_token_type(token_type: TokenTypeData) -> PackedTokenTypeData {
    match token_type {
        TokenTypeData::erc20(erc20_data) => {
            // Convert ERC20Data to packed format
            let (payout_type, param) = match erc20_data.distribution {
                Option::None => (PAYOUT_TYPE_POSITION, 0_u16),
                Option::Some(dist) => {
                    match dist {
                        game_components_utilities::distribution::structs::Distribution::Linear(w) => (
                            PAYOUT_TYPE_LINEAR, w,
                        ),
                        game_components_utilities::distribution::structs::Distribution::Exponential(w) => (
                            PAYOUT_TYPE_EXPONENTIAL, w,
                        ),
                        game_components_utilities::distribution::structs::Distribution::Uniform => (
                            PAYOUT_TYPE_UNIFORM, 0_u16,
                        ),
                        game_components_utilities::distribution::structs::Distribution::Custom(_) => (
                            PAYOUT_TYPE_CUSTOM, 0_u16,
                        ),
                    }
                },
            };
            let count = match erc20_data.distribution_count {
                Option::Some(c) => c,
                Option::None => 0_u32,
            };
            let packed = PackedERC20Data { amount: erc20_data.amount, payout_type, param, count };
            PackedTokenTypeData::erc20(PackedERC20DataPacking::pack(packed))
        },
        TokenTypeData::erc721(erc721_data) => PackedTokenTypeData::erc721(erc721_data),
    }
}

/// Helper to unpack TokenTypeData to Prize API format
fn unpack_token_type(packed_token_type: PackedTokenTypeData) -> TokenTypeData {
    match packed_token_type {
        PackedTokenTypeData::erc20(packed_felt) => {
            let packed = PackedERC20DataPacking::unpack(packed_felt);

            // Reconstruct distribution
            let distribution = if packed.payout_type == PAYOUT_TYPE_POSITION {
                Option::None
            } else if packed.payout_type == PAYOUT_TYPE_LINEAR {
                Option::Some(
                    game_components_utilities::distribution::structs::Distribution::Linear(
                        packed.param,
                    ),
                )
            } else if packed.payout_type == PAYOUT_TYPE_EXPONENTIAL {
                Option::Some(
                    game_components_utilities::distribution::structs::Distribution::Exponential(
                        packed.param,
                    ),
                )
            } else if packed.payout_type == PAYOUT_TYPE_UNIFORM {
                Option::Some(
                    game_components_utilities::distribution::structs::Distribution::Uniform,
                )
            } else {
                Option::Some(
                    game_components_utilities::distribution::structs::Distribution::Custom(
                        array![].span(),
                    ),
                )
            };

            // Reconstruct distribution_count
            let distribution_count = if packed.count == 0 {
                Option::None
            } else {
                Option::Some(packed.count)
            };

            TokenTypeData::erc20(
                ERC20Data { amount: packed.amount, distribution, distribution_count },
            )
        },
        PackedTokenTypeData::erc721(erc721_data) => TokenTypeData::erc721(erc721_data),
    }
}

/// Helper functions to convert between Prize (API) and StoredPrize (storage)
#[generate_trait]
pub impl StoredPrizeImpl of StoredPrizeTrait {
    /// Convert PrizeData to StoredPrize (for writing to storage)
    fn from_prize(prize: PrizeData) -> StoredPrize {
        let packed_token_type = pack_token_type(prize.token_type);
        StoredPrize {
            context_id: prize.context_id,
            token_address: prize.token_address,
            token_type: packed_token_type,
            sponsor_address: prize.sponsor_address,
        }
    }

    /// Convert StoredPrize to PrizeData (for reading from storage)
    fn to_prize(self: StoredPrize, id: u64) -> PrizeData {
        let token_type = unpack_token_type(self.token_type);
        PrizeData {
            id,
            context_id: self.context_id,
            token_address: self.token_address,
            token_type,
            sponsor_address: self.sponsor_address,
        }
    }
}

#[cfg(test)]
mod packed_erc20_data_tests {
    use super::{PackedERC20Data, PackedERC20DataPacking};

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    fn build_packed_erc20(
        amount: u128, payout_type: u8, param: u16, count: u32,
    ) -> PackedERC20Data {
        PackedERC20Data { amount, payout_type, param, count }
    }

    fn assert_roundtrip(data: PackedERC20Data) {
        let packed: felt252 = PackedERC20DataPacking::pack(data);
        let unpacked: PackedERC20Data = PackedERC20DataPacking::unpack(packed);
        assert!(unpacked.amount == data.amount, "amount mismatch");
        assert!(unpacked.payout_type == data.payout_type, "payout_type mismatch");
        assert!(unpacked.param == data.param, "param mismatch");
        assert!(unpacked.count == data.count, "count mismatch");
    }

    // -------------------------------------------------------------------------
    // 1. Zero values roundtrip
    // -------------------------------------------------------------------------

    #[test]
    fn test_zero_values_roundtrip() {
        let data = build_packed_erc20(0, 0, 0, 0);
        let packed: felt252 = PackedERC20DataPacking::pack(data);
        assert!(packed == 0, "packed zero should be zero");
        assert_roundtrip(data);
    }

    // -------------------------------------------------------------------------
    // 2. Max values
    // -------------------------------------------------------------------------

    #[test]
    fn test_max_values_roundtrip() {
        let data = build_packed_erc20(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, // u128 max
            0xFF, // u8 max
            0xFFFF, // u16 max
            0xFFFFFFFF // u32 max
        );
        assert_roundtrip(data);
    }

    #[test]
    fn test_max_amount_only() {
        let data = build_packed_erc20(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, 0, 0, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_max_payout_type_only() {
        let data = build_packed_erc20(0, 0xFF, 0, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_max_param_only() {
        let data = build_packed_erc20(0, 0, 0xFFFF, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_max_count_only() {
        let data = build_packed_erc20(0, 0, 0, 0xFFFFFFFF);
        assert_roundtrip(data);
    }

    // -------------------------------------------------------------------------
    // 3. Near-max values
    // -------------------------------------------------------------------------

    #[test]
    fn test_near_max_values() {
        let data = build_packed_erc20(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE_u128, // u128 max - 1
            0xFE, // u8 max - 1
            0xFFFE, // u16 max - 1
            0xFFFFFFFE // u32 max - 1
        );
        assert_roundtrip(data);
    }

    #[test]
    fn test_one_values() {
        let data = build_packed_erc20(1, 1, 1, 1);
        assert_roundtrip(data);
    }

    #[test]
    fn test_boundary_values() {
        // Values at power-of-2 boundaries
        let data = build_packed_erc20(
            0x80000000000000000000000000000000_u128, // 2^127
            0x80, // 2^7
            0x8000, // 2^15
            0x80000000 // 2^31
        );
        assert_roundtrip(data);
    }

    // -------------------------------------------------------------------------
    // 4. Mixed realistic values (payout types 0-4)
    // -------------------------------------------------------------------------

    #[test]
    fn test_payout_type_position() {
        // Position-based: no distribution param needed
        let data = build_packed_erc20(1000000000000000000_u128, 0, 0, 10);
        assert_roundtrip(data);
    }

    #[test]
    fn test_payout_type_linear() {
        // Linear distribution with weight param
        let data = build_packed_erc20(5000000000000000000_u128, 1, 500, 5);
        assert_roundtrip(data);
    }

    #[test]
    fn test_payout_type_exponential() {
        // Exponential distribution with decay param
        let data = build_packed_erc20(10000000000000000000_u128, 2, 200, 8);
        assert_roundtrip(data);
    }

    #[test]
    fn test_payout_type_uniform() {
        // Uniform distribution, param unused
        let data = build_packed_erc20(2500000000000000000_u128, 3, 0, 100);
        assert_roundtrip(data);
    }

    #[test]
    fn test_payout_type_custom() {
        // Custom distribution, param unused
        let data = build_packed_erc20(7500000000000000000_u128, 4, 0, 15);
        assert_roundtrip(data);
    }

    #[test]
    fn test_realistic_large_tournament() {
        // Large prize pool, many participants
        let data = build_packed_erc20(
            100000000000000000000000_u128, // 100k tokens (18 decimals)
            2, // exponential
            1000, // decay factor
            1000 // 1000 participants
        );
        assert_roundtrip(data);
    }

    // -------------------------------------------------------------------------
    // 5. Single field isolation
    // -------------------------------------------------------------------------

    #[test]
    fn test_isolation_amount_does_not_affect_others() {
        let data = build_packed_erc20(0xABCDEF0123456789_u128, 0, 0, 0);
        let packed: felt252 = PackedERC20DataPacking::pack(data);
        let unpacked: PackedERC20Data = PackedERC20DataPacking::unpack(packed);
        assert!(unpacked.amount == 0xABCDEF0123456789_u128, "amount wrong");
        assert!(unpacked.payout_type == 0, "payout_type should be zero");
        assert!(unpacked.param == 0, "param should be zero");
        assert!(unpacked.count == 0, "count should be zero");
    }

    #[test]
    fn test_isolation_payout_type_does_not_affect_others() {
        let data = build_packed_erc20(0, 0xAB, 0, 0);
        let packed: felt252 = PackedERC20DataPacking::pack(data);
        let unpacked: PackedERC20Data = PackedERC20DataPacking::unpack(packed);
        assert!(unpacked.amount == 0, "amount should be zero");
        assert!(unpacked.payout_type == 0xAB, "payout_type wrong");
        assert!(unpacked.param == 0, "param should be zero");
        assert!(unpacked.count == 0, "count should be zero");
    }

    #[test]
    fn test_isolation_param_does_not_affect_others() {
        let data = build_packed_erc20(0, 0, 0xBEEF, 0);
        let packed: felt252 = PackedERC20DataPacking::pack(data);
        let unpacked: PackedERC20Data = PackedERC20DataPacking::unpack(packed);
        assert!(unpacked.amount == 0, "amount should be zero");
        assert!(unpacked.payout_type == 0, "payout_type should be zero");
        assert!(unpacked.param == 0xBEEF, "param wrong");
        assert!(unpacked.count == 0, "count should be zero");
    }

    #[test]
    fn test_isolation_count_does_not_affect_others() {
        let data = build_packed_erc20(0, 0, 0, 0xDEADBEEF);
        let packed: felt252 = PackedERC20DataPacking::pack(data);
        let unpacked: PackedERC20Data = PackedERC20DataPacking::unpack(packed);
        assert!(unpacked.amount == 0, "amount should be zero");
        assert!(unpacked.payout_type == 0, "payout_type should be zero");
        assert!(unpacked.param == 0, "param should be zero");
        assert!(unpacked.count == 0xDEADBEEF, "count wrong");
    }

    // -------------------------------------------------------------------------
    // 6. Alternating max/zero
    // -------------------------------------------------------------------------

    #[test]
    fn test_alternating_max_zero_a() {
        // amount=max, payout_type=0, param=max, count=0
        let data = build_packed_erc20(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, 0, 0xFFFF, 0);
        assert_roundtrip(data);
    }

    #[test]
    fn test_alternating_max_zero_b() {
        // amount=0, payout_type=max, param=0, count=max
        let data = build_packed_erc20(0, 0xFF, 0, 0xFFFFFFFF);
        assert_roundtrip(data);
    }

    #[test]
    fn test_alternating_zero_max_a() {
        // amount=0, payout_type=0, param=max, count=max
        let data = build_packed_erc20(0, 0, 0xFFFF, 0xFFFFFFFF);
        assert_roundtrip(data);
    }

    #[test]
    fn test_alternating_zero_max_b() {
        // amount=max, payout_type=max, param=0, count=0
        let data = build_packed_erc20(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, 0xFF, 0, 0);
        assert_roundtrip(data);
    }

    // -------------------------------------------------------------------------
    // 7. Idempotency (pack -> unpack -> pack produces same felt252)
    // -------------------------------------------------------------------------

    #[test]
    fn test_idempotency_zero() {
        let data = build_packed_erc20(0, 0, 0, 0);
        let packed1: felt252 = PackedERC20DataPacking::pack(data);
        let unpacked: PackedERC20Data = PackedERC20DataPacking::unpack(packed1);
        let packed2: felt252 = PackedERC20DataPacking::pack(unpacked);
        assert!(packed1 == packed2, "idempotency failed for zero");
    }

    #[test]
    fn test_idempotency_max() {
        let data = build_packed_erc20(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128, 0xFF, 0xFFFF, 0xFFFFFFFF,
        );
        let packed1: felt252 = PackedERC20DataPacking::pack(data);
        let unpacked: PackedERC20Data = PackedERC20DataPacking::unpack(packed1);
        let packed2: felt252 = PackedERC20DataPacking::pack(unpacked);
        assert!(packed1 == packed2, "idempotency failed for max");
    }

    #[test]
    fn test_idempotency_mixed() {
        let data = build_packed_erc20(42000000000000000000_u128, 2, 300, 50);
        let packed1: felt252 = PackedERC20DataPacking::pack(data);
        let unpacked: PackedERC20Data = PackedERC20DataPacking::unpack(packed1);
        let packed2: felt252 = PackedERC20DataPacking::pack(unpacked);
        assert!(packed1 == packed2, "idempotency failed for mixed");
    }

    #[test]
    fn test_double_roundtrip() {
        let data = build_packed_erc20(9999999999_u128, 3, 12345, 67890);
        let packed1: felt252 = PackedERC20DataPacking::pack(data);
        let unpacked1: PackedERC20Data = PackedERC20DataPacking::unpack(packed1);
        let packed2: felt252 = PackedERC20DataPacking::pack(unpacked1);
        let unpacked2: PackedERC20Data = PackedERC20DataPacking::unpack(packed2);
        assert!(unpacked1.amount == unpacked2.amount, "double roundtrip amount mismatch");
        assert!(
            unpacked1.payout_type == unpacked2.payout_type, "double roundtrip payout_type mismatch",
        );
        assert!(unpacked1.param == unpacked2.param, "double roundtrip param mismatch");
        assert!(unpacked1.count == unpacked2.count, "double roundtrip count mismatch");
    }

    // -------------------------------------------------------------------------
    // 8. Fuzz roundtrip with bounded inputs
    // -------------------------------------------------------------------------

    #[test]
    #[fuzzer(runs: 100)]
    fn test_fuzz_roundtrip(amount: u128, payout_type: u8, param: u16, count: u32) {
        let data = build_packed_erc20(amount, payout_type, param, count);
        assert_roundtrip(data);
    }

    #[test]
    #[fuzzer(runs: 100)]
    fn test_fuzz_idempotency(amount: u128, payout_type: u8, param: u16, count: u32) {
        let data = build_packed_erc20(amount, payout_type, param, count);
        let packed1: felt252 = PackedERC20DataPacking::pack(data);
        let unpacked: PackedERC20Data = PackedERC20DataPacking::unpack(packed1);
        let packed2: felt252 = PackedERC20DataPacking::pack(unpacked);
        assert!(packed1 == packed2, "fuzz idempotency failed");
    }

    #[test]
    #[fuzzer(runs: 100)]
    fn test_fuzz_realistic_payout_types(amount: u128, param: u16, count: u32) {
        // Constrain payout_type to valid range 0-4
        let payout_type: u8 = (amount % 5).try_into().unwrap();
        let data = build_packed_erc20(amount, payout_type, param, count);
        assert_roundtrip(data);
    }
}
