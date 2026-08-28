// Core minigame interfaces
use starknet::ContractAddress;
use crate::structs::minigame::GameDetail;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// token_address: 0x19f994858ac8feac4b935e3747d4a05f1a4f8a96cc87ffa2d8bc17be3f3a5d7
/// settings_address: 0x31a225c3cb5d446d5015492333861cf55bd86d1d078aa03ebf5fab611be7ad5
/// objectives_address: 0x1e29430bb8699d02b61fbd5aeb58cdd98d669fe2ea3ec40d9db12b87a2ddd62
pub const IMINIGAME_ID: felt252 = 0x3672f24df9fc27c3ad99aa4e9f0a7173ccf1786921339b91fa5297588600260;

#[starknet::interface]
pub trait IMinigame<TState> {
    fn token_address(self: @TState) -> ContractAddress;
    fn settings_address(self: @TState) -> ContractAddress;
    fn objectives_address(self: @TState) -> ContractAddress;
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
