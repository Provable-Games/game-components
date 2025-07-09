use starknet::ContractAddress;
use crate::structs::TokenMetadata;
use crate::extensions::multi_game::structs::GameMetadata;
use crate::extensions::objectives::structs::TokenObjective;
use game_components_metagame::extensions::context::structs::GameContextDetails;

pub const IMINIGAME_TOKEN_ID: felt252 =
    0x02c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499704;

#[starknet::interface]
pub trait IMinigameToken<TContractState> {
    fn token_metadata(self: @TContractState, token_id: u64) -> TokenMetadata;
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
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
    fn update_game(ref self: TContractState, token_id: u64);
}

//================================================================================================
// CALLBACK TRAITS FOR OPTIONAL COMPONENTS
//================================================================================================

// Optional callback trait for minter functionality
pub trait TokenMinterCallback<TContractState> {
    fn on_mint_with_minter(ref self: TContractState, minter_address: ContractAddress) -> u64;
}

// Optional callback trait for context functionality
pub trait TokenContextCallback<TContractState> {
    fn on_mint_with_context(ref self: TContractState, token_id: u64, context: GameContextDetails);
}

// Optional callback trait for soulbound functionality
pub trait TokenSoulboundCallback<TContractState> {
    fn on_mint_soulbound(ref self: TContractState, token_id: u64, to: ContractAddress);
}

// Optional callback trait for renderer functionality
pub trait TokenRendererCallback<TContractState> {
    fn on_mint_with_renderer(ref self: TContractState, token_id: u64, renderer_address: ContractAddress);
}

// Optional callback trait for multi-game functionality
pub trait TokenMultiGameCallback<TContractState> {
    fn get_game_id_from_address(ref self: TContractState, game_address: ContractAddress) -> u64;
    fn get_game_metadata(ref self: TContractState, game_id: u64) -> GameMetadata;
    fn get_game_address_from_id(ref self: TContractState, game_id: u64) -> ContractAddress;
}

// Optional callback trait for token objectives functionality  
pub trait TokenObjectivesCallback<TContractState> {
    fn get_objective(ref self: TContractState, token_id: u64, objective_index: u32) -> TokenObjective;
    fn set_objective(ref self: TContractState, token_id: u64, objective_index: u32, objective: TokenObjective);
}


