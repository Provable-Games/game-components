#[derive(Drop, Serde)]
pub struct GameSettingDetails {
    pub name: ByteArray,
    pub description: ByteArray,
    pub settings: Span<GameSetting>,
}

#[derive(Drop, Serde)]
pub struct GameSetting {
    pub name: ByteArray,
    pub value: ByteArray,
}
