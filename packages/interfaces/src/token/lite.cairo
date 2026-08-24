// Lite token interface — single-game, no mutable token state.
//
// Surface for one-address deployments: the implementing component is embedded
// IN the game contract, so the game and the token are always the same
// contract, and the game contract remains the sole authority on game-over /
// objective completion. The token stores no per-token mutable state except
// `player_name` and `client_url`: every other view is unpacked from the token
// id itself.
//
// Token ids use the lite-native 251-bit layout (see
// `game_components_embeddable_game_standard::token_lite::packing`), NOT the
// full token's layout. Indexers must branch their token-id decoder by
// contract generation.
//
// Strip principle: dead MACHINERY and compat shims are deleted; CAPABILITY
// (writes) and cheap client-facing read views stay.
// * `game_address` / `game_registry_address` — gone: the pairing is
//   self == self; consumers probe `IMINIGAME_TOKEN_LITE_ID` via SRC5 instead
//   of resolving addresses.
// * `assert_is_playable` / `assert_owner_and_playable` — gone from the ABI:
//   the embedding game's own guards, internal calls now
//   (`CoreTokenLiteComponent::InternalTrait`); clients use `is_playable`.
// * `refresh_metadata_batch` — gone: a multicall of singles.
// * The full token's `game_address`, `renderer_address` and `skills_address`
//   mint parameters are gone (self-bound; no per-token renderer/skills).
//
// Mint parameters kept WITH their original full-token behaviors:
// * `objective_id` — packed into the id as inert data the game interprets;
//   the lite token has no completion machinery (`completed_objective` in
//   `token_metadata` stays always-false).
// * `context` — sets the id's has_context bit only; the data itself is NOT
//   stored (full-token parity: its context hook was a documented no-op and
//   token_uri sourced context from the minter at render time).
// * `client_url` — storage-backed, readable via `client_url(token_id)`.
// * `paymaster` — packed bit.
// * `metadata` — widened from the full token's u16 to a u128 holding a
//   65-bit packed field; read via `mint_metadata(token_id)`.
//
// Semantics that differ from the full token:
// * `is_playable` checks the lifecycle window only. There is no token-side
//   `game_over`/`completed_objective` latch — ask the game.
// * `token_metadata` reports `game_over`/`completed_objective`/`completed_at`
//   as `false`/`0` unconditionally, for the same reason, and its u16
//   `metadata` field as 0 (the 65-bit packed value cannot fit — use
//   `mint_metadata`).
// * There is no `update_game` — nothing to sync. `refresh_metadata`
//   (ERC-4906 emit) is the only post-action hook a game needs.
use starknet::ContractAddress;
use crate::structs::metagame::GameContextDetails;
use crate::structs::token::{MintBatchRecipient, TokenMetadata};

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors.
///
/// Surface is the trait below minus `refresh_metadata`, mirroring the
/// refresh-function exclusion from `IMINIGAME_TOKEN_ID`. Run `src5_rs parse`
/// against a stripped copy of this trait (see packages/interfaces/src/AGENTS.md)
/// to rederive:
/// token_metadata: 0x1ebdf5dc7aab5a2b9bd68eb3a453bfb8025371633679db9d0d918cf87f92dd0
/// is_playable: 0x2fbc9e87d82f279727e61c9ebc25269905fd28fb8137aeead5f417ac4cc66de
/// settings_id: 0x2c1ab8f675f7da818ca288b9feb48811492444b5e6d822b3d1fe07728d1b714
/// player_name: 0x2cf33209d5df54b50609fc29863a6b916471ac903c3d15acbe89210cac085aa
/// minted_by: 0x1017c8450696b88787feabb9b5f2584574556b2091690953c038e051d5801bb
/// minted_by_address: 0x3c8691eac3f879268d352d7d5f6f28a456e3f92f4843fec780e3037d4f9d162
/// is_soulbound: 0x38f66b071844d5c568a247092201c33b2ef3d3ac5bf07715050d15b213c48c2
/// objective_id: 0x1c4b6eb95bb446da526020769358176d3498e17d9c19de091867d39d7aec5f6
/// client_url: 0xfece505a913d6bf16c52441883915903c7f729b363edd8c5e632d00eec92d2
/// mint_metadata: 0x336044a33f6a282d709d30cdd1b1ef63ea14c85c9e0d7cb14f51127fa7cfa36
/// mint: 0x1bf0e27928426c321ad45df64c7ebb07bf82645eaecf532c67df90b4007692c
/// mint_batch_recipients: 0x144515c9b8cf0aa7bfe3e5c932f6d346730b53fa1515dd46a808bf5e055cbfe
/// update_player_name: 0x1f68f6ce969c632201a916c0ec4432e7edf5340a2b7a71172b820d22c2e9481
pub const IMINIGAME_TOKEN_LITE_ID: felt252 =
    0x15951d6d145a5a13c454bd75f0787e43e531a80a4bfb42a01fc4859e6fb7aea;

