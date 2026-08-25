// Token helpers for game contracts.
//
// These are plain reads against the game's token: ERC721 ownership, and the
// player name off the token standard. They carry no generation-specific
// assumptions, which is why they outlived the registry-backed generation that
// the rest of this module served.
//
// What was removed with that generation: `pre_action` / `post_action` (they
// called `update_game`, which no longer exists — there is no mutable token
// state to sync), `assert_game_token_playable` (the token's ABI guard is gone;
// the embedding game calls the component's internal
// `assert_owner_and_playable`, which costs zero syscalls), `register_game`,
// and the `mint` / `mint_batch` wrappers.
//
// For a self-bound game these take the game's own address: the game IS its
// token.

use core::num::traits::Zero;
use game_components_interfaces::token::core::{
    IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use starknet::ContractAddress;

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
/// A game that also needs the lifecycle window checked should prefer the token
/// component's internal `assert_owner_and_playable`, which does both with zero
/// syscalls. This is for the ownership question on its own, or when the token
/// is a separate contract from the caller.
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

/// Reads the player name stored on the token at mint.
///
/// # Arguments
/// * `minigame_token_address` - The address of the minigame token contract
/// * `token_id` - The token ID to get the player name for
///
/// # Returns
/// * `felt252` - The player name
pub fn get_player_name(minigame_token_address: ContractAddress, token_id: felt252) -> felt252 {
    IMinigameTokenDispatcher { contract_address: minigame_token_address }.player_name(token_id)
}
