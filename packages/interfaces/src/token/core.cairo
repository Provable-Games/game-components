// Core token interface
use starknet::ContractAddress;
use crate::structs::metagame::GameContextDetails;
use crate::structs::token::{
    MintParams, PlayerNameUpdate, TokenFullState, TokenMetadata, TokenMutableState,
};

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// Includes agent_skills view function. Run `src5_rs parse` for full derivation.
pub const IMINIGAME_TOKEN_ID: felt252 =
    0xe67e1d4ee0d7c0cd75c9082845e0641ca255f8fe509d2b121db0b2287c4e8d;

#[starknet::interface]
pub trait IMinigameToken<TState> {
    fn token_metadata(self: @TState, token_id: felt252) -> TokenMetadata;
    fn is_playable(self: @TState, token_id: felt252) -> bool;
    fn settings_id(self: @TState, token_id: felt252) -> u32;
    fn player_name(self: @TState, token_id: felt252) -> felt252;
    fn objective_id(self: @TState, token_id: felt252) -> u32;
    fn minted_by(self: @TState, token_id: felt252) -> felt252;
    fn game_address(self: @TState) -> ContractAddress;
    fn game_registry_address(self: @TState) -> ContractAddress;
    fn is_soulbound(self: @TState, token_id: felt252) -> bool;
    fn renderer_address(self: @TState, token_id: felt252) -> ContractAddress;
    fn token_game_address(self: @TState, token_id: felt252) -> ContractAddress;
    fn token_mutable_state(self: @TState, token_id: felt252) -> TokenMutableState;
    fn agent_skills(self: @TState, token_id: felt252) -> ByteArray;

    // Batch view functions
    fn token_metadata_batch(self: @TState, token_ids: Span<felt252>) -> Array<TokenMetadata>;
    fn is_playable_batch(self: @TState, token_ids: Span<felt252>) -> Array<bool>;
    fn settings_id_batch(self: @TState, token_ids: Span<felt252>) -> Array<u32>;
    fn player_name_batch(self: @TState, token_ids: Span<felt252>) -> Array<felt252>;
    fn objective_id_batch(self: @TState, token_ids: Span<felt252>) -> Array<u32>;
    fn minted_by_batch(self: @TState, token_ids: Span<felt252>) -> Array<felt252>;
    fn is_soulbound_batch(self: @TState, token_ids: Span<felt252>) -> Array<bool>;
    fn renderer_address_batch(self: @TState, token_ids: Span<felt252>) -> Array<ContractAddress>;
    fn token_game_address_batch(self: @TState, token_ids: Span<felt252>) -> Array<ContractAddress>;
    fn token_mutable_state_batch(
        self: @TState, token_ids: Span<felt252>,
    ) -> Array<TokenMutableState>;
    fn token_full_state_batch(self: @TState, token_ids: Span<felt252>) -> Array<TokenFullState>;

    fn mint(
        ref self: TState,
        game_address: ContractAddress,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
        paymaster: bool,
        salt: u16,
        metadata: u16,
    ) -> felt252;
    /// Batch mint with full per-token parameters.
    /// Each MintParams contains all configuration for that token.
    fn mint_batch(ref self: TState, mints: Array<MintParams>) -> Array<felt252>;

    /// Batch mint identical tokens to multiple recipients.
    /// Shares all parameters across recipients and auto-increments salt (base_salt + index).
    fn mint_batch_recipients(
        ref self: TState,
        game_address: ContractAddress,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        recipients: Array<ContractAddress>,
        soulbound: bool,
        paymaster: bool,
        salt: u16,
        metadata: u16,
    ) -> Array<felt252>;

    fn update_game(ref self: TState, token_id: felt252);
    fn update_player_name(ref self: TState, token_id: felt252, name: felt252);

    // Batch write functions
    fn update_game_batch(ref self: TState, token_ids: Span<felt252>);
    fn update_player_name_batch(ref self: TState, updates: Span<PlayerNameUpdate>);
}
