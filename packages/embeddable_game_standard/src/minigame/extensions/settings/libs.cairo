use game_components_interfaces::token::core::{
    IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use starknet::ContractAddress;

/// Gets the settings ID for a game token
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The token ID to get settings for
///
/// # Returns
/// * `u32` - The settings ID
pub fn get_settings_id(minigame_token_address: ContractAddress, token_id: felt252) -> u32 {
    IMinigameTokenDispatcher { contract_address: minigame_token_address }.settings_id(token_id)
}
// A `create_settings` announcement lived here: it dispatched to the token's
// settings surface so indexers saw a `SettingsCreated` event. That surface
// belonged to the retired token generation and the standard token never had
// one — the announcement already SRC5-probed and skipped for standard tokens,
// so with the retired generation gone it could only ever skip. It is removed
// rather than left as a call that does nothing.
//
// Nothing is lost functionally: the token side stored nothing, and the game
// contract remains the source of truth for which settings exist
// (`settings_exist` answers from the game). Indexers that consumed the
// token-side event read it from the game's own `SettingsCreated` instead.


