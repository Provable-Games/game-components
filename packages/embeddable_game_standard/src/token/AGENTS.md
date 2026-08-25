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
| Token id layout is standard-native | `token::packing::pack_token_id` (251-bit) — its OWN layout, not the legacy token's (`token_legacy::structs` stays untouched, serving legacy denshokan). Indexers must branch their decoder by contract generation |
| Strip principle: machinery deleted, capability + read views kept | The ABI is NOT `IMinigameTokenLegacy`-compatible: the legacy token's `game_address`, `renderer_address` and `skills_address` mint params are gone, and the compat views (`game_address`, `game_registry_address`) with them. Cheap client-facing read views (`token_metadata`, `is_playable`, `settings_id`, `minted_by`, `is_soulbound`, …) stay |
| Restored mint params keep their original legacy-token behaviors | `objective_id` (30-bit packed, INERT data the game interprets — no completion machinery; `completed_objective` stays always-false), `context` (sets the has_context bit only; the data is NOT stored — legacy-token parity), `client_url` (storage-backed, `client_url` view, empty default), `paymaster` (packed bit), `metadata` (u128 param packed into a 65-bit field, read via `mint_metadata` — the shared `TokenMetadata.metadata: u16` cannot hold it and stays 0, never truncated) |
| The minter is standard, not optional | The minter registry is absorbed into `MinigameTokenComponent`: same storage variable names, same `IMinigameTokenMinter` surface (`MinterImpl`, `IMINIGAME_TOKEN_MINTER_ID`), same `MinterRegistryUpdate` event as the legacy `MinterComponent`. `OptionalMinter` indirection remains only in `token_legacy` |
| The game-fee surface is standard, not optional | The registry's `game_fee_info` role moves onto the token: `game_fee_recipient` (payout sink), license and fee (bps, default 500) are set in the initializer and served via `GameFeeImpl` (`IMinigameTokenGameFee`, `IMINIGAME_TOKEN_GAME_FEE_ID`). Setters are gated on the game contract's OZ Ownable OWNER (`assert_only_owner`, hard `OwnableComponent::HasComponent` bound) — the stored recipient is a payee, not an admin. Monetization platforms resolve the payee LIVE at claim time |
| Game contract is the authority | Games gate dead/finished runs themselves (internal `assert_owner_and_playable`) and call `refresh_metadata` (ERC-4906) after actions |

## Token ID Layout (standard, 251 bits)

Defined in `packing.cairo` (`pack_token_id` / `unpack_token_id` +
per-field helpers, DivRem-chain style shared with `token_legacy::structs` for
the u128_safe_divmod gas savings). No field crosses the u128 boundary.

Low u128 (128 bits):

| Bits    | Field       | Size | Notes                                   |
| ------- | ----------- | ---- | --------------------------------------- |
| 0-34    | minted_at   | 35   | unix seconds                            |
| 35-59   | start_delay | 25   | seconds after minted_at (~388 days max) |
| 60-84   | end_delay   | 25   | 0 = no expiration (immortal)            |
| 85-100  | settings_id | 16   | ABI stays `Option<u32>`; value must be ≤ 0xFFFF |
| 101-126 | minted_by   | 26   | minter id from the absorbed `add_minter` (u64, must fit 26 bits) |
| 127     | soulbound   | 1    | bool                                    |

High u128 (123 bits):

| Bits   | Field        | Size | Notes                                        |
| ------ | ------------ | ---- | -------------------------------------------- |
| 0-9    | tx_hash      | 10   | last 10 bits of tx hash                      |
| 10-25  | salt         | 16   | per-tx multicall counter (65,536 per tx)     |
| 26     | paymaster    | 1    | bool                                         |
| 27     | has_context  | 1    | bool; the context data itself is NOT stored  |
| 28-57  | objective_id | 30   | inert data the game interprets               |
| 58-122 | metadata     | 65   | inert data the game interprets; u128 param, must be ≤ 2^65−1 |

The high half is **fully allocated — there is no reserved region**: every
spare bit was merged into the single writable `metadata` field, in line with
the original layout's single-field design. A future protocol-owned field would
require a new contract generation (accepted trade-off).

## Interface (IMinigameToken)

**Interface ID:** `IMINIGAME_TOKEN_ID = 0x20253de95bcdb23620c88405a5f97da040b91de832ad98a34b45c4f3331d13b`
(derived over the trait minus `refresh_metadata`, mirroring the refresh
exclusion from `IMINIGAME_TOKEN_LEGACY_ID`)

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
| `mint(player_name, settings_id, start, end, objective_id, context, client_url, to, soulbound, paymaster, salt, metadata)` | 1 minter-map read (warm), optional name/url writes, ERC721 mint | 12-arg shape — no game address (self-bound), no renderer/skills. objective/paymaster/metadata pack into the id; context sets the has_context bit only; client_url written when Some |
| `mint_batch_recipients(player_name, settings_id, start, end, objective_id, context, client_url, recipients, soulbound, paymaster, salt, metadata)` | batch work hoisted; per token: pack + optional name/url writes + ERC721 mint | Global salt counter over the 16-bit field (`salt + sum(counts) - 1 <= 0xFFFF`); packed fields (incl. the has_context bit) shared across the batch, client_url written per token |
| `is_playable` | 0 storage reads | Lifecycle window only — no game_over latch |
| `token_metadata`, `settings_id`, `minted_by`, `is_soulbound`, `objective_id`, `mint_metadata` | 0 storage reads | Pure unpack of the token id — kept as client/RPC conveniences (also derivable from the documented id layout). `token_metadata`'s u16 `metadata` field is always 0 (65 bits cannot fit; use `mint_metadata`) |
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
