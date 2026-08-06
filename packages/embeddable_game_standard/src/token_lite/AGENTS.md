# Token Lite Module — CoreTokenLiteComponent (ERC721)

Gas-optimized single-game variant of the `token` module ("denshokan lite").
Built for deployments that embed exactly one game, never used the multi-game
registry/objectives/context/skills/per-token renderer features, and keep
game-over / objective-completion authority in the game contract itself.

## Design Rules

| Rule | Consequence |
| --- | --- |
| One game, configured at init | No registry, no `game_id` resolution, no SRC5 probes on mint |
| No mutable token state | No `update_game`, no metagame callbacks; `is_playable` = lifecycle window only, zero storage reads |
| Token id layout is canonical | Reuses `token::structs::pack_token_id` (251-bit) bit-for-bit; unused fields (`game_id`, `objective_id`, `has_context`, `paymaster`, `metadata`) are written as zero |
| `mint` is ABI-compatible with `IMinigameToken::mint` | Existing call sites and the `minigame::mint` helper work unchanged; unsupported params are rejected loudly, never silently ignored |
| Game contract is the authority | Games gate dead/finished runs themselves and call `refresh_metadata` (ERC-4906) after actions |

## Interface (IMinigameTokenLite)

**Interface ID:** `IMINIGAME_TOKEN_LITE_ID = 0x3ea3d599077fbe09ddbe82ff33c1abc87aef52d8609d8bf3508fdba8dd92056`

Defined in `packages/interfaces/src/token/lite.cairo`. The initializer also
registers `IMINIGAME_TOKEN_ID` so `MinigameComponent::initializer` (which
hard-asserts it and then queries `game_registry_address()`) accepts a lite
token; `game_registry_address()` always returns zero.

| Method | Cost | Notes |
| --- | --- | --- |
| `mint(...)` | 1 minter-map read (warm), optional name write, ERC721 mint | Same 15-arg signature as the full token |
| `assert_owner_and_playable(token_id, expected_owner)` | 1 storage read (owner) | Combined guard — replaces `owner_of` + `assert_is_playable` (two calls) with one |
| `is_playable` / `assert_is_playable` | 0 storage reads | Lifecycle window only — no game_over latch |
| `token_metadata`, `settings_id`, `minted_by`, `is_soulbound` | 0 storage reads | Pure unpack of the token id |
| `player_name`, `minted_by_address` | 1 storage read | |
| `refresh_metadata(_batch)` | event only | Same advisory/no-existence-check semantics as the full token |
| `update_player_name` | owner-gated write | |

Not present (reverts with ENTRYPOINT_NOT_FOUND): `update_game`, all other
`*_batch` views, `mint_batch_recipients`, objectives/settings/context/
renderer/skills/enumerable surfaces.

## Game-side helpers

`minigame::lite` provides call-site twins of the full-token helpers so game
code keeps its familiar shape — the module path carries the semantic shift:

- `lite::pre_action(token_address, token_id)` → one `assert_owner_and_playable`
  call (replaces the full-token `assert_token_ownership` + `pre_action` pair)
- `lite::post_action(token_address, token_id)` → `refresh_metadata` only
  (there is no `update_game` to run)

## Composition

Requires: `ERC721Component`, `SRC5Component`, an `OptionalMinter` impl
(`MinterComponent::MinterOptionalImpl` — minter ids gate reward claims in
consumers), and an `ERC721HooksTrait` (enforce soulbound in `before_update`
via `unpack_soulbound` — pure, no storage).

See `tests/examples/token_lite_contract.cairo` for a full wiring example.

## Testing

```bash
snforge test -p game_components_embeddable_game_standard "::token_lite::"
```
