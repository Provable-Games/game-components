# Token Module — MinigameTokenComponent (ERC721)

THE minigame token standard: gas-optimized, single-game, self-bound. Built for
deployments that never used the multi-game
registry/objectives/context/skills/per-token renderer features, and keep
game-over / objective-completion authority in the game contract itself. The
original multi-game token lives on unchanged as the `token_legacy` module,
kept for deployed denshokan.

**Self-binding only:** the component is embedded IN the game contract — the
game contract IS the token (one-address architecture). A separate-token
deployment shape existed briefly and was removed after measurements showed it
strictly worse on gas; keeping it alive meant dead machinery (`bind_game`,
two-phase init, a standalone preset, game-side call helpers).

## Design Rules

| Rule | Consequence |
| --- | --- |
| Self-bound: the embedding contract is the game | No stored game address, no registry, no `game_id` resolution, no SRC5 probes on mint; there is no game_address view or mint parameter at all — consumers identify a standard token by SRC5 (`IMINIGAME_TOKEN_ID`) |
| No mutable token state | No `update_game`, no metagame callbacks; `is_playable` = lifecycle window only, zero storage reads. `player_name` (owner-renameable) and the mint-time `client_url` are the only per-token storage (plus the minter registry) |
| Token id layout is standard-native | `token::packing::pack_token_id` (schema v1, 251-bit) — its OWN layout, not the retired generation's. Indexers must branch their decoder by contract generation; `schema_version` (low bits 0-4) names the layout |
| Strip principle: machinery deleted, capability + read views kept | The ABI is NOT `IMinigameTokenLegacy`-compatible: the legacy token's `game_address`, `renderer_address` and `skills_address` mint params are gone, and the compat views (`game_address`, `game_registry_address`) with them. Cheap client-facing read views (`token_metadata`, `is_playable`, `settings_id`, `minted_by`, `is_soulbound`, …) stay |
| Restored mint params keep their original legacy-token behaviors | `objective_id` (20-bit packed, INERT data the game interprets — no completion machinery; `completed_objective` stays always-false), `context` (sets the has_context bit only; the data is NOT stored — legacy-token parity), `client_url` (storage-backed, `client_url` view, empty default), `paymaster` (packed bit), `metadata` (u128 param packed into a 59-bit field, read via `mint_metadata` or `TokenMetadata.metadata`) |
| No caller-supplied salt | Ids are made unique by the tx hash plus `tx_nonce` (0 for `mint`, the token's position for `mint_batch_recipients`); see "Token ID Layout" below |
| The minter is standard, not optional | The minter registry is absorbed into `MinigameTokenComponent`: same storage variable names, same `IMinigameTokenMinter` surface (`MinterImpl`, `IMINIGAME_TOKEN_MINTER_ID`), same `MinterRegistryUpdate` event as the legacy `MinterComponent`. `OptionalMinter` indirection remains only in `token_legacy` |
| The game-fee surface is standard, not optional | The registry's `game_fee_info` role moves onto the token: `game_fee_recipient` (payout sink), license and fee (bps, default 500) are set in the initializer and served via `GameFeeImpl` (`IMinigameTokenGameFee`, `IMINIGAME_TOKEN_GAME_FEE_ID`). Setters are gated on the game contract's OZ Ownable OWNER (`assert_only_owner`, hard `OwnableComponent::HasComponent` bound) — the stored recipient is a payee, not an admin. Monetization platforms resolve the payee LIVE at claim time |
| Game contract is the authority | Games gate dead/finished runs themselves (internal `assert_owner_and_playable`) and call `refresh_metadata` (ERC-4906) after actions |

## Token ID Layout (schema v1, 251 bits)

Defined in `packing.cairo` (`pack_token_id(PackedTokenId)` /
`unpack_token_id` + one `unpack_<field>` decoder per field, `unpack_lifecycle`
for the guard's hot path, and the pure minute helpers `minutes_floor`,
`minutes_ceil_delay`, `minutes_to_seconds`). Decode the id as a u256; bit
numbers are relative to their u128 half and no field crosses the boundary.
`SCHEMA_VERSION = 1` is written into low bits 0-4 so indexers can branch by
layout.

Low u128 (bits 0-127, fully allocated):

| Bits    | Field                  | Width | Type | Notes                                                        |
| ------- | ---------------------- | ----- | ---- | ------------------------------------------------------------ |
| 0-4     | schema_version         | 5     | u8   | this layout writes 1; 0 is never written                     |
| 5       | has_context            | 1     | bool | a context was supplied at mint (data NOT stored)             |
| 6       | soulbound              | 1     | bool | non-transferable                                             |
| 7       | paymaster              | 1     | bool | mint was sponsored                                           |
| 8-23    | tx_hash                | 16    | u16  | low 16 bits of the mint tx hash                              |
| 24-31   | tx_nonce               | 8     | u8   | 0 for `mint`; position in the batch for `mint_batch_recipients` |
| 32-63   | minted_at_block_number | 32    | u32  | block number at mint                                         |
| 64-90   | minted_at_timestamp    | 27    | u32  | block timestamp floored to whole minutes since the epoch     |
| 91-108  | start_delay            | 18    | u32  | minutes after minted_at_timestamp when play may begin        |
| 109-127 | end_delay              | 19    | u32  | minutes after start when the token expires; 0 = never        |

High u128 (bits 0-122 used; 123-127 must be zero to stay below the prime):

| Bits   | Field        | Width | Type | Notes                                                                     |
| ------ | ------------ | ----- | ---- | ------------------------------------------------------------------------- |
| 0-19   | settings_id  | 20    | u32  | ABI stays `Option<u32>`; value must be ≤ 0xFFFFF                          |
| 20-39  | objective_id | 20    | u32  | inert data the game interprets                                            |
| 40-63  | minted_by    | 24    | u32  | minter id from the absorbed `add_minter`, starts at 1                     |
| 64-122 | metadata     | 59    | u128 | minter-writable, uninterpreted; no built-in on-chain or off-chain reader  |

**Time semantics.** Times are stored to the minute: `minted_at_timestamp =
block_timestamp / 60`, the delays are `ceil` of the requested offsets, and the
public `Lifecycle` / `TokenMetadata.minted_at` are reconstructed in seconds
(`minted_at = minted_at_timestamp * 60`, `start = (minted_at_timestamp +
start_delay) * 60`, `end = start + end_delay * 60` or 0). A past start clamps
to now. Reconstructed times are never earlier than requested; `minted_at` and
`start` are at most 59 s later, and `end` is too unless the requested window
is shorter than the start's round-up, in which case `end_delay` clamps to 1
(`end = start + 60`). A non-zero requested end therefore always yields
`end_delay >= 1` — no sub-minute window collapses into an immortal token.

**tx_nonce.** No public or internal mint function takes a salt or nonce.
`mint` packs `tx_nonce = 0`; `mint_batch_recipients` numbers its tokens 0, 1,
2, … across all recipients and rejects more than 256 tokens up front. Nothing
consults storage to choose a nonce: within one transaction the id is unique
by tx-hash bits plus batch position, so a caller that wants several tokens in
one transaction uses `mint_batch_recipients`. Two mints with identical fields
in one transaction, or in one block whose tx hashes share their low 16 bits,
produce the same id and the second reverts in the ERC721 mint.

## Interface (IMinigameToken)

**Interface ID:** `IMINIGAME_TOKEN_ID = 0x3a2ed35c6e824eaf2721a9aeea082940f25bbad29b0f3acaa9d9c5b204c786`
(derived over the trait minus `refresh_metadata`, mirroring the refresh
exclusion from `IMINIGAME_TOKEN_LEGACY_ID`). v3 tokens register this id; v2
and earlier deployments keep the previous value,
`0x20253de95bcdb23620c88405a5f97da040b91de832ad98a34b45c4f3331d13b`, on-chain.

Defined in `packages/interfaces/src/token/core.cairo`.
`initializer(game_fee_recipient, license, fee_numerator)` stores the game-fee
terms (recipient must be non-zero; `license`/`fee_numerator` default to
`default_license()` / `DEFAULT_GAME_FEE_BPS` when None) and registers
`IMINIGAME_TOKEN_ID`, the absorbed minter's `IMINIGAME_TOKEN_MINTER_ID` and
the game-fee surface's `IMINIGAME_TOKEN_GAME_FEE_ID` — and nothing else: SRC5
is honest, a standard token does not implement `IMinigameTokenLegacy` and
does not advertise the legacy id. Consumers branch on `IMINIGAME_TOKEN_ID`
instead of resolving registry/game-address views.

| Method | Cost | Notes |
| --- | --- | --- |
| `mint(player_name, settings_id, start, end, objective_id, context, client_url, to, soulbound, paymaster, metadata)` | block/tx info read, 1 minter-map read (warm), owner read per nonce attempt, optional name/url writes, ERC721 mint | 11-arg shape — no game address (self-bound), no renderer/skills, no salt. objective/paymaster/metadata pack into the id; context sets the has_context bit only; client_url written when Some |
| `mint_batch_recipients(player_name, settings_id, start, end, objective_id, context, client_url, recipients, soulbound, paymaster, metadata)` | batch work hoisted; per token: pack + optional name/url writes + ERC721 mint | `tx_nonce` runs 0, 1, 2, … across the batch (≤ 256 tokens, checked before any mint); every other packed field (incl. the has_context bit) shared across the batch, client_url written per token |
| `is_playable` | 0 storage reads | Lifecycle window only — no game_over latch |
| `token_metadata`, `settings_id`, `minted_by`, `is_soulbound`, `objective_id`, `mint_metadata`, `schema_version`, `has_context`, `is_paymaster`, `tx_hash`, `tx_nonce`, `minted_at_block_number`, `minted_at`, `start_delay`, `end_delay`, `lifecycle` | 0 storage reads | Pure unpack of the token id — one view per schema field (`minted_at` and `lifecycle` in seconds, the delays in minutes), kept as client/RPC conveniences (also derivable from the documented id layout) |
| `player_name`, `minted_by_address`, `client_url` | 1 storage read | |
| `refresh_metadata` | event only | Same advisory/no-existence-check semantics as the legacy token |
| `update_player_name` | owner-gated write | Emits `MetadataUpdate` |

The absorbed minter registry additionally exposes the unchanged
`IMinigameTokenMinter` surface (`get_minter_address`, `get_minter_id`,
`minter_exists`, `total_minters`) via `MinigameTokenComponent::MinterImpl`.

The game-fee surface (`MinigameTokenComponent::GameFeeImpl`,
`IMINIGAME_TOKEN_GAME_FEE_ID = 0x171bf98e08ae98315df3e68477e24275ef5755111c1984db851c344b3907bb0`)
exposes `game_fee_terms` / `game_fee_recipient` (reads) and
`set_game_fee_recipient` / `set_game_fee` (owner-gated writes; rotation to
zero rejected, fee capped at `FEE_DENOMINATOR`). Renamed from the creator
surface — function renames change extended selectors, so the retired
`IMINIGAME_TOKEN_CREATOR_ID` value is dead (no deployment registers it).

Deleted from the ABI (strip principle — dead machinery and compat shims go,
capability and read views stay):

* `game_address` / `game_registry_address` — compat shims; the pairing is
  self == self and consumers probe `IMINIGAME_TOKEN_ID` via SRC5.
* `assert_is_playable` / `assert_owner_and_playable` — the embedding game's
  own guards, `InternalTrait` calls now (zero syscalls); clients read
  `is_playable`.
* `refresh_metadata_batch` — a multicall of singles.

Not present (reverts with ENTRYPOINT_NOT_FOUND): `update_game`, all batch
views, the objectives/settings/context creation and renderer/skills/enumerable
surfaces.

## Composition

**Preferred wiring: one embed.** `MinigameTokenComponent::MinigameTokenMixinImpl`
exposes the full standard surface (`MinigameTokenABI` = token + absorbed
minter + creator) in a single `#[abi(embed_v0)]` line — since the initializer
registers all three SRC5 ids unconditionally, the mixin keeps the advertised
ids honest by construction. The separate impls (`MinigameTokenImpl`,
`MinterImpl`, `GameFeeImpl`) remain exported; a contract wiring them
individually MUST embed all three or its SRC5 answers lie.

Requires: `ERC721Component`, `SRC5Component`, `OwnableComponent` (hard
`HasComponent` bound on `GameFeeImpl` and the mixin — the owner administers
the game-fee surface), and an `ERC721HooksTrait`
(enforce soulbound in `before_update` via `token::packing::unpack_soulbound`
— pure, no storage; NOT the legacy token's `unpack_soulbound`, which reads a
different bit position). No separate minter component: the registry is
absorbed — embed `MinigameTokenComponent::MinterImpl` alongside
`MinigameTokenImpl`. The embedding contract is the game: it implements
`IMinigameTokenData` (score/game_over) itself and calls the component's
internal guard (`InternalTrait::assert_owner_and_playable`) and
`refresh_metadata` internally.

See `test_common/src/mocks/standard_game_mock.cairo` (`StandardGameMock`) for
a full merged game+token wiring example — it lives in the test_common package
so downstream consumers can declare it in their own suites via
`build-external-contracts`.

For metagames: `metagame::metagame::assert_game_registered` SRC5-probes the
game's token for `IMINIGAME_TOKEN_ID` first — a standard token means
"registered" is the self-binding equality `token_address == game_address`;
otherwise the legacy-token registry path runs unchanged.

## Testing

```bash
snforge test -p game_components_embeddable_game_standard "::token::"
```
