use starknet::ContractAddress;

use crate::structs::TokenMetadata;
use crate::extensions::objectives::interface::TokenObjective;

use game_components_minigame::extensions::objectives::structs::GameObjective;
use game_components_minigame::extensions::settings::structs::GameSetting;
use game_components_metagame::extensions::context::structs::GameContextDetails;

#[starknet::interface]
pub trait IMinigameTokenMixin<TState> {
    // Core token functionality
    fn token_metadata(self: @TState, token_id: u64) -> TokenMetadata;
    fn is_playable(self: @TState, token_id: u64) -> bool;
    fn settings_id(self: @TState, token_id: u64) -> u32;
    fn player_name(self: @TState, token_id: u64) -> felt252;
    fn objectives_count(self: @TState, token_id: u64) -> u32;
    fn minted_by(self: @TState, token_id: u64) -> u64;
    fn game_address(self: @TState) -> ContractAddress;
    fn game_registry_address(self: @TState) -> ContractAddress;
    fn is_soulbound(self: @TState, token_id: u64) -> bool;
    fn renderer_address(self: @TState, token_id: u64) -> ContractAddress;
    fn token_game_address(self: @TState, token_id: u64) -> ContractAddress;

    fn mint(
        ref self: TState,
        game_address: Option<ContractAddress>,
        player_name: Option<felt252>,
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
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_ids: Option<Span<u32>>,
        context: Option<GameContextDetails>,
    );
    fn update_game(ref self: TState, token_id: u64);
    fn update_player_name(ref self: TState, token_id: u64, name: felt252);
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
    fn reset_token_renderer(ref self: TState, token_id: u64);
}

#[starknet::interface]
pub trait ITokenEventRelayer<TContractState> {
    fn initialize(
        ref self: TContractState,
        token_address: ContractAddress,
        game_registry_address: ContractAddress,
    );

    // Core token events
    fn emit_owners(
        ref self: TContractState, token_id: u64, owner: ContractAddress, auth: ContractAddress,
    );
    fn emit_token_metadata_update(
        ref self: TContractState,
        id: u64,
        game_id: u64,
        minted_at: u64,
        settings_id: u32,
        lifecycle_start: u64,
        lifecycle_end: u64,
        minted_by: u64,
        soulbound: bool,
        game_over: bool,
        completed_all_objectives: bool,
        has_context: bool,
        objectives_count: u8,
    );
    fn emit_token_player_name_update(ref self: TContractState, id: u64, player_name: felt252);
    fn emit_token_client_url_update(ref self: TContractState, id: u64, client_url: ByteArray);
    fn emit_token_score_update(ref self: TContractState, id: u64, score: u64);

    // Objectives extension events
    fn emit_objective_created(
        ref self: TContractState,
        game_address: ContractAddress,
        creator_address: ContractAddress,
        objective_id: u32,
        objective_data: ByteArray,
    );
    fn emit_objective_update(
        ref self: TContractState, token_id: u64, objective_id: u32, completed: bool,
    );

    // Settings extension events
    fn emit_settings_created(
        ref self: TContractState,
        game_address: ContractAddress,
        creator_address: ContractAddress,
        settings_id: u32,
        settings_data: ByteArray,
    );

    // Minter extension events
    fn emit_minter_registry_update(
        ref self: TContractState, id: u64, minter_address: ContractAddress,
    );

    // Context extension events
    fn emit_token_context_update(ref self: TContractState, id: u64, context_data: ByteArray);

    // Additional renderer events
    fn emit_token_renderer_update(
        ref self: TContractState, id: u64, renderer_address: ContractAddress,
    );

    // MinigameRegistry events
    fn emit_game_metadata_update(
        ref self: TContractState,
        id: u64,
        contract_address: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        developer: ByteArray,
        publisher: ByteArray,
        genre: ByteArray,
        image: ByteArray,
        color: ByteArray,
        client_url: ByteArray,
        renderer_address: ContractAddress,
    );
    fn emit_game_registry_update(
        ref self: TContractState, id: u64, contract_address: ContractAddress,
    );
}
