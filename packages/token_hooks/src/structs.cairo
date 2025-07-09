#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Lifecycle {
    pub start: u64,
    pub end: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TokenMetadata {
    pub game_id: u64,
    pub minted_at: u64,
    pub settings_id: u32,
    pub lifecycle: Lifecycle,
    pub minted_by: u64,
    pub soulbound: bool,
    pub game_over: bool,
    pub completed_all_objectives: bool,
    pub has_context: bool,
    pub objectives_count: u8,
}
