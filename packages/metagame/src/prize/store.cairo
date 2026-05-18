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
}
