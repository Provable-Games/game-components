use starknet::ContractAddress;
use crate::structs::TokenMetadata;
use game_components_metagame::extensions::context::structs::GameContextDetails;

pub const IMINIGAME_TOKEN_ID: felt252 =
    0x02c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499704;

#[starknet::interface]
pub trait IMinigameToken<TState> {
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
}
