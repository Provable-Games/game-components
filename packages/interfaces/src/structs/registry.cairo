// Registry structs
use starknet::ContractAddress;

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
    /// Used by token contracts for ERC2981 royalty_info
    pub royalty_fraction: u128,
    /// Game-specific agent skill definitions for AI agent integration
    pub agent_skills: ByteArray,
    /// Timestamp when the game was registered
    pub created_at: u64,
}
