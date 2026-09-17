// The minigame token STANDARD — single-game, no mutable token state.
//
// Surface for one-address deployments: the implementing component is embedded
// IN the game contract, so the game and the token are always the same
// contract, and the game contract remains the sole authority on game-over /
// objective completion. The token stores no per-token mutable state except
// `player_name` and `client_url`, both set by the token owner after mint
// (`set_player_name` / `set_client_url`): every other view is unpacked from
// the token id itself.
//
// The ORIGINAL multi-game token trait (separate token contract, registry,
// mutable state) lives on as `IMinigameTokenLegacy` in `token/legacy.cairo`,
// kept for deployed denshokan.
//
// Token ids use the standard's schema v1 layout (see
// `game_components_embeddable_game_standard::token::packing`), NOT the
// legacy token's layout. Indexers must branch their token-id decoder by
// contract generation; the `schema_version` view (id low bits 0-4) names
// the layout.
//
// Strip principle: dead MACHINERY and compat shims are deleted; CAPABILITY
// (writes) and cheap client-facing read views stay.
// * `game_address` / `game_registry_address` — gone: the pairing is
//   self == self; consumers probe `IMINIGAME_TOKEN_ID` via SRC5 instead
//   of resolving addresses.
// * `assert_is_playable` / `assert_owner_and_playable` — gone from the ABI:
//   the embedding game's own guards, internal calls now
//   (`MinigameTokenComponent::InternalTrait`); clients use `is_playable`.
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
// * `paymaster` — packed bit.
// * `metadata` — widened from the legacy token's u16 to a u128 holding a
//   59-bit packed field; read via `mint_metadata(token_id)`.
//
// Semantics that differ from the legacy token:
// * `is_playable` checks the lifecycle window only. There is no token-side
//   `game_over`/`completed_objective` latch — ask the game.
// * `token_metadata` reports `game_over`/`completed_objective`/`completed_at`
//   as `false`/`0` unconditionally, for the same reason.
// * Mint times are stored to the minute: `minted_at` and the lifecycle
//   `start`/`end` are reconstructed from minute fields (never earlier than
//   requested, at most 59 seconds later).
// * There is no salt parameter: token ids are made unique by the transaction
//   hash and an internal per-transaction counter; callers pass nothing.
// * There is no `update_game` — nothing to sync. `refresh_metadata`
//   (ERC-4906 emit) is the only post-action hook a game needs.
use starknet::ContractAddress;
use crate::structs::metagame::GameContextDetails;
use crate::structs::token::{Lifecycle, MintBatchRecipient, TokenMetadata};

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors.
///
/// Surface is the trait below minus `refresh_metadata`, mirroring the
/// refresh-function exclusion from `IMINIGAME_TOKEN_LEGACY_ID`. Run `src5_rs parse`
/// against a stripped copy of this trait (see packages/interfaces/src/AGENTS.md)
/// to rederive:
/// token_metadata: 0x2f33e0f12dee3fd282c251bf5a7fbb58faf5089710e5031c394a2d7fe40d4d1
/// is_playable: 0x2fbc9e87d82f279727e61c9ebc25269905fd28fb8137aeead5f417ac4cc66de
/// settings_id: 0x2c1ab8f675f7da818ca288b9feb48811492444b5e6d822b3d1fe07728d1b714
/// player_name: 0x2cf33209d5df54b50609fc29863a6b916471ac903c3d15acbe89210cac085aa
/// minted_by: 0x1017c8450696b88787feabb9b5f2584574556b2091690953c038e051d5801bb
/// minted_by_address: 0x3c8691eac3f879268d352d7d5f6f28a456e3f92f4843fec780e3037d4f9d162
/// is_soulbound: 0x38f66b071844d5c568a247092201c33b2ef3d3ac5bf07715050d15b213c48c2
/// objective_id: 0x1c4b6eb95bb446da526020769358176d3498e17d9c19de091867d39d7aec5f6
/// client_url: 0xfece505a913d6bf16c52441883915903c7f729b363edd8c5e632d00eec92d2
/// mint_metadata: 0x336044a33f6a282d709d30cdd1b1ef63ea14c85c9e0d7cb14f51127fa7cfa36
/// schema_version: 0x258a7489ca188017fc520eec694f112495367610300d89b93c7484a1d55fdf4
/// has_context: 0x1633419b5abcc4c0bbed8bd37a363fbe6de5bd25908761ab6dcda6a9b598ca9
/// is_paymaster: 0x32badde0e306e50b9956caed68eca17ad752dd181ca3a5eb10d1a53aefa2254
/// tx_hash: 0x2b6588e2657cbc9186a59b7591891a1a8e1d4991b5c87b8c34f1e9a7c666603
/// tx_nonce: 0x3c03138f1e5c3755ced0a0f66f9f1f08936c3071fe7fdff5e6a10eb9738442d
/// minted_at_block_number: 0x19ed497d0629ce5e2b55eac485f24a434058dbb15301f7bcfb6b03defdeae8d
/// minted_at: 0x1ca7afe27530d09d655c7031c794058f480a045c5642708a7cd78a339896af9
/// start_delay: 0x6aa39306f5eb0a223e03880876b6e99167460552df902870b319d60df1af20
/// end_delay: 0x381a4251694c88a7699f03059dc5327aaaae4d94348e61d22b9f3500a30a5
/// lifecycle: 0x31518034af1ff3055a3b8ca33a5a8fa3736833b5c146af44a3a0e60ced0fed0
/// mint: 0x48ad416b8cb93e8a0efab4c3eb95711c4cfbba9cfbe562f705c1b38b949cbb
/// mint_batch_recipients: 0x352e0e3bdf40a5969d45478a24551b8ed644b2dde2e5d8e4d07d51ec6822b06
/// set_player_name: 0x228047ae07a2ee2061a494891d2bb003eec951e7cf6d39ea9f775e02c1f5eb8
/// set_client_url: 0xc0ee9669c3b8065a0e3dc50a471b7cb0775c1cd555104b8bb1a5fc734a869b
///
/// Generation note: v3 tokens (token id schema v1, salt-free mint ABI)
/// register this id. v2 and earlier deployments keep the previous id,
/// `0x20253de95bcdb23620c88405a5f97da040b91de832ad98a34b45c4f3331d13b`,
/// on-chain — a consumer that must recognise both generations probes both.
pub const IMINIGAME_TOKEN_ID: felt252 =
    0xf004b9d53af59928314ad1d40678a64e2c80683c0f69bd1253840587a90e20;

