// Token objectives extension interface
use starknet::ContractAddress;
use crate::structs::minigame::GameObjectiveDetails;

pub const IMINIGAME_TOKEN_OBJECTIVES_ID: felt252 =
    0x8bb87efb8f7d4c796d9138d561d415d0db463db97873626f104b6e660ed6cf;

#[starknet::interface]
pub trait IMinigameTokenObjectives<TState> {
    fn create_objective(
        ref self: TState,
        game_address: ContractAddress,
        creator_address: ContractAddress,
        objective_id: u32,
        objective_details: GameObjectiveDetails,
    );
}
