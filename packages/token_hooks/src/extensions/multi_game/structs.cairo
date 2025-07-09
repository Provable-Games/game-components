#[derive(Drop, Serde, starknet::Store)]
pub struct GameMetadata {
    pub creator_token_id: u64,
    pub contract_address: starknet::ContractAddress,
    pub name: ByteArray,
    pub description: ByteArray,
    pub developer: ByteArray,
    pub publisher: ByteArray,
    pub genre: ByteArray,
    pub image: ByteArray,
    pub color: ByteArray,
    pub client_url: ByteArray,
    pub renderer_address: starknet::ContractAddress,
    pub settings_address: starknet::ContractAddress,
    pub objectives_address: starknet::ContractAddress,
}
