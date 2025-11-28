#[derive(Drop, Serde, Clone)]
pub struct GameContextDetails {
    pub name: ByteArray,
    pub description: ByteArray,
    pub id: Option<u32>,
    pub context: Span<GameContext>,
}

#[derive(Drop, Serde, Clone)]
pub struct GameContext {
    pub name: ByteArray,
    pub value: ByteArray,
}
