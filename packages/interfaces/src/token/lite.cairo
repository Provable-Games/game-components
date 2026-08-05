// Lite token interface — single-game, no mutable token state.
//
// Gas-optimized subset of `IMinigameToken` for deployments that embed exactly one
// game and let the game contract remain the sole authority on game-over /
// objective completion. The token stores no per-token mutable state: everything
// except `player_name` is unpacked from the token id itself, so every view is
// pure felt arithmetic plus at most one storage read.
//
// `mint` keeps the exact `IMinigameToken::mint` signature (same selector, same
// calldata layout) so existing call sites and the `minigame::mint` helper work
// unchanged against a lite deployment. Parameters the lite token does not
// support (objective_id, context, client_url, renderer_address, skills_address,
// paymaster, metadata) must be passed as `None`/`false`/`0` — the
// implementation rejects anything else loudly rather than silently ignoring it.
//
// Semantics that differ from the full token:
// * `is_playable`/`assert_is_playable` check the lifecycle window only. There
//   is no token-side `game_over`/`completed_objective` latch — ask the game.
// * `token_metadata` reports `game_over`/`completed_objective`/`completed_at`
//   as `false`/`0` unconditionally, for the same reason.
// * There is no `update_game` — nothing to sync. `refresh_metadata` (ERC-4906
//   emit) is the only post-action hook a game needs.
use starknet::ContractAddress;
use crate::structs::metagame::GameContextDetails;
use crate::structs::token::TokenMetadata;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors.
///
/// Surface is the trait below minus `refresh_metadata`/`refresh_metadata_batch`,
/// mirroring their exclusion from `IMINIGAME_TOKEN_ID`. Run `src5_rs parse`
/// against a stripped copy of this trait (see packages/interfaces/src/AGENTS.md)
/// to rederive.
pub const IMINIGAME_TOKEN_LITE_ID: felt252 =
    0x3ea3d599077fbe09ddbe82ff33c1abc87aef52d8609d8bf3508fdba8dd92056;

#[starknet::interface]
pub trait IMinigameTokenLite<TState> {
    fn token_metadata(self: @TState, token_id: felt252) -> TokenMetadata;
    fn is_playable(self: @TState, token_id: felt252) -> bool;
    fn assert_is_playable(self: @TState, token_id: felt252);
    /// Combined ownership + playability guard: one external call instead of
    /// `owner_of` followed by `assert_is_playable`. `expected_owner` is the
    /// game contract's caller (must be non-zero); panics unless it owns the
    /// token and the lifecycle window is open.
    fn assert_owner_and_playable(self: @TState, token_id: felt252, expected_owner: ContractAddress);
    fn settings_id(self: @TState, token_id: felt252) -> u32;
    fn player_name(self: @TState, token_id: felt252) -> felt252;
    fn minted_by(self: @TState, token_id: felt252) -> felt252;
    fn minted_by_address(self: @TState, token_id: felt252) -> ContractAddress;
    fn is_soulbound(self: @TState, token_id: felt252) -> bool;
    fn game_address(self: @TState) -> ContractAddress;
    /// Always returns the zero address — the lite token has no registry. Kept
    /// so `MinigameComponent::initializer`, which unconditionally queries the
    /// registry address before deciding whether to register the game, works
    /// against a lite deployment without modification.
    fn game_registry_address(self: @TState) -> ContractAddress;

    /// Signature-compatible with `IMinigameToken::mint`. `game_address` must be
    /// the single configured game; `objective_id`, `context`, `client_url`,
    /// `renderer_address`, `skills_address` must be `None`, `paymaster` must be
    /// `false`, and `metadata` must be `0`.
    fn mint(
        ref self: TState,
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
    ) -> felt252;
    /// Emits an ERC-4906 `MetadataUpdate` for `token_id` — see
    /// `IMinigameToken::refresh_metadata` for the spam/existence trade-offs;
    /// identical semantics here.
    fn refresh_metadata(ref self: TState, token_id: felt252);
    fn refresh_metadata_batch(ref self: TState, token_ids: Span<felt252>);
    fn update_player_name(ref self: TState, token_id: felt252, name: felt252);
}
