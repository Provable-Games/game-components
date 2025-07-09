use starknet::ContractAddress;
use crate::extensions::multi_game::structs::GameMetadata;

pub const IMINIGAME_TOKEN_MULTIGAME_ID: felt252 =
    0x014a8d6e4bf56a4bbf869257d1f846e5a2ac1e3508466147556f186143409be1;

#[starknet::interface]
pub trait IMinigameTokenMultiGame<TState> {
    fn game_count(self: @TState) -> u64;
    fn game_id_from_address(self: @TState, contract_address: ContractAddress) -> u64;
    fn game_address_from_id(self: @TState, game_id: u64) -> ContractAddress;
    fn game_metadata(self: @TState, game_id: u64) -> GameMetadata;
    fn is_game_registered(self: @TState, contract_address: ContractAddress) -> bool;
    fn game_address(self: @TState, token_id: u64) -> ContractAddress;
    fn creator_token_id(self: @TState, game_id: u64) -> u64;
    fn client_url(self: @TState, token_id: u64) -> ByteArray;
    fn register_game(
        ref self: TState,
        creator_address: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        developer: ByteArray,
        publisher: ByteArray,
        genre: ByteArray,
        image: ByteArray,
        color: Option<ByteArray>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
    ) -> u64;
}
