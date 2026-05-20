// SPDX-License-Identifier: BUSL-1.1

use game_components_utilities::distribution::packed_shares::CustomShares;
use game_components_utilities::distribution::structs::PackedDistribution;
use starknet::ContractAddress;
use crate::entry_fee::structs::PackedAdditionalShares;

/// Generic store trait for entry fee operations.
/// Maps storage reads/writes without business logic.
pub trait Store<T> {
    fn get_token(self: @T, context_id: u64) -> ContractAddress;
    fn set_token(ref self: T, context_id: u64, token: ContractAddress);
    fn get_data_raw(self: @T, context_id: u64) -> felt252;
    fn set_data_raw(ref self: T, context_id: u64, data: felt252);
    fn get_additional_recipient(self: @T, context_id: u64, index: u8) -> ContractAddress;
    fn set_additional_recipient(
        ref self: T, context_id: u64, index: u8, recipient: ContractAddress,
    );
    fn get_packed_shares(self: @T, context_id: u64, slot: u8) -> PackedAdditionalShares;
    fn set_packed_shares(ref self: T, context_id: u64, slot: u8, shares: PackedAdditionalShares);
    fn get_refund_claimed(self: @T, context_id: u64, token_id: felt252) -> bool;
    fn set_refund_claimed(ref self: T, context_id: u64, token_id: felt252, claimed: bool);
    fn get_position_claimed(self: @T, context_id: u64, position: u32) -> bool;
    fn set_position_claimed(ref self: T, context_id: u64, position: u32, claimed: bool);
    fn get_extension_address(self: @T, context_id: u64) -> ContractAddress;
    fn set_extension_address(ref self: T, context_id: u64, address: ContractAddress);
    /// Packed custom distribution shares for slot `slot` (15 `u16` per slot).
    /// The number of shares is sourced from `get_distribution().positions` —
    /// no separate count is stored here.
    fn get_distribution_shares_packed(self: @T, context_id: u64, slot: u8) -> CustomShares;
    fn set_distribution_shares_packed(ref self: T, context_id: u64, slot: u8, shares: CustomShares);
    /// Distribution shape (type tag + weight + paid-places count) for the
    /// entry-fee pool payout. Unset unless the context configured a payout
    /// distribution.
    fn get_distribution(self: @T, context_id: u64) -> PackedDistribution;
    fn set_distribution(ref self: T, context_id: u64, distribution: PackedDistribution);
}
