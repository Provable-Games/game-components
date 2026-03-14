// SPDX-License-Identifier: BUSL-1.1

use starknet::ContractAddress;
use crate::registry::interface::{GameFeeInfo, GameMetadata};

/// Generic store trait for registry operations.
/// Provides low-level storage accessors decoupled from any component state.
pub trait Store<T> {
    fn get_game_count(self: @T) -> u64;
    fn set_game_count(ref self: T, count: u64);
    fn get_game_id_by_address(self: @T, address: ContractAddress) -> u64;
    fn set_game_id_by_address(ref self: T, address: ContractAddress, game_id: u64);
    fn get_game_metadata(self: @T, game_id: u64) -> GameMetadata;
    fn set_game_metadata(ref self: T, game_id: u64, metadata: GameMetadata);
    fn get_default_game_fee_info(self: @T) -> GameFeeInfo;
    fn set_default_game_fee_info(ref self: T, info: GameFeeInfo);
    fn get_game_fee_info(self: @T, game_id: u64) -> GameFeeInfo;
    fn set_game_fee_info(ref self: T, game_id: u64, info: GameFeeInfo);
}
