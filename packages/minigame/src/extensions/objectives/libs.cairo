use starknet::ContractAddress;
use crate::extensions::objectives::structs::GameObjective;
use game_components_token::extensions::objectives::interface::{
    IMinigameTokenObjectivesDispatcher, IMinigameTokenObjectivesDispatcherTrait,
};


/// Gets the objective IDs for a game token
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The token ID to get objectives for
///
/// # Returns
/// * `Span<u32>` - The objective IDs
pub fn get_objective_ids(minigame_token_address: ContractAddress, token_id: u64) -> Span<u32> {
    let token_objectives_dispatcher = IMinigameTokenObjectivesDispatcher {
        contract_address: minigame_token_address,
    };
    token_objectives_dispatcher.objective_ids(token_id)
}

/// Creates an objective in the minigame token contract
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `game_address` - The address of the game contract creating the objective
/// * `objective_id` - The ID of the objective to create
/// * `data` - The objective data
pub fn create_objective(
    minigame_token_address: ContractAddress,
    game_address: ContractAddress,
    creator_address: ContractAddress,
    objective_id: u32,
    name: ByteArray,
    value: ByteArray,
) {
    let objective = GameObjective { name: name.clone(), value: value.clone() };
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


