use starknet::ContractAddress;
use game_components_minigame::extensions::objectives::structs::GameObjective;
use crate::extensions::objectives::structs::TokenObjective;

pub const IMINIGAME_TOKEN_OBJECTIVES_ID: felt252 =
    0x8bb87efb8f7d4c796d9138d561d415d0db463db97873626f104b6e660ed6cf;

#[starknet::interface]
pub trait IMinigameTokenObjectives<TState> {
    fn objectives_count(self: @TState, token_id: u64) -> u32;
    fn objectives(self: @TState, token_id: u64) -> Array<TokenObjective>;
    fn objective_ids(self: @TState, token_id: u64) -> Span<u32>;
    // fn objective_completed(self: @TState, token_id: u64, objective_id: u32) -> bool;
    fn all_objectives_completed(self: @TState, token_id: u64) -> bool;

    fn create_objective(
        ref self: TState,
        game_address: ContractAddress,
        objective_id: u32,
        objective_data: GameObjective,
    );
}
