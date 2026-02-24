use game_components_metagame::extensions::context::structs::GameContextDetails;
use starknet::ContractAddress;
use crate::structs::GameDetail;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - token_address()->ContractAddress
/// - settings_address()->ContractAddress
/// - objectives_address()->ContractAddress
/// - mint_game(...)
pub const IMINIGAME_ID: felt252 = 0x2f31b86998f0149c6a68c8ae77f6a09f22427dae80c92e7ffe3cc13029ba702;

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
        objective_ids: Option<Span<u32>>,
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
}

#[starknet::interface]
pub trait IMinigameTokenData<TState> {
    fn score(self: @TState, token_id: u64) -> u32;
    fn game_over(self: @TState, token_id: u64) -> bool;
}

#[starknet::interface]
pub trait IMinigameDetails<TState> {
    fn token_name(self: @TState, token_id: u64) -> ByteArray;
    fn token_description(self: @TState, token_id: u64) -> ByteArray;
    fn game_details(self: @TState, token_id: u64) -> Span<GameDetail>;
}

#[starknet::interface]
pub trait IMinigameDetailsSVG<TState> {
    fn game_details_svg(self: @TState, token_id: u64) -> ByteArray;
}

#[starknet::interface]
pub trait IMinigameTokenUri<TState> {
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;
}

