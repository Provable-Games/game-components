// Core minigame interfaces
use starknet::ContractAddress;
use crate::structs::metagame::GameContextDetails;
use crate::structs::minigame::{GameDetail, MintGameParams};

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - token_address()->ContractAddress
/// - settings_address()->ContractAddress
/// - objectives_address()->ContractAddress
/// - mint_game(...)->felt252
/// - mint_game_batch(Array<MintGameParams>)->Array<felt252>
pub const IMINIGAME_ID: felt252 = 0x1b78fcd155ca1cfe04a0f0f75dd48b398995d2f9ff0c9f0e00ec80c71d1f2bb;

#[starknet::interface]
pub trait IMinigame<TState> {
    fn token_address(self: @TState) -> ContractAddress;
    fn settings_address(self: @TState) -> ContractAddress;
    fn objectives_address(self: @TState) -> ContractAddress;
    fn mint_game(
        self: @TState,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        skills_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
        paymaster: bool,
        salt: u16,
        metadata: u128,
    ) -> felt252;
    /// Batch mint games with per-token parameters
    fn mint_game_batch(self: @TState, mints: Array<MintGameParams>) -> Array<felt252>;
}

#[starknet::interface]
pub trait IMinigameTokenData<TState> {
    fn score(self: @TState, token_id: felt252) -> u64;
    fn game_over(self: @TState, token_id: felt252) -> bool;

    // Batch operations
    fn score_batch(self: @TState, token_ids: Span<felt252>) -> Array<u64>;
    fn game_over_batch(self: @TState, token_ids: Span<felt252>) -> Array<bool>;
}

#[starknet::interface]
pub trait IMinigameDetails<TState> {
    fn token_name(self: @TState, token_id: felt252) -> ByteArray;
    fn token_description(self: @TState, token_id: felt252) -> ByteArray;
    fn game_details(self: @TState, token_id: felt252) -> Span<GameDetail>;

    // Batch operations
    fn token_name_batch(self: @TState, token_ids: Span<felt252>) -> Array<ByteArray>;
    fn token_description_batch(self: @TState, token_ids: Span<felt252>) -> Array<ByteArray>;
    fn game_details_batch(self: @TState, token_ids: Span<felt252>) -> Array<Span<GameDetail>>;
}

#[starknet::interface]
pub trait IMinigameDetailsSVG<TState> {
    fn game_details_svg(self: @TState, token_id: felt252) -> ByteArray;
}

#[starknet::interface]
pub trait IMinigameTokenUri<TState> {
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;
}
