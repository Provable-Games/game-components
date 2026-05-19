// SPDX-License-Identifier: BUSL-1.1

use starknet::ContractAddress;
use crate::prize::structs::{CustomShares, StoredPrize};

/// Generic store trait for prize operations.
/// Maps 1:1 to storage fields without business logic.
pub trait Store<T> {
    fn get_prize(self: @T, prize_id: u64) -> StoredPrize;
    fn set_prize(ref self: T, prize_id: u64, prize: StoredPrize);
    fn get_claim(self: @T, context_id: u64, hash: felt252) -> bool;
    fn set_claim(ref self: T, context_id: u64, hash: felt252, claimed: bool);
    fn get_total_prizes(self: @T) -> u64;
    fn set_total_prizes(ref self: T, count: u64);
    fn get_custom_shares_count(self: @T, prize_id: u64) -> u32;
    fn set_custom_shares_count(ref self: T, prize_id: u64, count: u32);
    fn get_custom_shares_packed(self: @T, prize_id: u64, slot: u8) -> CustomShares;
    fn set_custom_shares_packed(ref self: T, prize_id: u64, slot: u8, shares: CustomShares);
    fn get_extension_address(self: @T, context_id: u64, prize_id: u64) -> ContractAddress;
    fn set_extension_address(ref self: T, context_id: u64, prize_id: u64, addr: ContractAddress);
    /// For extension prizes, the context_id this prize_id belongs to.
    /// Built-in prizes have context_id in StoredPrize and are absent
    /// from this map (reads as 0 — built-in prizes are detected via
    /// StoredPrize, not this map).
    fn get_extension_prize_context(self: @T, prize_id: u64) -> u64;
    fn set_extension_prize_context(ref self: T, prize_id: u64, context_id: u64);
    /// For extension prizes, the sponsor (caller of add_prize at
    /// registration time). Built-in prizes have sponsor in StoredPrize.
    fn get_extension_prize_sponsor(self: @T, prize_id: u64) -> ContractAddress;
    fn set_extension_prize_sponsor(ref self: T, prize_id: u64, sponsor: ContractAddress);
    /// The leaderboard position this built-in prize pays out to. Set by
    /// the host at add_prize time for `Prize::Token` with a non-distributed
    /// payout shape; zero means unset (distributed prizes don't use it,
    /// and extension prizes own their own per-position semantics).
    /// Stored on the component so any host using PrizeComponent gets
    /// position-aware claim resolution without a parallel storage map.
    fn get_payout_position(self: @T, prize_id: u64) -> u32;
    fn set_payout_position(ref self: T, prize_id: u64, position: u32);
}
