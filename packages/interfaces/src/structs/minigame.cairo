// Minigame structs

/// Descriptive metadata about a game — the shape a renderer needs to draw a
/// token's art and traits.
///

#[derive(Drop, Serde, Copy)]
pub struct GameDetail {
    pub name: felt252,
    pub value: felt252,
}

#[derive(Drop, Serde, Clone)]
pub struct GameSettingDetails {
    pub name: ByteArray,
    pub description: ByteArray,
    pub settings: Span<GameSetting>,
}

#[derive(Drop, Serde, Copy)]
pub struct GameSetting {
    pub name: felt252,
    pub value: felt252,
}

#[derive(Drop, Serde, Clone)]
pub struct GameObjectiveDetails {
    pub name: ByteArray,
    pub description: ByteArray,
    pub objectives: Span<GameObjective>,
}

#[derive(Drop, Serde, Copy)]
pub struct GameObjective {
    pub name: felt252,
    pub value: felt252,
}

/// A game's identity — what an indexer or client needs to display it.
/// Stored once per contract and served by `IMinigameGameMetadata`.
#[derive(Drop, Serde, Clone, starknet::Store)]
pub struct GameMetadata {
    pub name: ByteArray,
    pub description: ByteArray,
    pub developer: ByteArray,
    pub publisher: ByteArray,
    pub genre: ByteArray,
    pub image: ByteArray,
    pub color: ByteArray,
    pub client_url: ByteArray,
    /// Royalty fraction in basis points (e.g., 500 = 5%)
    pub royalty_fraction: u128,
}
