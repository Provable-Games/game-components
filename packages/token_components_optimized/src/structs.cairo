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

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Lifecycle {
    pub start: u64,
    pub end: u64,
}

impl LifecycleDefault of Default<Lifecycle> {
    fn default() -> Lifecycle {
        Lifecycle {
            minted_at: 0,
            last_used: 0,
            usage_count: 0,
        }
    }
}

impl TokenMetadataDefault of Default<TokenMetadata> {
    fn default() -> TokenMetadata {
        TokenMetadata {
            token_id: 0,
            game_address: starknet::contract_address_const::<0>(),
            player_name: "",
            image: "",
            minted_by: 0,
            lifecycle: Default::default(),
            settings_id: 0,
            objectives_count: 0,
            is_soulbound: false,
            renderer_address: starknet::contract_address_const::<0>(),
        }
    }
} 