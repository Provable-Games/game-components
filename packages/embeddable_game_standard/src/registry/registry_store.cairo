// SPDX-License-Identifier: BUSL-1.1

use starknet::ContractAddress;
use crate::registry::interface::GameMetadata;
use crate::registry::registry::registry::Errors;
use crate::registry::store::Store;

/// Store bridge: composes Store<T> reads with pure lib operations.
/// Provides composed read operations (batch, filtered, paginated) that only
/// need Store<T> access and are testable without a component.
pub trait RegistryStoreTrait<T> {
    /// Check if a game is registered by its contract address
    fn is_game_registered(self: @T, contract_address: ContractAddress) -> bool;
    /// Batch fetch metadata for multiple game IDs
    fn game_metadata_batch(self: @T, game_ids: Span<u64>) -> Array<GameMetadata>;
    /// Batch check registration status for multiple addresses
    fn games_registered_batch(self: @T, addresses: Span<ContractAddress>) -> Array<bool>;
    /// Get paginated list of games
    fn get_games(self: @T, start: u64, count: u64) -> Array<GameMetadata>;
    /// Get paginated list of games filtered by developer
    fn get_games_by_developer(
        self: @T, developer: ByteArray, start: u64, count: u64,
    ) -> Array<GameMetadata>;
    /// Get paginated list of games filtered by publisher
    fn get_games_by_publisher(
        self: @T, publisher: ByteArray, start: u64, count: u64,
    ) -> Array<GameMetadata>;
    /// Get paginated list of games filtered by genre
    fn get_games_by_genre(
        self: @T, genre: ByteArray, start: u64, count: u64,
    ) -> Array<GameMetadata>;
}

pub impl RegistryStoreImpl<T, +Store<T>, +Drop<T>> of RegistryStoreTrait<T> {
    fn is_game_registered(self: @T, contract_address: ContractAddress) -> bool {
        self.get_game_id_by_address(contract_address) != 0
    }

    fn game_metadata_batch(self: @T, game_ids: Span<u64>) -> Array<GameMetadata> {
        assert!(game_ids.len() > 0, "{}", Errors::GAME_IDS_EMPTY);
        let mut results: Array<GameMetadata> = ArrayTrait::new();
        let mut i: u32 = 0;
        loop {
            if i >= game_ids.len() {
                break;
            }
            let game_id = *game_ids.at(i);
            results.append(self.get_game_metadata(game_id));
            i += 1;
        }
        results
    }

    fn games_registered_batch(self: @T, addresses: Span<ContractAddress>) -> Array<bool> {
        assert!(addresses.len() > 0, "{}", Errors::ADDRESSES_EMPTY);
        let mut results: Array<bool> = ArrayTrait::new();
        let mut i: u32 = 0;
        loop {
            if i >= addresses.len() {
                break;
            }
            let addr = *addresses.at(i);
            results.append(self.get_game_id_by_address(addr) != 0);
            i += 1;
        }
        results
    }

    fn get_games(self: @T, start: u64, count: u64) -> Array<GameMetadata> {
        let mut results: Array<GameMetadata> = ArrayTrait::new();
        if count == 0 {
            return results;
        }
        let game_count = self.get_game_count();
        // Game IDs are 1-indexed, so valid range is 1..=game_count
        // If start is 0 or greater than game_count, return empty
        if start == 0 || start > game_count {
            return results;
        }
        let end = core::cmp::min(start + count, game_count + 1);
        let mut i = start;
        loop {
            if i >= end {
                break;
            }
            results.append(self.get_game_metadata(i));
            i += 1;
        }
        results
    }

    fn get_games_by_developer(
        self: @T, developer: ByteArray, start: u64, count: u64,
    ) -> Array<GameMetadata> {
        let mut results: Array<GameMetadata> = ArrayTrait::new();
        if count == 0 {
            return results;
        }
        let game_count = self.get_game_count();
        let mut game_id: u64 = 1;
        let mut skipped: u64 = 0;
        let mut collected: u64 = 0;
        loop {
            if game_id > game_count || collected >= count {
                break;
            }
            let metadata = self.get_game_metadata(game_id);
            if metadata.developer == developer {
                if skipped >= start {
                    results.append(metadata);
                    collected += 1;
                } else {
                    skipped += 1;
                }
            }
            game_id += 1;
        }
        results
    }

    fn get_games_by_publisher(
        self: @T, publisher: ByteArray, start: u64, count: u64,
    ) -> Array<GameMetadata> {
        let mut results: Array<GameMetadata> = ArrayTrait::new();
        if count == 0 {
            return results;
        }
        let game_count = self.get_game_count();
        let mut game_id: u64 = 1;
        let mut skipped: u64 = 0;
        let mut collected: u64 = 0;
        loop {
            if game_id > game_count || collected >= count {
                break;
            }
            let metadata = self.get_game_metadata(game_id);
            if metadata.publisher == publisher {
                if skipped >= start {
                    results.append(metadata);
                    collected += 1;
                } else {
                    skipped += 1;
                }
            }
            game_id += 1;
        }
        results
    }

    fn get_games_by_genre(
        self: @T, genre: ByteArray, start: u64, count: u64,
    ) -> Array<GameMetadata> {
        let mut results: Array<GameMetadata> = ArrayTrait::new();
        if count == 0 {
            return results;
        }
        let game_count = self.get_game_count();
        let mut game_id: u64 = 1;
        let mut skipped: u64 = 0;
        let mut collected: u64 = 0;
        loop {
            if game_id > game_count || collected >= count {
                break;
            }
            let metadata = self.get_game_metadata(game_id);
            if metadata.genre == genre {
                if skipped >= start {
                    results.append(metadata);
                    collected += 1;
                } else {
                    skipped += 1;
                }
            }
            game_id += 1;
        }
        results
    }
}
