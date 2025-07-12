use game_components_token::core::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use game_components_token::examples::multi_game_contract::{
    IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
};
use game_components_metagame::extensions::context::structs::GameContextDetails;
use starknet::ContractAddress;

/// Asserts that a game is registered in the minigame token contract
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `game_address` - The address of the game contract to check
pub fn assert_game_registered(
    minigame_token_address: ContractAddress, game_address: ContractAddress,
) {
    let minigame_token_dispatcher = IMinigameRegistryDispatcher {
        contract_address: minigame_token_address,
    };
    let game_exists = minigame_token_dispatcher.is_game_registered(game_address);
    assert!(game_exists, "Game is not registered");
}

/// Mints a game token through the minigame token contract
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `game_address` - The address of the game contract minting the token
/// * `player_name` - Optional player name
/// * `settings_id` - Optional settings ID
/// * `start` - Optional start time
/// * `end` - Optional end time
/// * `objective_ids` - Optional objective IDs
/// * `context` - Optional context data
/// * `client_url` - Optional client URL
/// * `renderer_address` - Optional renderer contract address
/// * `to` - Address to mint the token to
/// * `soulbound` - Whether the token should be soulbound
///
/// # Returns
/// * `u64` - The minted token ID
pub fn mint(
    minigame_token_address: ContractAddress,
    game_address: Option<ContractAddress>,
    player_name: Option<ByteArray>,
    settings_id: Option<u32>,
    start: Option<u64>,
    end: Option<u64>,
    objective_ids: Option<Span<u32>>,
    context: Option<GameContextDetails>,
    client_url: Option<ByteArray>,
    renderer_address: Option<ContractAddress>,
    to: ContractAddress,
    soulbound: bool,
) -> u64 {
    let minigame_token_dispatcher = IMinigameTokenDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher
        .mint(
            game_address,
            player_name,
            settings_id,
            start,
            end,
            objective_ids,
            context,
            client_url,
            renderer_address,
            to,
            soulbound,
        )
}
