// Helpers for contracts that hold or act on someone else's game token.
//
// A game does not need these: it embeds `MinigameTokenComponent` and uses the
// component's internal `assert_owner_and_playable`, which costs zero syscalls.
// These are for a SEPARATE contract — a minter, a dungeon, a tournament —
// reading the token over a dispatcher.

use game_components_interfaces::token::core::{
    IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use starknet::ContractAddress;

/// Asserts the caller owns `token_id` on `token_address`.
pub fn assert_token_ownership(token_address: ContractAddress, token_id: felt252) {
    let token_owner = IERC721Dispatcher { contract_address: token_address }
        .owner_of(token_id.into());
    assert!(
        token_owner == starknet::get_caller_address(), "Caller is not owner of token {}", token_id,
    );
}

/// Reads the player name recorded on the token at mint.
pub fn get_player_name(token_address: ContractAddress, token_id: felt252) -> felt252 {
    IMinigameTokenDispatcher { contract_address: token_address }.player_name(token_id)
}
