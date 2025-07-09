use starknet::ContractAddress;
use crate::structs::TokenMetadata;
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
