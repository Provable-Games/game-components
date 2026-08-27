// SPDX-License-Identifier: BUSL-1.1

use starknet::ContractAddress;
use crate::gpp::structs::{PackedGppConfig, PackedGppPool};

/// Generic store trait for GPP operations.
/// Abstracts storage access so business logic can work with any backing store.
pub trait Store<T> {
    fn get_config(self: @T, context_id: u64) -> PackedGppConfig;
    fn set_config(ref self: T, context_id: u64, config: PackedGppConfig);
    fn get_prize_token(self: @T, context_id: u64) -> ContractAddress;
    fn set_prize_token(ref self: T, context_id: u64, addr: ContractAddress);
    fn get_pool(self: @T, context_id: u64) -> PackedGppPool;
    fn set_pool(ref self: T, context_id: u64, pool: PackedGppPool);
    fn get_nft_at(self: @T, context_id: u64, index: u32) -> u128;
    fn set_nft_at(ref self: T, context_id: u64, index: u32, nft_id: u128);
    /// The NFT reserved for `token_id` IN `context_id`.
    ///
    /// Keyed by the pair, not by token id alone: a game token id is unique
    /// only within the contract that minted it, and a metagame runs contexts
    /// against many game contracts. See the component docs.
    fn get_token_nft(self: @T, context_id: u64, token_id: felt252) -> u128;
    fn set_token_nft(ref self: T, context_id: u64, token_id: felt252, nft_id: u128);
    fn is_claimed(self: @T, context_id: u64, token_id: felt252) -> bool;
    fn set_claimed(ref self: T, context_id: u64, token_id: felt252, claimed: bool);
}