#[starknet::interface]
pub trait IMinigameToken<TState> {
    fn token_metadata(self: @TState, token_id: felt252) -> TokenMetadata;
    /// Lifecycle window only — no game_over latch; ask the game.
    fn is_playable(self: @TState, token_id: felt252) -> bool;
    fn settings_id(self: @TState, token_id: felt252) -> u32;
    fn player_name(self: @TState, token_id: felt252) -> felt252;
    fn minted_by(self: @TState, token_id: felt252) -> felt252;
    /// Resolves the packed 24-bit minter id back to the minter's address —
    /// the one view a packing-aware caller cannot derive from the id alone.
    fn minted_by_address(self: @TState, token_id: felt252) -> ContractAddress;
    fn is_soulbound(self: @TState, token_id: felt252) -> bool;
    /// Packed objective id — inert data the game interprets; the token
    /// has no completion machinery.
    fn objective_id(self: @TState, token_id: felt252) -> u32;
    /// Stored client url; empty ByteArray until the owner sets one.
    fn client_url(self: @TState, token_id: felt252) -> ByteArray;
    /// The packed 59-bit mint metadata. Same value as
    /// `token_metadata(token_id).metadata`, as a single-field read.
    fn mint_metadata(self: @TState, token_id: felt252) -> u128;
    /// Token id layout version (id low bits 0-4); this generation writes 1.
    fn schema_version(self: @TState, token_id: felt252) -> u8;
    /// Whether a context was supplied at mint (id low bit 5); the context
    /// data itself is not stored.
    fn has_context(self: @TState, token_id: felt252) -> bool;
    /// Whether the mint was sponsored (id low bit 7).
    fn is_paymaster(self: @TState, token_id: felt252) -> bool;
    /// Low 16 bits of the mint transaction hash (id low bits 8-23).
    fn tx_hash(self: @TState, token_id: felt252) -> u16;
    /// Id low bits 24-31: 0 for a token minted with `mint`, the token's
    /// position (0, 1, 2, …) for one minted with `mint_batch_recipients`.
    fn tx_nonce(self: @TState, token_id: felt252) -> u8;
    /// Block number at mint (id low bits 32-63).
    fn minted_at_block_number(self: @TState, token_id: felt252) -> u32;
    /// Mint time in Unix seconds: the id's minute-floored timestamp (low
    /// bits 64-90) times 60.
    fn minted_at(self: @TState, token_id: felt252) -> u64;
    /// Minutes after `minted_at` when play may begin (id low bits 91-108).
    fn start_delay(self: @TState, token_id: felt252) -> u32;
    /// Minutes after start when the token expires (id low bits 109-127);
    /// 0 = never expires.
    fn end_delay(self: @TState, token_id: felt252) -> u32;
    /// The reconstructed lifecycle window in Unix seconds (`end` 0 = never).
    fn lifecycle(self: @TState, token_id: felt252) -> Lifecycle;

