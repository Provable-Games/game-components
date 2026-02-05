use game_components_token::extensions::objectives::interface::{
    IMinigameTokenObjectivesDispatcher, IMinigameTokenObjectivesDispatcherTrait,
};
use starknet::ContractAddress;
use crate::extensions::objectives::structs::GameObjective;


/// Creates an objective in the minigame token contract
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `game_address` - The address of the game contract creating the objective
/// * `creator_address` - The address of the creator
/// * `objective_id` - The ID of the objective to create
/// * `objective` - The objective data (name, value)
pub fn create_objective(
    minigame_token_address: ContractAddress,
    game_address: ContractAddress,
    creator_address: ContractAddress,
    objective_id: u32,
    objective: GameObjective,
) {
    let minigame_token_dispatcher = IMinigameTokenObjectivesDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher
        .create_objective(game_address, creator_address, objective_id, objective);
}
// /// Asserts that an objective exists by checking the game contract
// ///
// /// # Arguments
// /// * `game_contract` - Reference to the game contract implementing IMinigameObjectives
// /// * `objective_id` - The ID of the objective to check
// pub fn assert_objective_exists<T, +crate::interface::IMinigameObjectives<T>>(
//     game_contract: @T, objective_id: u32,
// ) {
//     let objective_exists = game_contract.objective_exists(objective_id);
//     if !objective_exists {
//         panic!("Game: Objective ID {} does not exist", objective_id);
//     }
// }


