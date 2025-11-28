use starknet::ContractAddress;
use crate::structs::TokenMetadata;
use game_components_metagame::extensions::context::structs::GameContextDetails;

pub const IMINIGAME_TOKEN_ID: felt252 =
    0xa08df7e54b63300eeacf85a0f3289c405351278620b5af7e5d868b91f4d43d;

#[starknet::interface]
pub trait IMinigameToken<TState> {
    fn token_metadata(self: @TState, token_id: u64) -> TokenMetadata;
    fn is_playable(self: @TState, token_id: u64) -> bool;
    fn settings_id(self: @TState, token_id: u64) -> u32;
    fn player_name(self: @TState, token_id: u64) -> felt252;
    fn objectives_count(self: @TState, token_id: u64) -> u32;
    fn minted_by(self: @TState, token_id: u64) -> u64;
    fn game_address(self: @TState) -> ContractAddress;
    fn game_registry_address(self: @TState) -> ContractAddress;
    fn event_relayer_address(self: @TState) -> ContractAddress;
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
    fn mint_batch(
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
        quantity: u32,
    );
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
}
