// SPDX-License-Identifier: BUSL-1.1

use starknet::storage_access::StorePacking;

/// Constants for GPP packing
const NZ_TWO_POW_8: NonZero<u128> = 0x100;
const NZ_TWO_POW_32: NonZero<u128> = 0x100000000;
const NZ_TWO_POW_56: NonZero<u128> = 0x100000000000000;
const TWO_POW_8: u128 = 0x100;
const TWO_POW_32: u128 = 0x100000000;
const TWO_POW_56: u128 = 0x100000000000000;
const NZ_TWO_POW_64: NonZero<u128> = 0x10000000000000000;
const TWO_POW_64: u128 = 0x10000000000000000;

/// Prize type constants
pub const PRIZE_TYPE_UNSET: u8 = 0;
pub const PRIZE_TYPE_ERC20: u8 = 1;
pub const PRIZE_TYPE_ERC721: u8 = 2;

/// GPP config packed into felt252 (200 bits).
/// Set across configure (capacity + game_lifetime) and first fund call (prize_type + per_entrant).
/// Layout uses u256:
///   low u128: capacity(32) | game_lifetime(32) | prize_type(8) | per_entrant_lo(56)
///   high u128: per_entrant_hi(72)
/// Reconstruct: per_entrant = per_entrant_lo + per_entrant_hi * 2^56
#[derive(Copy, Drop, Serde)]
pub struct PackedGppConfig {
    pub capacity: u32,
    pub game_lifetime: u32,
    pub prize_type: u8,
    pub per_entrant: u128,
}

pub impl PackedGppConfigStorePacking of StorePacking<PackedGppConfig, felt252> {
    fn pack(value: PackedGppConfig) -> felt252 {
        let (per_hi, per_lo) = DivRem::div_rem(value.per_entrant, NZ_TWO_POW_56);
        let low: u128 = value.capacity.into()
            + Into::<u32, u128>::into(value.game_lifetime) * TWO_POW_32
            + Into::<u8, u128>::into(value.prize_type) * TWO_POW_32 * TWO_POW_32
            + per_lo * TWO_POW_32 * TWO_POW_32 * TWO_POW_8;
        let high: u128 = per_hi;
        let packed = u256 { low, high };
        packed.try_into().expect('GPP_CFG_PACK_OVERFLOW')
    }

    fn unpack(value: felt252) -> PackedGppConfig {
        let val: u256 = value.into();
        let (hi, capacity) = DivRem::div_rem(val.low, NZ_TWO_POW_32);
        let (hi, game_lifetime) = DivRem::div_rem(hi, NZ_TWO_POW_32);
        let (per_lo, prize_type) = DivRem::div_rem(hi, NZ_TWO_POW_8);
        let per_entrant: u128 = per_lo + val.high * TWO_POW_56;
        PackedGppConfig {
            capacity: capacity.try_into().unwrap(),
            game_lifetime: game_lifetime.try_into().unwrap(),
            prize_type: prize_type.try_into().unwrap(),
            per_entrant,
        }
    }
}

/// GPP mutable pool state packed into felt252 (192 bits).
/// All three fields change on hot paths (entry/completion/release).
/// Layout (u256):
///   low u128: active_count(32) | nft_top(32) | pool_balance_lo(64)
///   high u128: pool_balance_hi(64)
/// Reconstruct: pool_balance = pool_balance_lo + pool_balance_hi * 2^64
#[derive(Copy, Drop, Serde)]
pub struct PackedGppPool {
    pub pool_balance: u128,
    pub active_count: u32,
    pub nft_top: u32,
}

pub impl PackedGppPoolStorePacking of StorePacking<PackedGppPool, felt252> {
    fn pack(value: PackedGppPool) -> felt252 {
        let (pool_hi, pool_lo) = DivRem::div_rem(value.pool_balance, NZ_TWO_POW_64);
        let low: u128 = value.active_count.into()
            + Into::<u32, u128>::into(value.nft_top) * TWO_POW_32
            + pool_lo * TWO_POW_32 * TWO_POW_32;
        let high: u128 = pool_hi;
        let packed = u256 { low, high };
        packed.try_into().expect('GPP_POOL_PACK_OVERFLOW')
    }

    fn unpack(value: felt252) -> PackedGppPool {
        let val: u256 = value.into();
        let (hi, active_count) = DivRem::div_rem(val.low, NZ_TWO_POW_32);
        let (pool_lo, nft_top) = DivRem::div_rem(hi, NZ_TWO_POW_32);
        let pool_balance: u128 = pool_lo + val.high * TWO_POW_64;
        PackedGppPool {
            pool_balance,
            active_count: active_count.try_into().unwrap(),
            nft_top: nft_top.try_into().unwrap(),
        }
    }
}
