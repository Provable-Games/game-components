//! Common interfaces for all token component variants
//!
//! This file defines the base interfaces that all token components should implement,
//! plus optional interfaces for extended functionality.

use starknet::ContractAddress;

/// Base interface that all token components must implement
/// This provides the core minigame token functionality
#[starknet::interface]
pub trait IMinigameToken<TState> {
    // Core minting functionality
    fn mint(ref self: TState, to: ContractAddress, game_address: ContractAddress, settings_id: u32, objectives: Array<u32>) -> u64;
    
    // Token metadata
    fn settings_id(self: @TState, token_id: u64) -> u32;
    fn game_address(self: @TState, token_id: u64) -> ContractAddress;
    fn objective_ids(self: @TState, token_id: u64) -> Span<u32>;
    
    // Token count
    fn token_count(self: @TState) -> u64;
}

/// Optional interface for minter tracking functionality
/// Only implemented by components that include minter features
#[starknet::interface]
pub trait IMinterToken<TState> {
    fn minted_by(self: @TState, token_id: u64) -> u64;
    fn minter_address(self: @TState, minter_id: u64) -> ContractAddress;
    fn minter_count(self: @TState) -> u64;
}

/// Optional interface for multi-game functionality
/// Only implemented by components that include multi-game features
#[starknet::interface]
pub trait IMultiGameToken<TState> {
    fn register_game(ref self: TState, creator_address: ContractAddress, name: ByteArray, description: ByteArray, developer: ByteArray, publisher: ByteArray, genre: ByteArray, image: ByteArray, color: Option<ByteArray>, client_url: Option<ByteArray>, renderer_address: Option<ContractAddress>) -> u64;
    fn game_count(self: @TState) -> u64;
    fn game_id_from_address(self: @TState, contract_address: ContractAddress) -> u64;
    fn is_game_registered(self: @TState, contract_address: ContractAddress) -> bool;
}

/// Optional interface for objectives functionality
/// Only implemented by components that include objectives features
#[starknet::interface]
pub trait IObjectivesToken<TState> {
    fn objectives_count(self: @TState, token_id: u64) -> u32;
    fn all_objectives_completed(self: @TState, token_id: u64) -> bool;
    fn create_objective(ref self: TState, game_address: ContractAddress, objective_id: u32, objective_data: game_components_minigame::extensions::objectives::structs::GameObjective);
} 