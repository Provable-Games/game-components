# Token Lite Module — CoreTokenLiteComponent (ERC721)

Gas-optimized single-game variant of the `token` module ("denshokan lite").
Built for deployments that never used the multi-game
registry/objectives/context/skills/per-token renderer features, and keep
game-over / objective-completion authority in the game contract itself.

**Self-binding only:** the component is embedded IN the game contract — the
game contract IS the token (one-address architecture). A separate-token
deployment shape existed briefly and was removed after measurements showed it
strictly worse on gas; keeping it alive meant dead machinery (`bind_game`,
two-phase init, a standalone preset, game-side call helpers).

## Design Rules

| Rule | Consequence |
| --- | --- |
| Self-bound: the embedding contract is the game | No stored game address, no registry, no `game_id` resolution, no SRC5 probes on mint; there is no game_address view or mint parameter at all — consumers identify a lite token by SRC5 (`IMINIGAME_TOKEN_LITE_ID`) |
| No mutable token state | No `update_game`, no metagame callbacks; `is_playable` = lifecycle window only, zero storage reads. `player_name` is the only per-token storage (owner-renameable) |
| Token id layout is lite-native | `token_lite::packing::pack_lite_token_id` (251-bit) — its OWN layout, not the full token's (`token::structs` stays untouched, serving legacy denshokan). Indexers must branch their decoder by contract generation |
| Strip principle: machinery deleted, capability + read views kept | The ABI is NOT `IMinigameToken`-compatible: the full token's dead mint params (game_address, objective, context, client_url, renderer, skills, paymaster, metadata) are gone along with their reject-asserts, and the compat views (`game_address`, `game_registry_address`) with them. Cheap client-facing read views (`token_metadata`, `is_playable`, `settings_id`, `minted_by`, `is_soulbound`, …) stay |
| Game contract is the authority | Games gate dead/finished runs themselves (internal `assert_owner_and_playable`) and call `refresh_metadata` (ERC-4906) after actions |

## Token ID Layout (lite-native, 251 bits)

Defined in `packing.cairo` (`pack_lite_token_id` / `unpack_lite_token_id` +
per-field helpers, DivRem-chain style shared with `token::structs` for the
u128_safe_divmod gas savings). No field crosses the u128 boundary.

Low u128 (128 bits):

| Bits    | Field       | Size | Notes                                   |
| ------- | ----------- | ---- | --------------------------------------- |
| 0-34    | minted_at   | 35   | unix seconds                            |
| 35-59   | start_delay | 25   | seconds after minted_at (~388 days max) |
| 60-84   | end_delay   | 25   | 0 = no expiration (immortal)            |
| 85-100  | settings_id | 16   | ABI stays `Option<u32>`; value must be ≤ 0xFFFF |
| 101-126 | minted_by   | 26   | minter id from `OptionalMinter::add_minter` (u64, must fit 26 bits) |
| 127     | soulbound   | 1    | bool                                    |

High u128 (123 bits):

| Bits   | Field    | Size | Notes                                     |
| ------ | -------- | ---- | ----------------------------------------- |
| 0-9    | tx_hash  | 10   | last 10 bits of tx hash                   |
| 10-25  | salt     | 16   | per-tx multicall counter (65,536 per tx)  |
| 26-122 | reserved | 97   | component-owned, ALWAYS packed as zero    |

**Reserved-region ownership contract:** bits [26-122] of the high half belong
to the component. They are always packed as zero — there is no pack parameter
and no public unpack accessor. Future fields (protocol- or game-facing) are
carved from this region later; since every id minted under this layout
provably decodes the region as 0, any future field reads as 0 ("absent") on
all existing ids, making carve-outs non-breaking by construction. Do not stamp
data into these bits from outside the component.

## Interface (IMinigameTokenLite)

**Interface ID:** `IMINIGAME_TOKEN_LITE_ID = 0x2ec4714e0b5610e5cffd262be7c69b721a6865f9a8ce7e1094c8211f3beaa37`
(derived over the trait minus `refresh_metadata`, mirroring the refresh
exclusion from `IMINIGAME_TOKEN_ID`)

Defined in `packages/interfaces/src/token/lite.cairo`. The no-arg
`initializer()` registers ONLY `IMINIGAME_TOKEN_LITE_ID` — SRC5 is honest: a
lite token does not implement `IMinigameToken` and does not advertise the
legacy id. Consumers branch on the lite id instead of resolving
registry/game-address views.

| Method | Cost | Notes |
| --- | --- | --- |
| `mint(player_name, settings_id, start, end, to, soulbound, salt)` | 1 minter-map read (warm), optional name write, ERC721 mint | Trimmed 7-arg shape — no game address (self-bound), none of the full token's dead params |
| `mint_batch_recipients(player_name, settings_id, start, end, recipients, soulbound, salt)` | batch work hoisted; per token: pack + optional name write + ERC721 mint | Global salt counter over the lite 16-bit field (`salt + sum(counts) - 1 <= 0xFFFF`) |
| `is_playable` | 0 storage reads | Lifecycle window only — no game_over latch |
| `token_metadata`, `settings_id`, `minted_by`, `is_soulbound` | 0 storage reads | Pure unpack of the token id — kept as client/RPC conveniences (also derivable from the documented id layout) |
| `player_name`, `minted_by_address` | 1 storage read | |
| `refresh_metadata` | event only | Same advisory/no-existence-check semantics as the full token |
| `update_player_name` | owner-gated write | Emits `MetadataUpdate` |

Deleted from the ABI (strip principle — dead machinery and compat shims go,
capability and read views stay):

* `game_address` / `game_registry_address` — compat shims; the pairing is
  self == self and consumers probe the lite id via SRC5.
* `assert_is_playable` / `assert_owner_and_playable` — the embedding game's
  own guards, `InternalTrait` calls now (zero syscalls); clients read
  `is_playable`.
* `refresh_metadata_batch` — a multicall of singles.

Not present (reverts with ENTRYPOINT_NOT_FOUND): `update_game`, all batch
views, objectives/settings/context/renderer/skills/enumerable surfaces.

## Composition

Requires: `ERC721Component`, `SRC5Component`, an `OptionalMinter` impl
(`MinterComponent::MinterOptionalImpl` — minter ids gate reward claims in
consumers), and an `ERC721HooksTrait` (enforce soulbound in `before_update`
via `token_lite::packing::unpack_soulbound` — pure, no storage; NOT the
full token's `unpack_soulbound`, which reads a different bit position). The embedding contract is the game:
it implements `IMinigameTokenData` (score/game_over) itself and calls the
component's internal guard (`InternalTrait::assert_owner_and_playable`) and
`refresh_metadata` internally — the former `minigame::lite::{pre_action,
post_action}` cross-contract helpers were deleted with the separate-token
shape.

See `test_common/src/mocks/lite_game_mock.cairo` (`LiteGameMock`) for a full
merged game+token wiring example — it lives in the test_common package so
downstream consumers can declare it in their own suites via
`build-external-contracts`.

For metagames: `metagame::metagame::assert_game_registered` SRC5-probes the
game's token for `IMINIGAME_TOKEN_LITE_ID` first — a lite token means
"registered" is the self-binding equality `token_address == game_address`;
otherwise the full-token registry path runs unchanged.

## Testing

```bash
snforge test -p game_components_embeddable_game_standard "::token_lite::"
```
