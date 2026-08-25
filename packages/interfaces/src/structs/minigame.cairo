// Minigame structs
use starknet::ContractAddress;
use super::metagame::GameContextDetails;

/// Descriptive metadata about a game — the shape a renderer needs to draw a
/// token's art and traits.
///
/// This was the registry's stored record. With the registry retired it is no
/// longer read from anywhere on-chain: it is an INPUT a caller assembles and
/// hands to the renderer. The fields are unchanged so existing renderers and
/// indexers keep working.
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
    /// Royalty fraction in basis points (e.g., 500 = 5%)
    pub royalty_fraction: u128,
    /// Contract address providing agent skill definitions for AI agent integration
    pub skills_address: ContractAddress,
    /// Timestamp when the game was registered
    pub created_at: u64,
    /// Version number for game contract versioning
    pub version: u64,
}

#[derive(Drop, Serde, Copy)]
pub struct GameDetail {
    pub name: felt252,
    pub value: felt252,
}

/// Parameters for minting a game token in batch operations
#[derive(Drop, Serde)]
pub struct MintGameParams {
    pub player_name: Option<felt252>,
    pub settings_id: Option<u32>,
    pub start: Option<u64>,
    pub end: Option<u64>,
    pub objective_id: Option<u32>,
    pub context: Option<GameContextDetails>,
    pub client_url: Option<ByteArray>,
    pub renderer_address: Option<ContractAddress>,
    pub skills_address: Option<ContractAddress>,
    pub to: ContractAddress,
    pub soulbound: bool,
    pub paymaster: bool,
    pub salt: u16,
    pub metadata: u16,
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
