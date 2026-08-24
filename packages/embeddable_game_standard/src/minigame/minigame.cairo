use core::num::traits::Zero;
use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
use game_components_embeddable_game_standard::registry::interface::{
    IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
};
use game_components_embeddable_game_standard::token_legacy::interface::{
    IMinigameTokenLegacyDispatcher, IMinigameTokenLegacyDispatcherTrait,
};
use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use starknet::ContractAddress;
use crate::minigame::structs::MintGameParams;

/// Performs pre-action validation for the game playability
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The game token ID to validate
pub fn pre_action(minigame_token_address: ContractAddress, token_id: felt252) {
    assert_game_token_playable(minigame_token_address, token_id);
}

/// Performs post-action updates to the game state
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The game token ID to update
pub fn post_action(minigame_token_address: ContractAddress, token_id: felt252) {
    let minigame_token_dispatcher = IMinigameTokenLegacyDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher.update_game(token_id);
}

/// Asserts that the specified token is owned by someone
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The token ID to check ownership for
pub fn require_owned_token(minigame_token_address: ContractAddress, token_id: felt252) {
    let erc721_dispatcher = IERC721Dispatcher { contract_address: minigame_token_address };
    let token_owner = erc721_dispatcher.owner_of(token_id.into());
    assert!(!token_owner.is_zero(), "Token {} does not exist or is not owned by anyone", token_id);
}

/// Asserts that the caller owns the specified token
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The token ID to check ownership for
pub fn assert_token_ownership(minigame_token_address: ContractAddress, token_id: felt252) {
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
pub fn assert_game_token_playable(minigame_token_address: ContractAddress, token_id: felt252) {
    let minigame_token_dispatcher = IMinigameTokenLegacyDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher.assert_is_playable(token_id);
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
/// * `client_url` - Optional client URL
/// * `renderer_address` - Optional renderer contract address
/// * `royalty_fraction` - Optional royalty fraction in basis points (e.g., 500 = 5%)
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
    royalty_fraction: Option<u128>,
    skills_address: Option<ContractAddress>,
    version: u64,
    license: Option<ByteArray>,
    fee_numerator: Option<u16>,
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
            royalty_fraction,
            skills_address,
            version,
            license,
            fee_numerator,
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
/// * `objective_id` - Optional objective ID
/// * `context` - Optional context data
/// * `client_url` - Optional client URL
/// * `renderer_address` - Optional renderer contract address
/// * `to` - Address to mint the token to
/// * `soulbound` - Whether the token should be soulbound
///
/// # Returns
/// * `felt252` - The minted token ID
pub fn mint(
    minigame_token_address: ContractAddress,
    game_address: ContractAddress,
    player_name: Option<felt252>,
    settings_id: Option<u32>,
    start: Option<u64>,
    end: Option<u64>,
    objective_id: Option<u32>,
    context: Option<GameContextDetails>,
    client_url: Option<ByteArray>,
    renderer_address: Option<ContractAddress>,
    skills_address: Option<ContractAddress>,
    to: ContractAddress,
    soulbound: bool,
    paymaster: bool,
    salt: u16,
    metadata: u16,
) -> felt252 {
    let minigame_token_dispatcher = IMinigameTokenLegacyDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher
        .mint(
            game_address,
            player_name,
            settings_id,
            start,
            end,
            objective_id,
            context,
            client_url,
            renderer_address,
            skills_address,
            to,
            soulbound,
            paymaster,
            salt,
            metadata,
        )
}

/// Mints multiple game tokens in batch through the denshokan contract
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `game_address` - The address of the game contract minting the tokens
/// * `mints` - Array of mint parameters for each token
///
/// # Returns
/// * `Array<felt252>` - Array of minted token IDs
pub fn mint_batch(
    minigame_token_address: ContractAddress,
    game_address: ContractAddress,
    mints: Array<MintGameParams>,
) -> Array<felt252> {
    let minigame_token_dispatcher = IMinigameTokenLegacyDispatcher {
        contract_address: minigame_token_address,
    };

    let mut token_ids: Array<felt252> = array![];
    let mut index: u32 = 0;
    while index < mints.len() {
        let mint_game_param = mints.at(index);

        // Clone non-copyable Option types
        let context_clone = match mint_game_param.context {
            Option::Some(ctx) => Option::Some(ctx.clone()),
            Option::None => Option::None,
        };
        let client_url_clone = match mint_game_param.client_url {
            Option::Some(url) => Option::Some(url.clone()),
            Option::None => Option::None,
        };

        let token_id = minigame_token_dispatcher
            .mint(
                game_address,
                *mint_game_param.player_name,
                *mint_game_param.settings_id,
                *mint_game_param.start,
                *mint_game_param.end,
                *mint_game_param.objective_id,
                context_clone,
                client_url_clone,
                *mint_game_param.renderer_address,
                *mint_game_param.skills_address,
                *mint_game_param.to,
                *mint_game_param.soulbound,
                *mint_game_param.paymaster,
                *mint_game_param.salt,
                *mint_game_param.metadata,
            );
        token_ids.append(token_id);
        index += 1;
    }

    token_ids
}

/// Gets the player name for a game token
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The token ID to get the player name for
///
/// # Returns
/// * `felt252` - The player name
pub fn get_player_name(minigame_token_address: ContractAddress, token_id: felt252) -> felt252 {
    let minigame_token_dispatcher = IMinigameTokenLegacyDispatcher {
        contract_address: minigame_token_address,
    };
    minigame_token_dispatcher.player_name(token_id)
}
