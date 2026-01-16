use starknet::ContractAddress;

// ==============================================================================
// MINIGAME REGISTRY - Types and Interface
// ==============================================================================

pub const IMINIGAME_REGISTRY_ID: felt252 =
    0x014a8d6e4bf56a4bbf869257d1f846e5a2ac1e3508466147556f186143409be1;

#[derive(Drop, Serde, Clone, starknet::Store)]
pub struct GameMetadata {
    pub contract_address: ContractAddress,
    pub name: ByteArray,
    pub description: ByteArray,
    pub developer: ByteArray,
    pub publisher: ByteArray,
    pub genre: ByteArray,
    pub image: ByteArray,
    pub color: ByteArray,
    pub client_url: ByteArray,
    pub renderer_address: ContractAddress,
}

#[starknet::interface]
pub trait IMinigameRegistry<TState> {
    fn game_count(self: @TState) -> u64;
    fn game_id_from_address(self: @TState, contract_address: ContractAddress) -> u64;
    fn game_address_from_id(self: @TState, game_id: u64) -> ContractAddress;
    fn game_metadata(self: @TState, game_id: u64) -> GameMetadata;
    fn is_game_registered(self: @TState, contract_address: ContractAddress) -> bool;
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
