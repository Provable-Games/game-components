// Minigame registry interface
use starknet::ContractAddress;
pub use crate::structs::registry::GameMetadata;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - game_count, game_id_from_address, game_address_from_id, game_metadata,
///   is_game_registered, register_game, set_game_royalty, skills_address,
///   game_metadata_batch, games_registered_batch, get_games,
///   get_games_by_developer, get_games_by_publisher, get_games_by_genre
pub const IMINIGAME_REGISTRY_ID: felt252 =
    0x1c12eed2dacd6f7cc81a6f01d1f65248ab5baae392d7baa5f9ffc3593d25803;

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
        skills_address: Option<ContractAddress>,
    ) -> u64;
    /// Set the royalty fraction for a game.
    /// Only the owner of the game creator token (game_id) can call this.
    /// royalty_fraction is in basis points (e.g., 500 = 5%)
    fn set_game_royalty(ref self: TState, game_id: u64, royalty_fraction: u128);

    // Batch view functions
    fn game_metadata_batch(self: @TState, game_ids: Span<u64>) -> Array<GameMetadata>;
    fn games_registered_batch(self: @TState, addresses: Span<ContractAddress>) -> Array<bool>;
    fn get_games(self: @TState, start: u64, count: u64) -> Array<GameMetadata>;

    /// Get the skills address for a registered game
    fn skills_address(self: @TState, game_id: u64) -> ContractAddress;

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
