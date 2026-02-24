#[derive(Drop, Serde, Clone, starknet::Store)]
pub enum GameExpiration {
    #[default]
    None,
    Fixed: u64,
    Dynamic: u64,
}

#[derive(Drop, Serde, Clone, starknet::Store)]
pub struct GoldenPass {
    pub cooldown: u64,
    pub game_expiration: GameExpiration,
    pub pass_expiration: u64,
}

#[derive(Drop, Serde, Clone)]
pub struct GoldenPassInfo {
    pub address: starknet::ContractAddress,
    pub token_id: u128,
}

#[derive(Drop, Serde, Clone)]
pub enum PaymentType {
    Ticket,
    GoldenPass: GoldenPassInfo,
}
