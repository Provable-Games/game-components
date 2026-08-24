# Denshokan Lite → One-Address: the full change log and rationale

*2026-08-06 — covers game-components [#123](https://github.com/Provable-Games/game-components/pull/123), super-death-mountain [#149](https://github.com/Provable-Games/super-death-mountain/pull/149) / [#150](https://github.com/Provable-Games/super-death-mountain/pull/150), budokan [#313](https://github.com/Provable-Games/budokan/pull/313). All numbers are measured — snforge harness or real Sepolia transactions — not estimates, except where marked.*

## TL;DR

A beast-mode game (~75 actions) cost **~$0.40** on the original architecture. On the final architecture it costs **~$0.35 (−12%)**, with every stage of a game's life cheaper: mint, start, every action, and game-end (which now costs *nothing* — the ~6.73M-gas sync transaction no longer exists). The dominant remaining cost is per-transaction protocol overhead (~44% of a long game), which points at client-side action batching (est. ~$0.25–0.28) as the next lever — a client change, not a contract change.

Beyond gas: deployment went from 12 steps (including a baked-address fixed-point dance) to 3; subsystem upgrades became one owner storage write; the token can no longer desync from the game because they are the same contract; and the tournament layer (budokan) required **zero changes** to work with the final architecture — proven by live Sepolia tournaments.

---

## The original architecture and where the gas went

The original stack (mainnet today):

```
Player ──► Dungeons (greed, karat, …) ──mint──► Denshokan (shared multi-game ERC721)
Player ──► GameCore ──► 5 subsystem contracts          │        │
              │  ▲                                     ▼        ▼
              │  └─(load_assets callbacks)◄── GameToken   MinigameRegistry
              └───guards/refresh/update_game──► Denshokan
```

Measured hot spots (SDM's own gas bench + mainnet observations):

| Cost | Where | Why it existed |
|---|---|---|
| **~6.73M gas `update_game` subtree** | `start_game`, plus a keeper transaction per finished game | Denshokan pulled `game_over()`/`score()` from the game — each callback re-ran full `load_assets` (~1.56M each) — then re-validated SRC5, resolved the registry, probed the minter for metagame callbacks, and persisted a token-side game-over latch |
| **5 cross-contract calls per action** | every GameCore entrypoint | `owner_of` + `assert_is_playable` + `refresh_metadata` into denshokan, a settings read into GameToken, and the subsystem dispatch |
| **Registry + validation on every mint** | denshokan `mint` | SRC5 probe of the game, `game_id_from_address` registry lookup, cross-contract settings validation, minter-registry writes, enumerable index writes |

The audits that preceded the changes established the key fact that made everything below safe: **the expensive machinery answered questions whose answers were constant or unused.** SDM used exactly one game (registry resolution always returned the same answer), no dungeon implemented the metagame callbacks (the SRC5 probe failed every time), the token-side game-over latch was only advisory (game logic already rejects dead adventurers on every path), and token-side context was write-only decoration (budokan keeps its own token→tournament map).

---

## Phase 1 — the lite token (`game-components` #123)

**What:** a new `token_lite` module: `CoreTokenLiteComponent`, a single-game ERC721 with *no mutable token state*.

| Change | For |
|---|---|
| Registry removed; one `game_address` slot, bound once | Single-game deployments paid a registry round-trip on every mint and sync for an answer that never changed |
| `update_game`, the game-over/objective latch, and all metagame callbacks removed | The game contract is the sole authority on game-over; the latch was advisory and the callbacks were never consumed. `is_playable` becomes **zero storage reads** (lifecycle lives packed in the token id) |
| Objectives, context, skills, per-token renderer/client_url, enumerable, settings-validation-on-mint removed | Audits showed all unused by SDM; enumerable cost 2+ storage writes per mint/transfer for a view nothing on-chain called |
| New `assert_owner_and_playable(token_id, expected_owner)` | Merges the per-action ownership + playability pair into **one** external call |
| `mint` / `mint_batch_recipients` keep the full token's exact ABI (unsupported params rejected loudly) | Existing call sites — dungeons, budokan, the `minigame::mint` helper — work unchanged against a lite deployment |
| The 251-bit packed token-id layout kept bit-identical (zeros in dead fields) | ~10 call sites and the indexer decode `settings_id`/`minted_by`/lifecycle from the id; 75 freed bits kept as a compatible reserve |
| `minigame::lite::{pre_action, post_action}` helpers | Game code keeps its familiar call-site shape; the module path carries the semantic shift |
| Registry-less `assert_game_registered`: mutual game↔token pairing | Replaces the registry's integrity role — the token→game binding is the one half of the pairing an impostor cannot forge |
| Game-side settings/objectives extensions probe SRC5 before announcing to the token | The unconditional `create_settings` dispatch would have bricked settings creation (including SDM's GameToken constructor) against a lite token |
| `MinigameTokenLite` preset (Ownable + Upgradeable) with two-phase `bind_game` | Production deployable; two-phase init breaks the token↔game mutual-constructor circularity on real networks |

**Measured (component benches):** per-action guard pair 449k → 271k (−40%); post-action sync 1,648k → 186k against mocks — against the real contract the sync path (6.73M) is deleted outright; warm mint −22%.

**Final decision — self-binding only.** The lite component originally supported two deployment shapes: embedded in the game contract (one-address) and as a separate token contract paired to a game. Once Phase 4's measurements showed the separate shape strictly worse on gas, supporting it only kept dead machinery alive, so the component was committed to self-binding: the game contract IS the token. The `game_address` storage slot, `bind_game`, the two-phase `register_interfaces` init, the `MinigameTokenLite` preset, and the `minigame::lite::{pre_action, post_action}` cross-contract helpers were all deleted (the game calls the component internally); `game_address()` now returns the contract's own address, and the ecosystem pairing check in `assert_game_registered` simplified to an address equality (`token_address == game_address`), saving a cross-contract call at tournament creation. The `IMinigameTokenLite` ABI and `IMINIGAME_TOKEN_LITE_ID` are unchanged — `mint`'s `game_address` parameter survives for ABI parity (it must equal the contract's own address, same error string as before).

## Phase 2 — SDM integration (`super-death-mountain` #149)

| Change | For |
|---|---|
| All 10 GameCore entrypoints: `assert_token_ownership` + `pre_action` → one `lite::pre_action` call | Two token round-trips per action become one |
| `start_game` stops calling `update_game`; emits the ERC-4906 refresh like every other action | There is nothing to latch at start (score 0) — the call was paying the full 6.73M subtree for a no-op |
| Behavioural tests updated; mock gains the merged guard | 869/869 green |

**Measured (harness, origin/main → #149):** start_game 39.31M → 37.74M; attack 42.69M → 40.61M; 13-action game 80.64M → 77.69M.

## Phase 3 — budokan v2 (`budokan` #313)

Decision: with the registry retired, budokan goes **lite-only from day one** (a fresh v2 deployment) rather than carrying dual-mode branches; the existing budokan serves legacy tournaments until they wind down. A dual-mode bridge (#312) was built, measured, and deliberately closed as superseded.

| Change | For |
|---|---|
| Constructor is `(owner)`; `MetagameComponent` removed | There is no shared "default token" — every mint already resolved `game.token_address()` per tournament |
| Game validity = SRC5 lite-id + mutual game↔token pairing + settings exist | The registry's integrity role, one slot instead of a contract |
| `GameConfig` → `{game_address, settings_id, soulbound}`; `metadata_value` removed from entrypoints; no context/client_url mint decoration | Those surfaces no longer exist on the token; the decoration was `token_uri`-only — budokan's own registration map is the real token→tournament association |
| Game-creator fee shares rejected at creation | The registry that resolved the recipient is gone; a game-declared `IMinigameCreator` surface is the designed replacement (follow-up) |
| Viewer bug fixed: `owner_of` was called on budokan itself | Pre-existing; both affected views reverted for *any* token |

**Unchanged by design:** scoring (read from the game), leaderboards, prizes, entry requirements, registration — none ever touched the removed surfaces. Tests: 227/32/13 across packages, the whole suite running on the real lite pair.

## Phase 4 — one address (`super-death-mountain` #150)

The library-class pattern (already used by budokan's rewards class) dissolved the class-size argument for keeping the token separate:

| Change | For |
|---|---|
| GameCore **is** the token: ERC721 + lite core + minter + settings + `IMinigameTokenData`, self-bound at construction | The remaining per-action token/settings calls become internal (zero syscalls); the token cannot desync from the game; budokan's pairing check passes as self==self with zero budokan changes |
| Five subsystems become **library classes** behind owner-settable class hashes | A library call executes in GameCore's context — the baked `GAME_CORE_ADDRESS` constant, the subsystem caller-gates, and the two-pass declare/upgrade deployment all disappear; upgrades become one storage write |
| GameToken contract deleted; its settings field-pointer optimizations preserved inside GameCore | One address, one storage |
| Class-size splits: `GameSession` (state load/write, start_game) and `SettingsSystem` (whole-struct settings I/O) as additional library classes sharing GameCore's storage | The naive merge was 130k CASM felts vs the 81,920 limit |

**First deployment measured a regression** — attack +160k vs the multi-contract stack — because each action crossed *three* library boundaries (load → subsystem → write), serializing the full adventurer+bag four extra times. Since `start_game` runs once but actions run ~75 times, break-even was at two actions: a net loss for real games.

**The fix (boundary collapse):** `GameSession` now owns the entire action body — load, settings reads, `uses_vrf`, the seal write (strictly before dispatch, preserving the security invariant), the single subsystem library call, write-back, and events — all in the shared storage context. GameCore's entrypoints reduced to: internal guard → **one** session library call → internal refresh. 864/864 tests, zero test changes needed. Final CASM: GameCore 61,877, GameSession 70,263 (limit 81,920).

## Phase 5 — lite-native token-id layout (`game-components`, this branch)

Phase 1 kept the full token's 251-bit id layout bit-identical (zeros in the dead fields) to avoid touching call sites during the migration. With no lite deployment on mainnet yet, that compatibility shim was retired before first release: the lite token now has its **own** layout in `token_lite/packing.cairo` (`pack_lite_token_id`, `unpack_lite_token_id`, per-field helpers — same DivRem-chain style as `token::structs`, which stays untouched and keeps serving legacy denshokan). The one truly dead field (`game_id` — self-bound, always this contract) is gone from the id; `settings_id` and `salt` widen to 16 bits each; `metadata` widens from the full token's 16 bits to a 65-bit field absorbing every remaining spare bit.

Low u128 (128 bits): `minted_at(35) | start_delay(25) | end_delay(25) | settings_id(16) | minted_by(26) | soulbound(1)`

High u128 (123 bits): `tx_hash(10) | salt(16) | paymaster(1) | has_context(1) | objective_id(30) | metadata(65)`

| Bits (low) | Field | Bits (high) | Field |
|---|---|---|---|
| 0–34 | minted_at (unix s) | 0–9 | tx_hash (last 10 bits) |
| 35–59 | start_delay | 10–25 | salt (16-bit multicall counter) |
| 60–84 | end_delay (0 = immortal) | 26 | paymaster |
| 85–100 | settings_id (≤ 0xFFFF, ABI stays `Option<u32>`) | 27 | has_context (context data NOT stored) |
| 101–126 | minted_by (26-bit minter id) | 28–57 | objective_id (inert, game-interpreted) |
| 127 | soulbound | 58–122 | metadata (65-bit, u128 param ≤ 2^65−1) |

The high half is **fully allocated — there is no reserved region**: the spare bits were merged into the single writable `metadata` field, in line with the original layout's single-field design. A future protocol-owned field would require a new contract generation — an accepted trade-off. The batch salt bound rises to `salt + sum(counts) - 1 <= 0xFFFF`, and `settings_id > 0xFFFF`, `objective_id > 2^30−1` and `metadata > 2^65−1` are rejected at mint. **The indexer must branch its token-id decode by contract generation:** ids from legacy denshokan decode with the full layout, ids from lite (one-address) contracts with this one.

### The ABI strip (same branch, deliberate break)

With the layout compat shim retired, the ABI compat shim went with it — before first release, on the principle: **delete dead machinery and compat shims; keep capability (writes) and cheap client-facing read views.** The `IMinigameTokenLite` trait is now its own surface, not an `IMinigameToken` mirror:

| Change | Detail |
|---|---|
| `mint` reshaped to 12 args | `mint(player_name, settings_id, start, end, objective_id, context, client_url, to, soulbound, paymaster, salt, metadata)` — no `game_address` (self-bound) and no `renderer_address`/`skills_address` (no per-token renderer/skills surface); `mint_batch_recipients` matches (recipients array in place of `to`) |
| Restored params keep their original full-token behaviors | `objective_id` → packed field, INERT data the game interprets (no completion machinery — `completed_objective` stays always-false); `context` → sets the id's has_context bit only, the data is NOT stored (full-token parity: its context hook was a documented no-op); `client_url` → storage-backed with a `client_url` view (empty default); `paymaster` → packed bit; `metadata` → u128 param packed into the 65-bit field, read via the `mint_metadata` view — the shared `TokenMetadata.metadata: u16` (deployed full-token ABI) cannot hold it and stays 0, never truncated |
| Compat views deleted | `game_address` (was: returns self) and `game_registry_address` (was: returns zero) — consumers now SRC5-probe `IMINIGAME_TOKEN_LITE_ID` instead of resolving addresses; `metagame::assert_game_registered` probes the lite id first and falls through to the unchanged full-token registry path |
| Guards moved internal | `assert_is_playable` and `assert_owner_and_playable` left the ABI — they are the embedding game's own pre-action checks (`InternalTrait`, zero syscalls). Clients read `is_playable` |
| `refresh_metadata_batch` deleted | A multicall of singles |
| Read views + rename kept | `token_metadata`, `is_playable`, `settings_id`, `minted_by`, `minted_by_address`, `is_soulbound`, `objective_id`, `client_url`, `mint_metadata`, `player_name` (near-zero-cost client/RPC conveniences) and `update_player_name` (owner-gated capability) stay |
| Legacy id registration dropped | `initializer()` registers ONLY `IMINIGAME_TOKEN_LITE_ID` — SRC5 is honest; `supports_interface(IMINIGAME_TOKEN_ID)` is now false on lite tokens |
| New interface id | `IMINIGAME_TOKEN_LITE_ID = 0x15951d6d145a5a13c454bd75f0787e43e531a80a4bfb42a01fc4859e6fb7aea` (rederived over the 14-function surface minus `refresh_metadata`, per the refresh-exclusion convention) |

**Downstream:** SDM dungeons/GameCore and budokan v2 migrate their mint call sites to the 12-arg shape (drop the game-address, renderer and skills arguments; the remaining params keep their full-token positions and meanings — pass `None`/`false`/`0` where unused, noting `metadata` is now `u128`), GameCore's guard becomes the component-internal call, and anything that asserted the full-token id or called `game_registry_address()` on a lite token switches to the lite-id SRC5 probe.

---

## Final measured results

**Sepolia, real transactions, identical action (first attack on the starter beast), total tx L2 gas:**

| | mint | start_game | attack (×N per game) |
|---|---|---|---|
| Multi-contract lite (#149) | 4,602,400 | 5,315,280 | 4,680,320 |
| One-address, 3 boundaries | 4,602,400 | 4,995,280 | 4,840,320 ❌ |
| **One-address, 2 boundaries (final)** | 4,602,400 | **4,995,280 (−6.0%)** | **4,440,320 (−5.1%)** |

**Per-action estimates for the other entrypoints.** Method: the harness's cumulative benches yield a per-action execution delta, and adding each stack's measured protocol overhead (on-chain attack minus harness attack: 1,805,666 for #149, 1,834,426 for the final stack) reproduces the measured attack numbers exactly — so the same anchor gives reliable estimates for the actions we benched but didn't send on-chain:

| Action (total tx L2 gas) | #149 stack | One-address final | Δ |
|---|---|---|---|
| start_game *(measured)* | 5,315,280 | 4,995,280 | −320k (−6.0%) |
| attack *(measured)* | 4,680,320 | 4,440,320 | −240k (−5.1%) |
| explore | ~4,342,000 | ~4,094,000 | ~−250k (−5.7%) |
| surrender | ~3,113,000 | ~3,019,000 | ~−95k (−3.0%) |
| select_stat_upgrades | ~3,787,000 | ~3,868,000 | ≈ break-even¹ |
| flee / equip / drop_items / buy_items | *not benchmarked* | | structurally the same call pattern; expect flee ≈ attack-class, equip/drop ≈ stat-upgrades-class, buy_items between |

¹ The architectural saving is a roughly constant *absolute* amount per action (removed token/settings calls vs. the session boundary's adventurer+bag payload). Heavy actions (attack, explore) net −5–6%; the lightest action (stat upgrades) is where the fixed boundary payload roughly cancels the removed calls. Two effects bias this table *against* the final stack: the #149 harness numbers use a mock token that deliberately under-charges the real token calls by ~60–100k/action (true #149 costs are higher, so true deltas are better across the board, pulling stat upgrades to neutral-or-better), and light actions are exactly the ones that gain most from client-side batching, since their cost is dominated by the ~1.8M protocol overhead.

**Harness, full architecture span (origin/main → final):** attack −15.3%, start_game −14.7%, 13-action game −9.7% — understated, because the harness mock charged a fraction of real denshokan costs and the original also paid the ~6.73M keeper latch per game that no longer exists.

**Per beast-mode game (75 actions):** ~388M gas → ~343M ≈ **$0.40 → ~$0.35 (−12%)**. At 75 actions the per-action cost is 94% of the game, and ~2M of every action transaction is protocol overhead (validation, fee transfer, calldata) that no contract architecture can remove — ~44% of the game's total. **Next lever: client-side action batching** (multicall across actions, trivial now that everything is one address): ~$0.28 at 2 actions/tx, ~$0.25 at 3.

**Live E2E proof (Sepolia):** the full loop — budokan v2 `create_tournament` → `enter_tournament` (entry token minted by budokan on the game contract itself) → `start_game` → `attack` → `submit_score` → leaderboard — ran on-chain against both the multi-contract stack (tournament 1) and the one-address stack (tournament 2, after upgrading the live GameCore *in place* with two invokes). Key addresses: one-address GameCore `0x04f9bf2c7ace4ca777048e5fa4c0aa0206cc6c3fe856a244f65c11ff2da16bd4`, budokan v2 `0x0759dce1485904dc9a3db04480f06b07d4d34b08a2315bbbf7769625df15ec7a`, standalone lite token `0x061a97eb76ee193e61bb1777b66dfec365b2d50a7281ab8310024278b479032a`.

---

## Rollout order and open items

1. **Merge #123** (game-components) and cut a release tag.
2. **#149 → #150** (SDM) and **#313** (budokan): flip each `TEMPORARY PIN` from branch `feat/token-lite` to the tag, refresh locks.
3. Deploy per network. Note: Sepolia (Starknet 0.14.3) accepts Sierra ≤1.7 — SDM's 2.20 toolchain output is rejected there; #150 currently pins `starknet = 2.16.1` (reviewer decision needed on repo toolchain).

**Open follow-ups:** client-side action batching (the biggest remaining per-game lever); `IMinigameCreator` game-declared fee surface; negative-path tests for the lite pairing check; indexer/SDK migration for budokan v2's slimmed ABI and the one-address event source; a production `token_uri` (the renderer contract is wired but `create_metadata` has a pre-existing u64 truncation for packed ids); rewrite of SDM's `scripts/deploy*.sh` for the 3-step flow; decision on where game metadata (name/image/genre) lives now that the registry is gone.

---

## The lite token is the standard

As the final step of this migration, the repo renamed the lite token to be THE
minigame token standard and demoted the original full token to an explicit
"legacy" naming. This is a **source-level rename only**: every interface-id
VALUE and selector is unchanged — deployed contracts registered them on-chain
and they are frozen forever. Downstream repos should migrate names using this
map:

| Old name (pre-rename) | New standard name | Legacy name |
| --- | --- | --- |
| `IMinigameTokenLite` (+`Dispatcher`/`DispatcherTrait`) | `IMinigameToken` (+`Dispatcher`/`DispatcherTrait`) | — |
| `IMINIGAME_TOKEN_LITE_ID` (= `0x15951d…7aea`) | `IMINIGAME_TOKEN_ID` (same value) | — |
| `IMinigameToken` (original full trait) | — | `IMinigameTokenLegacy` |
| `IMINIGAME_TOKEN_ID` (original, = `0x246f61…9906`) | — | `IMINIGAME_TOKEN_LEGACY_ID` (same value) |
| `game_components_interfaces::token::lite` | `game_components_interfaces::token::core` | — |
| `game_components_interfaces::token::core` (original) | — | `game_components_interfaces::token::legacy` |
| `embeddable_game_standard::token_lite` module | `embeddable_game_standard::token` | — |
| `embeddable_game_standard::token` module (original) | — | `embeddable_game_standard::token_legacy` (all names inside unchanged: `CoreTokenComponent`, `structs::PackedTokenId`, …) |
| `CoreTokenLiteComponent` (+`CoreTokenLiteImpl`) | `MinigameTokenComponent` (+`MinigameTokenImpl`) | — |
| `token_lite::packing::{LitePackedTokenId, pack_lite_token_id, unpack_lite_token_id}` | `token::packing::{PackedTokenId, pack_token_id, unpack_token_id}` | — |
| Error prefixes `"MinigameTokenLite: …"` / `"LitePackedTokenId: …"` | `"MinigameToken: …"` / `"PackedTokenId: …"` | — |
| `LiteGameMock` (`test_common::mocks::lite_game_mock`) | `StandardGameMock` (`test_common::mocks::standard_game_mock`) | — |

Additionally, **the minter is standard, not optional**: the legacy
`MinterComponent`'s substance (storage under the same variable names,
`IMinigameTokenMinter` impl, `MinterRegistryUpdate` event,
`IMINIGAME_TOKEN_MINTER_ID` registration) is absorbed directly into
`MinigameTokenComponent`. Embedders drop the separate
`component!(MinterComponent…)` wiring and embed
`MinigameTokenComponent::MinterImpl` instead; the `OptionalMinter` indirection
remains only in `token_legacy`. `IMinigameTokenMinter` and its id are
unchanged, and the standard token's SRC5 id was NOT rederived (its trait did
not change).
