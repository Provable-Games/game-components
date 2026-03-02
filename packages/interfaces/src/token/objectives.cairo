// Token objectives extension interface
use starknet::ContractAddress;
use crate::structs::minigame::GameObjectiveDetails;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// -
/// create_objective(ContractAddress,ContractAddress,u32,((Array<bytes31>,felt252,usize),(Array<bytes31>,felt252,usize),(@Array<((Array<bytes31>,felt252,usize),(Array<bytes31>,felt252,usize))>)))
pub const IMINIGAME_TOKEN_OBJECTIVES_ID: felt252 =
    0x82edb5ff654d5a1b77ab3c2dce61b5a22fc1d8223eb615fcf3810b50430d04;

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
