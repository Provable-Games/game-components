use game_components_embeddable_game_standard::token::core::interface::{
    IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use game_components_embeddable_game_standard::token::extensions::settings::interface::{
    IMinigameTokenSettingsDispatcher, IMinigameTokenSettingsDispatcherTrait,
};
use starknet::ContractAddress;
use crate::minigame::extensions::settings::structs::GameSettingDetails;

/// Gets the settings ID for a game token
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The token ID to get settings for
///
/// # Returns
/// * `u32` - The settings ID
pub fn get_settings_id(minigame_token_address: ContractAddress, token_id: felt252) -> u32 {
    let minigame_token_dispatcher = IMinigameTokenDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher.settings_id(token_id)
}

/// Creates settings in the minigame token contract
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `game_address` - The address of the game contract creating the settings
/// * `creator_address` - The address of the creator
/// * `settings_id` - The ID of the settings to create
/// * `settings_details` - The settings details (name, description, settings)
pub fn create_settings(
    minigame_token_address: ContractAddress,
    game_address: ContractAddress,
    creator_address: ContractAddress,
    settings_id: u32,
    settings_details: GameSettingDetails,
) {
    let minigame_token_dispatcher = IMinigameTokenSettingsDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher
        .create_settings(game_address, creator_address, settings_id, settings_details);
}
// /// Asserts that a setting exists by checking the game contract
// ///
// /// # Arguments
// /// * `game_contract` - Reference to the game contract implementing IMinigameSettings
// /// * `settings_id` - The ID of the setting to check
// pub fn assert_settings_exist(settings_id: u32) {
//     let setting_exists = minigame_token_dispatcher.settings_exist(settings_id);
//     if !setting_exists {
//         panic!("Game: Setting ID {} does not exist", settings_id);
//     }
// }


