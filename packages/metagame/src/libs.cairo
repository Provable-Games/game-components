use game_components_metagame::extensions::context::structs::GameContextDetails;
use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
use game_components_registry::interface::{
    IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
};
use game_components_token::core::interface::{
    IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use starknet::ContractAddress;
use crate::structs::MintMetagameParams;

/// Asserts that a game is registered in the minigame token contract
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `game_address` - The address of the game contract to check
pub fn assert_game_registered(game_address: ContractAddress) {
    let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
    let minigame_token_address = minigame_dispatcher.token_address();
    let minigame_token_dispatcher = IMinigameTokenDispatcher {
        contract_address: minigame_token_address,
    };
    let minigame_registry_address = minigame_token_dispatcher.game_registry_address();
    let minigame_registry_dispatcher = IMinigameRegistryDispatcher {
        contract_address: minigame_registry_address,
    };
    let game_exists = minigame_registry_dispatcher.is_game_registered(game_address);
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
/// * `objective_id` - Optional objective ID
/// * `context` - Optional context data
/// * `client_url` - Optional client URL
/// * `renderer_address` - Optional renderer contract address
/// * `to` - Address to mint the token to
/// * `soulbound` - Whether the token should be soulbound
///
/// # Returns
/// * `u64` - The minted token ID
pub fn mint(
    default_token_address: ContractAddress,
    game_address: Option<ContractAddress>,
    player_name: Option<felt252>,
    settings_id: Option<u32>,
    start: Option<u64>,
    end: Option<u64>,
    objective_id: Option<u32>,
    context: Option<GameContextDetails>,
    client_url: Option<ByteArray>,
    renderer_address: Option<ContractAddress>,
    to: ContractAddress,
    soulbound: bool,
) -> u64 {
    match game_address {
        // If the game address is provided, mint a token through the token contract the game
        // supports (could include its own game registry)
        Option::Some(game_address) => {
            let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
            let minigame_token_address = minigame_dispatcher.token_address();
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
                    objective_id,
                    context,
                    client_url,
                    renderer_address,
                    to,
                    soulbound,
                )
        },
        // If no game address is provided, mint a token through the default token contract (blank
        // game)
        Option::None => {
            let minigame_token_dispatcher = IMinigameTokenDispatcher {
                contract_address: default_token_address,
            };
            minigame_token_dispatcher
                .mint(
                    Option::None,
                    player_name,
                    settings_id,
                    start,
                    end,
                    objective_id,
                    context,
                    client_url,
                    renderer_address,
                    to,
                    soulbound,
                )
        },
    }
}

/// Mints multiple game tokens in batch through minigame token contracts
///
/// # Arguments
/// * `default_token_address` - The default token address for minting when no game_address is
/// provided * `mints` - Array of mint parameters for each token
///
/// # Returns
/// * `Array<u64>` - Array of minted token IDs
pub fn mint_batch(
    default_token_address: ContractAddress, mints: Array<MintMetagameParams>,
) -> Array<u64> {
    let mut token_ids = array![];
    let mut index = 0;

    loop {
        if index >= mints.len() {
            break;
        }

        let mint_param = mints.at(index);

        // Clone non-copyable Option types
        let context_clone = match mint_param.context {
            Option::Some(ctx) => Option::Some(ctx.clone()),
            Option::None => Option::None,
        };

        let client_url_clone = match mint_param.client_url {
            Option::Some(url) => Option::Some(url.clone()),
            Option::None => Option::None,
        };

        let token_id = mint(
            default_token_address,
            *mint_param.game_address,
            *mint_param.player_name,
            *mint_param.settings_id,
            *mint_param.start,
            *mint_param.end,
            *mint_param.objective_id,
            context_clone,
            client_url_clone,
            *mint_param.renderer_address,
            *mint_param.to,
            *mint_param.soulbound,
        );

        token_ids.append(token_id);
        index += 1;
    }

    token_ids
}
