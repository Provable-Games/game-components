// The minigame token STANDARD — single-game, no mutable token state.
//
// Surface for one-address deployments: the implementing component is embedded
// IN the game contract, so the game and the token are always the same
// contract, and the game contract remains the sole authority on game-over /
// objective completion. The token stores no per-token mutable state except
// `player_name` and `client_url`: every other view is unpacked from the token
// id itself.
//
// The ORIGINAL multi-game token trait (separate token contract, registry,
// mutable state) lives on as `IMinigameTokenLegacy` in `token/legacy.cairo`,
// kept for deployed denshokan.
//
// Token ids use the standard's 251-bit layout (see
// `game_components_embeddable_game_standard::token::packing`), NOT the
// legacy token's layout. Indexers must branch their token-id decoder by
// contract generation.
//
// Strip principle: dead MACHINERY and compat shims are deleted; CAPABILITY
// (writes) and cheap client-facing read views stay.
// * `game_address` / `game_registry_address` — gone: the pairing is
//   self == self; consumers probe `IMINIGAME_TOKEN_ID` via SRC5 instead
//   of resolving addresses.
// * `assert_is_playable` / `assert_owner_and_playable` — gone from the ABI:
//   the embedding game's own guards. What survives is the single internal
//   `MinigameTokenComponent::InternalTrait::assert_lifecycle_open`; the
//   ownership half is a plain `owner_of` comparison the game writes at its
//   own call site. Clients read `is_lifecycle_open`.
// * `refresh_metadata_batch` — gone: a multicall of singles.
// * The legacy token's `game_address`, `renderer_address` and `skills_address`
//   mint parameters are gone (self-bound; no per-token renderer/skills).
//
// Mint parameters kept WITH their original legacy-token behaviors:
// * `objective_id` — packed into the id as inert data the game interprets;
//   the token has no completion machinery (`completed_objective` in
//   `token_metadata` stays always-false).
// * `context` — sets the id's has_context bit only; the data itself is NOT
//   stored (legacy-token parity: its context hook was a documented no-op and
//   token_uri sourced context from the minter at render time).
// * `client_url` — storage-backed, readable via `client_url(token_id)`.
// * `paymaster` — packed bit.
// * `metadata` — widened from the legacy token's u16 to a u128 holding a
//   65-bit packed field; read via `mint_metadata(token_id)`.
//
// Semantics that differ from the legacy token:
// * `is_lifecycle_open` checks the lifecycle window only — it is NOT a
//   "can this token be played" answer. There is no token-side
//   `game_over`/`completed_objective` latch, and the view knows nothing
//   about ownership or objective completion — ask the game.
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
/// refresh-function exclusion from `IMINIGAME_TOKEN_LEGACY_ID`. Run `src5_rs parse`
/// against a stripped copy of this trait (see packages/interfaces/src/AGENTS.md)
/// to rederive:
/// token_metadata: 0x2b0dd558353cb20e7f4ab7c3f1d2bc5ba7dbc4814f2f019e5910cd952338601
/// is_lifecycle_open: 0x1da17b2b388744fb4dc987bca72f0639cf90a3bf07598e095b6fc4e07eca2bc
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
pub const IMINIGAME_TOKEN_ID: felt252 =
    0x1238d845bb65d15a4ae71f27bef35d008ad496acb4c3b840c5de17bf0111559;

#[starknet::interface]
pub trait IMinigameToken<TState> {
    fn token_metadata(self: @TState, token_id: felt252) -> TokenMetadata;
    /// Is the mint-time lifecycle window open right now? `now >= start`, and
    /// `now < end` when an end was set. That is the WHOLE claim: it says
    /// nothing about ownership, game over, or objective completion — the game
    /// contract is the authority on those. Named for what it checks; the old
    /// name (`is_playable`) promised an answer this view cannot give.
    fn is_lifecycle_open(self: @TState, token_id: felt252) -> bool;
    fn settings_id(self: @TState, token_id: felt252) -> u32;
    fn player_name(self: @TState, token_id: felt252) -> felt252;
    fn minted_by(self: @TState, token_id: felt252) -> felt252;
    /// Resolves the packed 26-bit minter id back to the minter's address —
    /// the one view a packing-aware caller cannot derive from the id alone.
    fn minted_by_address(self: @TState, token_id: felt252) -> ContractAddress;
    fn is_soulbound(self: @TState, token_id: felt252) -> bool;
    /// Packed objective id — inert data the game interprets; the token
    /// has no completion machinery.
    fn objective_id(self: @TState, token_id: felt252) -> u32;
    /// Stored client url from mint; empty ByteArray when none was supplied.
    fn client_url(self: @TState, token_id: felt252) -> ByteArray;
    /// The packed 65-bit mint metadata. Same value as
    /// `token_metadata(token_id).metadata`, as a single-field read.
    fn mint_metadata(self: @TState, token_id: felt252) -> u128;

