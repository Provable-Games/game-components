// Metagame structs (without StorePacking - those stay in original package)

#[derive(Drop, Serde, Clone)]
pub struct GameContextDetails {
    pub name: ByteArray,
    pub description: ByteArray,
    pub id: Option<u32>,
    pub context: Span<GameContext>,
}

#[derive(Drop, Serde, Copy, Clone)]
pub struct GameContext {
    pub name: felt252,
    pub value: felt252,
}
