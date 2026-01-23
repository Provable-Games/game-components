use game_components_metagame::extensions::context::structs::GameContextDetails;
use starknet::ContractAddress;

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
}
