// Minigame registry interface
use starknet::ContractAddress;
pub use crate::structs::registry::{GameFeeInfo, GameMetadata};

/// Default game fee in basis points (500 = 5%)
pub const DEFAULT_GAME_FEE_BPS: u16 = 500;

/// Fee denominator for basis points (10_000 = 100%)
pub const FEE_DENOMINATOR: u16 = 10_000;

/// Returns the default license text for the Embeddable Game Standard
pub fn default_license() -> ByteArray {
    "This game is licensed under the Embeddable Game Standard License v1.0. Monetization platforms must pay the declared game fee (default 5%) on revenue generated from this game."
}

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - game_count, game_id_from_address, game_address_from_id, game_metadata,
///   is_game_registered, register_game, set_game_royalty, skills_address,
///   game_metadata_batch, games_registered_batch, get_games,
///   get_games_by_developer, get_games_by_publisher, get_games_by_genre,
///   game_fee_info, default_game_fee_info, set_default_game_fee,
///   set_game_fee, reset_game_fee
pub const IMINIGAME_REGISTRY_ID: felt252 =
    0x2d4d61e5a2e608d8adab5fc69e6d35baff40ba85dadbd5f4ff0be139d4b69b5;

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
        version: u64,
        license: Option<ByteArray>,
        fee_numerator: Option<u16>,
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

    // Game fee functions (ERC2981-inspired)

    /// Returns game fee info for a specific game (override if set, else default).
    fn game_fee_info(self: @TState, game_id: u64) -> GameFeeInfo;

    /// Returns the default game fee info.
    fn default_game_fee_info(self: @TState) -> GameFeeInfo;

    /// Set the default license + fee for all games. Admin only.
    fn set_default_game_fee(ref self: TState, license: ByteArray, fee_numerator: u16);

    /// Override license + fee for a specific game. Creator token owner only.
    fn set_game_fee(ref self: TState, game_id: u64, license: ByteArray, fee_numerator: u16);

    /// Reset game fee back to default. Creator token owner only.
    fn reset_game_fee(ref self: TState, game_id: u64);
}
