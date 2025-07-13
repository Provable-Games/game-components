use starknet::ContractAddress;

use crate::structs::TokenMetadata;
use crate::extensions::objectives::interface::TokenObjective;

use game_components_minigame::extensions::objectives::structs::GameObjective;
use game_components_minigame::extensions::settings::structs::GameSetting;
use game_components_metagame::extensions::context::structs::GameContextDetails;

// Interface constants for the optimized token components
pub const IMINIGAME_TOKEN_ID: felt252 =
    0x02c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499704;

pub const IMINIGAME_TOKEN_MULTIGAME_ID: felt252 =
    0x014a8d6e4bf56a4bbf869257d1f846e5a2ac1e3508466147556f186143409be1;

pub const IMINIGAME_TOKEN_OBJECTIVES_ID: felt252 =
    0x8bb87efb8f7d4c796d9138d561d415d0db463db97873626f104b6e660ed6cf;

pub const IMINIGAME_TOKEN_SETTINGS_ID: felt252 =
    0x02e0b4b2324e3b0a64da1d2c55dbbcaf8c369f0dd3f44e23babe98f8de7d6a89;

pub const IMINIGAME_TOKEN_MINTER_ID: felt252 =
    0x021482384f4a706dbe387c9fc12175768c24904c5f5f258f1189a6d545eb3104;

pub const IMINIGAME_TOKEN_SOULBOUND_ID: felt252 =
    0x0373556b429b8d6a1209e10edfb4d099f83f2eb128dd3c3d7cc427b238732cda;

#[starknet::interface]
pub trait IMinigameTokenMixin<TState> {
    // Core token functionality
    fn token_metadata(self: @TState, token_id: u64) -> TokenMetadata;
    fn is_playable(self: @TState, token_id: u64) -> bool;
    fn settings_id(self: @TState, token_id: u64) -> u32;
    fn player_name(self: @TState, token_id: u64) -> ByteArray;
    fn objectives_count(self: @TState, token_id: u64) -> u32;
    fn minted_by(self: @TState, token_id: u64) -> u64;
    fn game_address(self: @TState, token_id: u64) -> ContractAddress;
    fn game_registry_address(self: @TState) -> ContractAddress;
    fn is_soulbound(self: @TState, token_id: u64) -> bool;
    fn renderer_address(self: @TState, token_id: u64) -> ContractAddress;

    fn mint(
        ref self: TState,
        game_address: Option<ContractAddress>,
        player_name: Option<ByteArray>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_ids: Option<Span<u32>>,
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
    fn set_token_metadata(
        ref self: TState,
        token_id: u64,
        game_address: ContractAddress,
        player_name: Option<ByteArray>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_ids: Option<Span<u32>>,
        context: Option<GameContextDetails>,
    );
    fn update_game(ref self: TState, token_id: u64);
    // Minter functionality
    fn get_minter_address(self: @TState, minter_id: u64) -> starknet::ContractAddress;
    fn get_minter_id(self: @TState, minter_address: starknet::ContractAddress) -> u64;
    fn minter_exists(self: @TState, minter_address: starknet::ContractAddress) -> bool;
    fn total_minters(self: @TState) -> u64;
    // Objective functionality
    fn objectives(self: @TState, token_id: u64) -> Array<TokenObjective>;
    fn objective_ids(self: @TState, token_id: u64) -> Span<u32>;
    fn all_objectives_completed(self: @TState, token_id: u64) -> bool;
    fn create_objective(
        ref self: TState,
        game_address: ContractAddress,
        objective_id: u32,
        objective_data: GameObjective,
    );
    // Settings functionality
    fn create_settings(
        ref self: TState,
        game_address: ContractAddress,
        settings_id: u32,
        name: ByteArray,
        description: ByteArray,
        settings_data: Span<GameSetting>,
    );
    // Renderer functionality
    fn get_renderer(self: @TState, token_id: u64) -> starknet::ContractAddress;
    fn has_custom_renderer(self: @TState, token_id: u64) -> bool;
}