#[starknet::interface]
pub trait IMinigameTokenLite<TState> {
    fn token_metadata(self: @TState, token_id: felt252) -> TokenMetadata;
    /// Lifecycle window only — no game_over latch; ask the game.
    fn is_playable(self: @TState, token_id: felt252) -> bool;
    fn settings_id(self: @TState, token_id: felt252) -> u32;
    fn player_name(self: @TState, token_id: felt252) -> felt252;
    fn minted_by(self: @TState, token_id: felt252) -> felt252;
    /// Resolves the packed 26-bit minter id back to the minter's address —
    /// the one view a packing-aware caller cannot derive from the id alone.
    fn minted_by_address(self: @TState, token_id: felt252) -> ContractAddress;
    fn is_soulbound(self: @TState, token_id: felt252) -> bool;
    /// Packed objective id — inert data the game interprets; the lite token
    /// has no completion machinery.
    fn objective_id(self: @TState, token_id: felt252) -> u32;
    /// Stored client url from mint; empty ByteArray when none was supplied.
    fn client_url(self: @TState, token_id: felt252) -> ByteArray;
    /// The 65-bit packed mint metadata field — the value the u16 `metadata`
    /// field of `token_metadata` cannot hold.
    fn mint_metadata(self: @TState, token_id: felt252) -> u128;

    /// Mints to `to` and returns the packed token id. The game is this
    /// contract — there is no game_address parameter. `settings_id` keeps
    /// `Option<u32>` for call-site ergonomics, but the value must fit the
    /// lite layout's 16-bit field (`<= 0xFFFF`) or the mint reverts; likewise
    /// `objective_id` must fit 30 bits and `metadata` 65 bits. `context` sets
    /// the id's has_context bit only (data not stored); `client_url` is
    /// written to storage when Some.
    fn mint(
        ref self: TState,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        to: ContractAddress,
        soulbound: bool,
        paymaster: bool,
        salt: u16,
        metadata: u128,
    ) -> felt252;
    /// Batch mint with per-recipient counts. Salt is a single global counter
    /// across the batch (`salt + sum(counts) - 1 <= 0xFFFF` — the lite
    /// layout's 16-bit salt field). All packed fields (including the
    /// has_context bit) are shared by every minted token; the client_url, when
    /// Some, is written per token.
    fn mint_batch_recipients(
        ref self: TState,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        recipients: Array<MintBatchRecipient>,
        soulbound: bool,
        paymaster: bool,
        salt: u16,
        metadata: u128,
    ) -> Array<felt252>;
    /// Emits an ERC-4906 `MetadataUpdate` for `token_id` — see
    /// `IMinigameToken::refresh_metadata` for the spam/existence trade-offs;
    /// identical semantics here.
    fn refresh_metadata(ref self: TState, token_id: felt252);
    /// Owner-gated rename; emits `MetadataUpdate`.
    fn update_player_name(ref self: TState, token_id: felt252, name: felt252);
}
