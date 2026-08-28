// Minigame structs

/// Descriptive metadata about a game — the shape a renderer needs to draw a
/// token's art and traits.
///

#[derive(Drop, Serde, Copy)]
pub struct GameDetail {
    pub name: felt252,
    pub value: felt252,
}

#[derive(Drop, Serde, Clone)]
pub struct GameSettingDetails {
    pub name: ByteArray,
    pub description: ByteArray,
    pub settings: Span<GameSetting>,
}

#[derive(Drop, Serde, Copy)]
pub struct GameSetting {
    pub name: felt252,
    pub value: felt252,
}

#[derive(Drop, Serde, Clone)]
pub struct GameObjectiveDetails {
    pub name: ByteArray,
    pub description: ByteArray,
    pub objectives: Span<GameObjective>,
}

#[derive(Drop, Serde, Copy)]
pub struct GameObjective {
    pub name: felt252,
    pub value: felt252,
}
