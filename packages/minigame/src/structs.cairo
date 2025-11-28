#[derive(Drop, Serde)]
pub struct GameDetail {
    pub name: ByteArray,
    pub value: ByteArray,
}