    /// Mints to `to` and returns the packed token id. The game is this
    /// contract — there is no game_address parameter. `settings_id` keeps
    /// `Option<u32>` for call-site ergonomics, but the value must fit the
    /// id layout's 16-bit field (`<= 0xFFFF`) or the mint reverts; likewise
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
    /// across the batch (`salt + sum(counts) - 1 <= 0xFFFF` — the id
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
    /// `IMinigameTokenLegacy::refresh_metadata` for the spam/existence trade-offs;
    /// identical semantics here.
    fn refresh_metadata(ref self: TState, token_id: felt252);
    /// Owner-gated rename; emits `MetadataUpdate`.
    fn update_player_name(ref self: TState, token_id: felt252, name: felt252);
}

/// Combined mixin ABI: the full external surface of the standard token —
/// `IMinigameToken` + the absorbed minter (`IMinigameTokenMinter`) + the
/// game-fee surface (`IMinigameTokenGameFee`) — as ONE embeddable trait,
/// mirroring OpenZeppelin's ERC20ABI / MixinImpl pattern.
///
/// The component's `initializer` registers all three SRC5 ids
/// unconditionally; embedding `MinigameTokenComponent::MinigameTokenMixinImpl`
/// (instead of the three impls separately) guarantees the advertised ids can
/// never diverge from the exposed entrypoints. NOT used for SRC5 id
/// derivation — the ids remain `IMINIGAME_TOKEN_ID`,
/// `IMINIGAME_TOKEN_MINTER_ID` and `IMINIGAME_TOKEN_GAME_FEE_ID`.
#[starknet::interface]
pub trait MinigameTokenABI<TState> {
    // IMinigameToken
    fn token_metadata(self: @TState, token_id: felt252) -> TokenMetadata;
    fn is_lifecycle_open(self: @TState, token_id: felt252) -> bool;
    fn settings_id(self: @TState, token_id: felt252) -> u32;
    fn player_name(self: @TState, token_id: felt252) -> felt252;
    fn minted_by(self: @TState, token_id: felt252) -> felt252;
    fn minted_by_address(self: @TState, token_id: felt252) -> ContractAddress;
    fn is_soulbound(self: @TState, token_id: felt252) -> bool;
    fn objective_id(self: @TState, token_id: felt252) -> u32;
    fn client_url(self: @TState, token_id: felt252) -> ByteArray;
    fn mint_metadata(self: @TState, token_id: felt252) -> u128;
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
    fn refresh_metadata(ref self: TState, token_id: felt252);
    fn update_player_name(ref self: TState, token_id: felt252, name: felt252);

    // IMinigameTokenMinter (absorbed minter registry)
    fn get_minter_address(self: @TState, minter_id: u64) -> ContractAddress;
    fn get_minter_id(self: @TState, minter_address: ContractAddress) -> u64;
    fn minter_exists(self: @TState, minter_address: ContractAddress) -> bool;
    fn total_minters(self: @TState) -> u64;

    // IMinigameTokenGameFee (game fee recipient + terms)
    fn game_fee_terms(self: @TState) -> crate::structs::token::GameFeeTerms;
    fn game_fee_recipient(self: @TState) -> ContractAddress;
    fn set_game_fee_recipient(ref self: TState, new_recipient: ContractAddress);
    fn set_game_fee(ref self: TState, license: ByteArray, fee_numerator: u16);
}

/// The game answers for its own tokens' state; the token holds no latch.
#[starknet::interface]
pub trait IMinigameTokenData<TState> {
    fn score(self: @TState, token_id: felt252) -> u64;
    fn game_over(self: @TState, token_id: felt252) -> bool;

    // Batch operations
    fn score_batch(self: @TState, token_ids: Span<felt252>) -> Array<u64>;
    fn game_over_batch(self: @TState, token_ids: Span<felt252>) -> Array<bool>;
}
