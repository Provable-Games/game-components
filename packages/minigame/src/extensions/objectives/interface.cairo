use crate::extensions::objectives::structs::GameObjective;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - objective_exists(u32)->E((),())
/// - completed_objective(u64,u32)->E((),())
pub const IMINIGAME_OBJECTIVES_ID: felt252 =
    0x28169a0897c7968558950f765729c88209b858de3a02a2b06ea0931e3f5415d;

#[starknet::interface]
pub trait IMinigameObjectives<TState> {
    fn objective_exists(self: @TState, objective_id: u32) -> bool;
    fn completed_objective(self: @TState, token_id: u64, objective_id: u32) -> bool;
}

#[starknet::interface]
pub trait IMinigameObjectivesDetails<TState> {
    fn objectives_details(self: @TState, token_id: u64) -> Span<GameObjective>;
}

#[starknet::interface]
pub trait IMinigameObjectivesSVG<TState> {
    fn objectives_svg(self: @TState, token_id: u64) -> ByteArray;
}
