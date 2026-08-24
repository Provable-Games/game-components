// Lite token interface — single-game, no mutable token state.
//
// Surface for one-address deployments: the implementing component is embedded
// IN the game contract, so the game and the token are always the same
// contract, and the game contract remains the sole authority on game-over /
// objective completion. The token stores no per-token mutable state except
// `player_name`: every other view is unpacked from the token id itself.
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
// * The full token's dead mint parameters (game_address, objective, context,
//   client_url, renderer, skills, paymaster, metadata) are gone along with
//   their reject-asserts.
//
// Semantics that differ from the full token:
// * `is_playable` checks the lifecycle window only. There is no token-side
//   `game_over`/`completed_objective` latch — ask the game.
// * `token_metadata` reports `game_over`/`completed_objective`/`completed_at`
//   as `false`/`0` unconditionally, for the same reason.
// * There is no `update_game` — nothing to sync. `refresh_metadata`
//   (ERC-4906 emit) is the only post-action hook a game needs.
use starknet::ContractAddress;
use crate::structs::token::{MintBatchRecipient, TokenMetadata};

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors.
///
/// Surface is the trait below minus `refresh_metadata`, mirroring the
/// refresh-function exclusion from `IMINIGAME_TOKEN_ID`. Run `src5_rs parse`
/// against a stripped copy of this trait (see packages/interfaces/src/AGENTS.md)
/// to rederive:
/// mint: 0x301f9859704837f9b996bbffa025fe2570eeb0087cbdff42badfe51f5b26537
/// mint_batch_recipients: 0x243cccd53204a3d22330ac6403c39ecba1cd11e5107832acf751829639bba2a
/// minted_by_address: 0x3c8691eac3f879268d352d7d5f6f28a456e3f92f4843fec780e3037d4f9d162
/// player_name: 0x2cf33209d5df54b50609fc29863a6b916471ac903c3d15acbe89210cac085aa
/// update_player_name: 0x1f68f6ce969c632201a916c0ec4432e7edf5340a2b7a71172b820d22c2e9481
/// token_metadata: 0x1ebdf5dc7aab5a2b9bd68eb3a453bfb8025371633679db9d0d918cf87f92dd0
/// is_playable: 0x2fbc9e87d82f279727e61c9ebc25269905fd28fb8137aeead5f417ac4cc66de
/// settings_id: 0x2c1ab8f675f7da818ca288b9feb48811492444b5e6d822b3d1fe07728d1b714
/// minted_by: 0x1017c8450696b88787feabb9b5f2584574556b2091690953c038e051d5801bb
/// is_soulbound: 0x38f66b071844d5c568a247092201c33b2ef3d3ac5bf07715050d15b213c48c2
pub const IMINIGAME_TOKEN_LITE_ID: felt252 =
    0x2ec4714e0b5610e5cffd262be7c69b721a6865f9a8ce7e1094c8211f3beaa37;

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

    /// Mints to `to` and returns the packed token id. The game is this
    /// contract — there is no game_address parameter. `settings_id` keeps
    /// `Option<u32>` for call-site ergonomics, but the value must fit the
    /// lite layout's 16-bit field (`<= 0xFFFF`) or the mint reverts.
    fn mint(
        ref self: TState,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        to: ContractAddress,
        soulbound: bool,
        salt: u16,
    ) -> felt252;
    /// Batch mint with per-recipient counts. Salt is a single global counter
    /// across the batch (`salt + sum(counts) - 1 <= 0xFFFF` — the lite
    /// layout's 16-bit salt field).
    fn mint_batch_recipients(
        ref self: TState,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        recipients: Array<MintBatchRecipient>,
        soulbound: bool,
        salt: u16,
    ) -> Array<felt252>;
    /// Emits an ERC-4906 `MetadataUpdate` for `token_id` — see
    /// `IMinigameToken::refresh_metadata` for the spam/existence trade-offs;
    /// identical semantics here.
    fn refresh_metadata(ref self: TState, token_id: felt252);
    /// Owner-gated rename; emits `MetadataUpdate`.
    fn update_player_name(ref self: TState, token_id: felt252, name: felt252);
}
