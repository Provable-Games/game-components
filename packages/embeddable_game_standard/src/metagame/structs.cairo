use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
use starknet::ContractAddress;

/// Parameters for minting a token in batch operations through metagame
#[derive(Drop, Serde)]
pub struct MintMetagameParams {
    pub game_address: ContractAddress,
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
