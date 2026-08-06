// Lite-token twins of `minigame::minigame::pre_action` / `post_action`.
//
// Same call-site shape as the full-token helpers, different token contract and
// deliberately different semantics — the module path is what signals the shift:
//
// * `pre_action` folds the old `assert_token_ownership` + `pre_action` pair
//   into ONE cross-contract call. The lite token checks that this contract's
//   caller owns the token and that the lifecycle window is open. There is no
//   token-side game_over/objective latch to consult — with the lite token the
//   game contract is the sole authority on those, and must gate finished runs
//   itself.
// * `post_action` emits an ERC-4906 refresh and nothing else. There is no
//   `update_game` on the lite token and no state to sync back.
//
// Like the full-token helpers, these are free functions that run in the game
// contract's own execution context, so `get_caller_address()` inside
// `pre_action` is the game's caller (the player).
use starknet::{ContractAddress, get_caller_address};
use crate::token_lite::interface::{IMinigameTokenLiteDispatcher, IMinigameTokenLiteDispatcherTrait};

/// Asserts the game's caller owns `token_id` and its lifecycle window is open.
/// One external call — replaces the full-token `assert_token_ownership` +
/// `pre_action` pair.
pub fn pre_action(minigame_token_address: ContractAddress, token_id: felt252) {
    IMinigameTokenLiteDispatcher { contract_address: minigame_token_address }
        .assert_owner_and_playable(token_id, get_caller_address());
}

/// Emits a state-free ERC-4906 `MetadataUpdate` for `token_id` so indexers and
/// marketplaces observe the action. Writes nothing; safe to call while the
/// roll's outcome is sealed.
pub fn post_action(minigame_token_address: ContractAddress, token_id: felt252) {
    IMinigameTokenLiteDispatcher { contract_address: minigame_token_address }
        .refresh_metadata(token_id);
}
