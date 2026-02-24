// Token objectives extension interface
use starknet::ContractAddress;
use crate::structs::minigame::GameObjectiveDetails;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - create_objective(ContractAddress,ContractAddress,u32,u32,GameObjectiveDetails)
pub const IMINIGAME_TOKEN_OBJECTIVES_ID: felt252 =
    0x2c9b37fb2982c9480e67f2da4c7730a8cde17b5fb021f3d530305f2f3a0b929;

#[starknet::interface]
pub trait IMinigameTokenObjectives<TState> {
    fn create_objective(
        ref self: TState,
        game_address: ContractAddress,
        creator_address: ContractAddress,
        objective_id: u32,
        settings_id: u32,
        objective_details: GameObjectiveDetails,
    );
}