    /// Mints to `to` and returns the packed token id. The game is this
    /// contract — there is no game_address parameter. `settings_id` keeps
    /// `Option<u32>` for call-site ergonomics, but the value must fit the
    /// id layout's 20-bit field (`<= 0xFFFFF`) or the mint reverts; likewise
    /// `objective_id` must fit 20 bits and `metadata` 59 bits. `context` sets
    /// the id's has_context bit only (data not stored). Player name and
    /// client url are not mint parameters: the owner sets them afterwards
    /// via `set_player_name` / `set_client_url`. Token ids are made unique by the
    /// transaction hash and an internal per-transaction counter; callers
    /// pass nothing.
    fn mint(
        ref self: TState,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        context: Option<GameContextDetails>,
        to: ContractAddress,
        soulbound: bool,
        paymaster: bool,
        metadata: u128,
    ) -> felt252;
    /// Batch mint with per-recipient counts (at most 256 tokens per batch).
    /// Token ids are made unique by the transaction hash and an internal
    /// per-transaction counter that runs across the batch; callers pass
    /// nothing. All packed fields (including the has_context bit) are shared
    /// by every minted token.
    fn mint_batch_recipients(
        ref self: TState,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        context: Option<GameContextDetails>,
        recipients: Array<MintBatchRecipient>,
        soulbound: bool,
        paymaster: bool,
        metadata: u128,
    ) -> Array<felt252>;
    /// Emits an ERC-4906 `MetadataUpdate` for `token_id` — see
    /// `IMinigameTokenLegacy::refresh_metadata` for the spam/existence trade-offs;
    /// identical semantics here.
    fn refresh_metadata(ref self: TState, token_id: felt252);
    /// Owner-gated; stores the name and emits `MetadataUpdate`. Names are
    /// never set at mint.
    fn set_player_name(ref self: TState, token_id: felt252, name: felt252);
    /// Owner-gated; stores the url and emits `MetadataUpdate`. Urls are
    /// never set at mint.
    fn set_client_url(ref self: TState, token_id: felt252, url: ByteArray);
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
    fn is_playable(self: @TState, token_id: felt252) -> bool;
    fn settings_id(self: @TState, token_id: felt252) -> u32;
    fn player_name(self: @TState, token_id: felt252) -> felt252;
    fn minted_by(self: @TState, token_id: felt252) -> felt252;
    fn minted_by_address(self: @TState, token_id: felt252) -> ContractAddress;
    fn is_soulbound(self: @TState, token_id: felt252) -> bool;
    fn objective_id(self: @TState, token_id: felt252) -> u32;
    fn client_url(self: @TState, token_id: felt252) -> ByteArray;
    fn mint_metadata(self: @TState, token_id: felt252) -> u128;
    fn schema_version(self: @TState, token_id: felt252) -> u8;
    fn has_context(self: @TState, token_id: felt252) -> bool;
    fn is_paymaster(self: @TState, token_id: felt252) -> bool;
    fn tx_hash(self: @TState, token_id: felt252) -> u16;
    fn tx_nonce(self: @TState, token_id: felt252) -> u8;
    fn minted_at_block_number(self: @TState, token_id: felt252) -> u32;
    fn minted_at(self: @TState, token_id: felt252) -> u64;
    fn start_delay(self: @TState, token_id: felt252) -> u32;
    fn end_delay(self: @TState, token_id: felt252) -> u32;
    fn lifecycle(self: @TState, token_id: felt252) -> Lifecycle;
    fn mint(
        ref self: TState,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        context: Option<GameContextDetails>,
        to: ContractAddress,
        soulbound: bool,
        paymaster: bool,
        metadata: u128,
    ) -> felt252;
    fn mint_batch_recipients(
        ref self: TState,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
        context: Option<GameContextDetails>,
        recipients: Array<MintBatchRecipient>,
        soulbound: bool,
        paymaster: bool,
        metadata: u128,
    ) -> Array<felt252>;
    fn refresh_metadata(ref self: TState, token_id: felt252);
    fn set_player_name(ref self: TState, token_id: felt252, name: felt252);
    fn set_client_url(ref self: TState, token_id: felt252, url: ByteArray);

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
