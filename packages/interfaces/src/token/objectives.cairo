// Token objectives extension interface
use starknet::ContractAddress;
use crate::structs::minigame::GameObjectiveDetails;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// -
/// create_objective(ContractAddress,ContractAddress,u32,((Array<bytes31>,felt252,usize),(Array<bytes31>,felt252,usize),(@Array<(felt252,felt252)>)))
pub const IMINIGAME_TOKEN_OBJECTIVES_ID: felt252 =
    0x1e9f4982a68b67ddda6e894e8e620fe12ae877cf303308fe16814ceb2706077;

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
