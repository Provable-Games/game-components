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
            completed_all_objectives: false,
            has_context: false,
            objectives_count: 0,
        }
    }
}
