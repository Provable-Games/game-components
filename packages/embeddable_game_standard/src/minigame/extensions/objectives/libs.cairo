use game_components_embeddable_game_standard::token_legacy::extensions::objectives::interface::{
    IMINIGAME_TOKEN_OBJECTIVES_ID, IMinigameTokenObjectivesDispatcher,
    IMinigameTokenObjectivesDispatcherTrait,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::ContractAddress;
use crate::minigame::extensions::objectives::structs::GameObjectiveDetails;


/// Announces a created objective to the minigame token contract, when it has
/// an objectives surface.
///
/// Same rationale as `settings::libs::create_settings`: the token-side call is
/// an indexer announcement, the game remains the source of truth, and
/// standard tokens (no objectives surface, no `IMINIGAME_TOKEN_OBJECTIVES_ID`
/// registration) skip the announcement instead of reverting.
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `game_address` - The address of the game contract creating the objective
/// * `creator_address` - The address of the creator
/// * `objective_id` - The ID of the objective to create
/// * `objective_details` - The objective details struct
pub fn create_objective(
    minigame_token_address: ContractAddress,
    game_address: ContractAddress,
    creator_address: ContractAddress,
    objective_id: u32,
    objective_details: GameObjectiveDetails,
) {
    let token_src5 = ISRC5Dispatcher { contract_address: minigame_token_address };
    if !token_src5.supports_interface(IMINIGAME_TOKEN_OBJECTIVES_ID) {
        return;
    }
    let minigame_token_dispatcher = IMinigameTokenObjectivesDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher
        .create_objective(game_address, creator_address, objective_id, objective_details);
}
// /// Asserts that an objective exists by checking the game contract
// ///
// /// # Arguments
// /// * `game_contract` - Reference to the game contract implementing IMinigameObjectives
// /// * `objective_id` - The ID of the objective to check
// pub fn assert_objective_exists<T, +crate::minigame::interface::IMinigameObjectives<T>>(
//     game_contract: @T, objective_id: u32,
// ) {
//     let objective_exists = game_contract.objective_exists(objective_id);
//     if !objective_exists {
//         panic!("Game: Objective ID {} does not exist", objective_id);
//     }
// }


