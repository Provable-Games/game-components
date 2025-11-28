#[derive(Drop, Serde)]
pub struct GameObjective {
    pub name: ByteArray,
    pub value: ByteArray,
}
