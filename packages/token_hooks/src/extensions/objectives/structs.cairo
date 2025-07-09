#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TokenObjective {
    pub objective_id: u32,
    pub completed: bool,
}
