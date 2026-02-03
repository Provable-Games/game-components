// Minigame registry interface
use starknet::ContractAddress;
pub use crate::structs::registry::GameMetadata;

pub const IMINIGAME_REGISTRY_ID: felt252 =
    0x014a8d6e4bf56a4bbf869257d1f846e5a2ac1e3508466147556f186143409be1;

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
        royalty_fraction: Option<u128>,
    ) -> u64;
    /// Set the royalty fraction for a game.
    /// Only the owner of the game creator token (game_id) can call this.
    /// royalty_fraction is in basis points (e.g., 500 = 5%)
    fn set_game_royalty(ref self: TState, game_id: u64, royalty_fraction: u128);

    // Batch view functions
    fn game_metadata_batch(self: @TState, game_ids: Span<u64>) -> Array<GameMetadata>;
    fn games_registered_batch(self: @TState, addresses: Span<ContractAddress>) -> Array<bool>;
    fn get_games(self: @TState, start: u64, count: u64) -> Array<GameMetadata>;

    // Filtered view functions
    fn get_games_by_developer(
        self: @TState, developer: ByteArray, start: u64, count: u64,
    ) -> Array<GameMetadata>;
    fn get_games_by_publisher(
        self: @TState, publisher: ByteArray, start: u64, count: u64,
    ) -> Array<GameMetadata>;
    fn get_games_by_genre(
        self: @TState, genre: ByteArray, start: u64, count: u64,
    ) -> Array<GameMetadata>;
}
