// Minigame objectives extension interface
use crate::structs::minigame::{GameObjective, GameObjectiveDetails};

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - objective_exists(u32)->E((),())
/// - completed_objective(felt252,u32)->E((),())
/// - objective_exists_batch((@Array<u32>))->Array<E((),())>
pub const IMINIGAME_OBJECTIVES_ID: felt252 =
    0xac0aaa451454d78741d9fafe803b69c8b31d073156020b08496104356db5e5;

#[starknet::interface]
pub trait IMinigameObjectives<TState> {
    fn objective_exists(self: @TState, objective_id: u32) -> bool;
    fn completed_objective(self: @TState, token_id: felt252, objective_id: u32) -> bool;

    // Batch operations
    fn objective_exists_batch(self: @TState, objective_ids: Span<u32>) -> Array<bool>;
}

#[starknet::interface]
pub trait IMinigameObjectivesDetails<TState> {
    fn objectives_count(self: @TState) -> u32;
    fn objectives_details(self: @TState, objective_id: u32) -> GameObjectiveDetails;
    fn objective_settings_id(self: @TState, objective_id: u32) -> u32;

    // Batch operations
    fn objectives_details_batch(
        self: @TState, objective_ids: Span<u32>,
    ) -> Array<GameObjectiveDetails>;
    fn objective_settings_id_batch(self: @TState, objective_ids: Span<u32>) -> Array<u32>;
}

#[starknet::interface]
pub trait IMinigameObjectivesSVG<TState> {
    fn objectives_svg(self: @TState, objective_id: u32) -> ByteArray;
}
