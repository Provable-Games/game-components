use game_components_token::core::interface::{
    IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use game_components_token::examples::minigame_registry_contract::{
    IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
};
use game_components_metagame::extensions::context::structs::GameContextDetails;
use starknet::ContractAddress;
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

/// Performs pre-action validation for the game playability
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The game token ID to validate
pub fn pre_action(minigame_token_address: ContractAddress, token_id: u64) {
    assert_game_token_playable(minigame_token_address, token_id);
}

/// Performs post-action updates to the game state
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The game token ID to update
pub fn post_action(minigame_token_address: ContractAddress, token_id: u64) {
    let minigame_token_dispatcher = IMinigameTokenDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher.update_game(token_id);
}

/// Asserts that the caller owns the specified token
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The token ID to check ownership for
pub fn assert_token_ownership(minigame_token_address: ContractAddress, token_id: u64) {
    let erc721_dispatcher = IERC721Dispatcher { contract_address: minigame_token_address };
    let token_owner = erc721_dispatcher.owner_of(token_id.into());
    assert!(
        token_owner == starknet::get_caller_address(), "Caller is not owner of token {}", token_id,
    );
}

/// Asserts that the game token is in a playable state
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The token ID to check playability for
pub fn assert_game_token_playable(minigame_token_address: ContractAddress, token_id: u64) {
    let minigame_token_dispatcher = IMinigameTokenDispatcher {
        contract_address: minigame_token_address,
    };
    let is_playable = minigame_token_dispatcher.is_playable(token_id);
    assert!(is_playable, "Game is not playable");
}

/// Registers a game with the denshokan contract
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `creator_address` - The address of the game creator
/// * `name` - The name of the game
/// * `description` - The description of the game
/// * `developer` - The developer of the game
/// * `publisher` - The publisher of the game
/// * `genre` - The genre of the game
/// * `image` - The image URL of the game
/// * `color` - Optional color theme for the game
/// * `renderer_address` - Optional renderer contract address
pub fn register_game(
    minigame_token_address: ContractAddress,
    creator_address: ContractAddress,
    name: ByteArray,
    description: ByteArray,
    developer: ByteArray,
    publisher: ByteArray,
    genre: ByteArray,
    image: ByteArray,
    color: Option<ByteArray>,
    client_url: Option<ByteArray>,
    renderer_address: Option<ContractAddress>,
) {
    let minigame_token_dispatcher = IMinigameRegistryDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher
        .register_game(
            creator_address,
            name,
            description,
            developer,
            publisher,
            genre,
            image,
            color,
            client_url,
            renderer_address,
        );
}

/// Mints a game token through the denshokan contract
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
    game_address: ContractAddress,
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
            Option::Some(game_address),
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

/// Gets the player name for a game token
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The token ID to get the player name for
///
/// # Returns
/// * `felt252` - The player name
pub fn get_player_name(minigame_token_address: ContractAddress, token_id: u64) -> ByteArray {
    let minigame_token_dispatcher = IMinigameTokenDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher.player_name(token_id)
}
