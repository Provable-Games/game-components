// Token structs
// Note: StorePacking implementations are in the token package for optimized storage
use starknet::ContractAddress;
use super::metagame::GameContextDetails;

#[derive(Copy, Drop, Serde)]
pub struct Lifecycle {
    pub start: u64,
    pub end: u64,
}

#[derive(Copy, Drop, Serde)]
pub struct TokenMetadata {
    pub game_id: u64,
    pub minted_at: u64,
    pub settings_id: u32,
    pub lifecycle: Lifecycle,
    pub minted_by: u64,
    pub soulbound: bool,
    pub game_over: bool,
    pub completed_objective: bool,
    pub has_context: bool,
    pub objective_id: u32,
    pub paymaster: bool,
    pub metadata: u16,
}

impl TokenMetadataDefault of Default<TokenMetadata> {
    fn default() -> TokenMetadata {
        TokenMetadata {
            game_id: 0,
            minted_at: 0,
            settings_id: 0,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 0,
            soulbound: false,
            game_over: false,
            completed_objective: false,
            has_context: false,
            objective_id: 0,
            paymaster: false,
            metadata: 0,
        }
    }
}

/// Per-token mint parameters for batch minting.
/// Contains all parameters for a single mint operation.
/// Note: Not Copy because it contains ByteArray and GameContextDetails.
#[derive(Drop, Serde)]
pub struct MintParams {
    pub game_address: ContractAddress,
    pub player_name: Option<felt252>,
    pub settings_id: Option<u32>,
    pub start: Option<u64>,
    pub end: Option<u64>,
    pub objective_id: Option<u32>,
    pub context: Option<GameContextDetails>,
    pub client_url: Option<ByteArray>,
    pub renderer_address: Option<ContractAddress>,
    pub to: ContractAddress,
    pub soulbound: bool,
    pub paymaster: bool,
    pub salt: u16,
    pub metadata: u16,
}

/// Per-token name update parameters for batch name updates
#[derive(Copy, Drop, Serde)]
pub struct PlayerNameUpdate {
    pub token_id: felt252,
    pub name: felt252,
}

