//! Token Mixin Component
//!
//! A comprehensive component that combines all token extensions into a single interface.
//! This follows the OpenZeppelin pattern for mixin components.

// Interface re-exports for convenience
pub use crate::interface::IMINIGAME_TOKEN_ID;
pub use crate::extensions::multi_game::interface::IMINIGAME_TOKEN_MULTIGAME_ID;
pub use crate::extensions::objectives::interface::IMINIGAME_TOKEN_OBJECTIVES_ID;
pub use crate::extensions::settings::interface::IMINIGAME_TOKEN_SETTINGS_ID;
pub use crate::extensions::minter::interface::IMINIGAME_TOKEN_MINTER_ID;
// pub use crate::extensions::soulbound::interface::IMINIGAME_TOKEN_SOULBOUND_ID;

// Component re-exports for convenience
pub use crate::token::TokenComponent;
pub use crate::extensions::multi_game::multi_game::MultiGameComponent;
pub use crate::extensions::objectives::objectives::TokenObjectivesComponent;

// OpenZeppelin re-exports
pub use openzeppelin_token::erc721::ERC721Component;
pub use openzeppelin_introspection::src5::SRC5Component;

use starknet::ContractAddress;

/// Combined ABI interface for all token functionality
/// This interface combines all the token extension interfaces into a single trait
#[starknet::interface]
pub trait IMinigameTokenABI<TContractState> {
    // ===== Core Token Interface =====
    fn token_metadata(self: @TContractState, token_id: u64) -> crate::structs::TokenMetadata;
    fn is_playable(self: @TContractState, token_id: u64) -> bool;
    fn settings_id(self: @TContractState, token_id: u64) -> u32;
    fn player_name(self: @TContractState, token_id: u64) -> ByteArray;
    fn mint(
        ref self: TContractState,
        game_address: Option<ContractAddress>,
        player_name: Option<ByteArray>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_ids: Option<Span<u32>>,
        context: Option<game_components_metagame::extensions::context::structs::GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
    fn update_game(ref self: TContractState, token_id: u64);

    // ===== Multi-Game Interface =====
    fn game_count(self: @TContractState) -> u64;
    fn game_id_from_address(self: @TContractState, contract_address: ContractAddress) -> u64;
    fn game_address_from_id(self: @TContractState, game_id: u64) -> ContractAddress;
    fn game_metadata(
        self: @TContractState, game_id: u64,
    ) -> crate::extensions::multi_game::structs::GameMetadata;
    fn is_game_registered(self: @TContractState, contract_address: ContractAddress) -> bool;
    fn game_address(self: @TContractState, token_id: u64) -> ContractAddress;
    fn creator_token_id(self: @TContractState, game_id: u64) -> u64;
    fn client_url(self: @TContractState, token_id: u64) -> ByteArray;
    fn register_game(
        ref self: TContractState,
        creator_address: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        developer: ByteArray,
        publisher: ByteArray,
        genre: ByteArray,
        image: ByteArray,
        color: Option<ByteArray>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
    ) -> u64;

    // ===== Objectives Interface =====
    fn objectives_count(self: @TContractState, token_id: u64) -> u32;
    fn objectives(
        self: @TContractState, token_id: u64,
    ) -> Array<crate::extensions::objectives::structs::TokenObjective>;
    fn objective_ids(self: @TContractState, token_id: u64) -> Span<u32>;
    fn all_objectives_completed(self: @TContractState, token_id: u64) -> bool;
    fn create_objective(
        ref self: TContractState,
        game_address: ContractAddress,
        objective_id: u32,
        objective_data: game_components_minigame::extensions::objectives::structs::GameObjective,
    );

    // ===== SRC5 Interface =====
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;

    // ===== ERC721 Interface =====
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    );
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;

    // ===== ERC721 Metadata =====
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
}

/// Utility struct for mixin initialization parameters
#[derive(Drop, Clone)]
pub struct TokenMixinInitParams {
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub base_uri: ByteArray,
    pub game_address: Option<ContractAddress>,
}
