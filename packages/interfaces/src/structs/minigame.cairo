// Minigame structs
use starknet::ContractAddress;
use super::metagame::GameContextDetails;

#[derive(Drop, Serde)]
pub struct GameDetail {
    pub name: ByteArray,
    pub value: ByteArray,
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
    pub to: ContractAddress,
    pub soulbound: bool,
    pub paymaster: bool,
    pub salt: u16,
    pub metadata: u16,
}

#[derive(Drop, Serde)]
pub struct GameSettingDetails {
    pub name: ByteArray,
    pub description: ByteArray,
    pub settings: Span<GameSetting>,
}

#[derive(Drop, Serde)]
pub struct GameSetting {
    pub name: ByteArray,
    pub value: ByteArray,
}

#[derive(Drop, Serde)]
pub struct GameObjectiveDetails {
    pub name: ByteArray,
    pub description: ByteArray,
    pub objectives: Span<GameObjective>,
}

#[derive(Drop, Serde)]
pub struct GameObjective {
    pub name: ByteArray,
    pub value: ByteArray,
}
