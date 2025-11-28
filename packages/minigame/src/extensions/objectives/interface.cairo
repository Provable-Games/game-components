use crate::extensions::objectives::structs::GameObjective;

pub const IMINIGAME_OBJECTIVES_ID: felt252 =
    0x0213cfcf73543e549f00c7cad49cf27a1e544d71315ff981930aaf77ac0709bd;

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
