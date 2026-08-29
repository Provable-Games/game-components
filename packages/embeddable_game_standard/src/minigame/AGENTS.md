# Minigame Module

What is left that is distinctly *game*-level, now that the game IS its token.
Minting, playability and ownership live in `MinigameTokenComponent` on the same
contract; a game is identified by `IMINIGAME_TOKEN_ID`, not a separate game id.

So this module is: `MinigameComponent` (the game's own data — its identity, for
indexers and clients), the `IMinigameTokenData` surface a game implements to
answer for its tokens' score/game-over, and two optional extensions.

## What lives here

| Path | Purpose |
|------|---------|
| `minigame_component.cairo` | `MinigameComponent` — the game's own data (identity), served over `IMinigameGameMetadata` |
| `interface.cairo` | `IMinigameTokenData` |
| `structs.cairo` | `GameDetail` |
| `extensions/settings/` | `SettingsComponent` — settings presets |
| `extensions/objectives/` | `ObjectivesComponent` — achievement tracking |

## MinigameComponent

Records the game's identity once at construction and serves it over
`IMinigameGameMetadata::game_metadata()`.

```cairo
component!(path: MinigameComponent, storage: minigame, event: MinigameEvent);
#[abi(embed_v0)]
impl MinigameImpl = MinigameComponent::MinigameImpl<ContractState>;
impl MinigameInternalImpl = MinigameComponent::InternalImpl<ContractState>;

// in the constructor:
self.minigame.initializer(game_metadata);
```

`GameMetadata` carries the nine identity fields — name, description, developer,
publisher, genre, image, color, client_url, royalty_fraction. It is read once
per contract, not once per token, and is deliberately not parsed out of a
rendered token URI.

## Interfaces

### IMinigameTokenData (MUST IMPLEMENT)

| Method | Returns | Description |
|--------|---------|-------------|
| `score(token_id)` | `u32` | Current score for token |
| `game_over(token_id)` | `bool` | Whether game has ended |
| `score_batch(token_ids)` | `Array<u32>` | Batch scores |
| `game_over_batch(token_ids)` | `Array<bool>` | Batch game states |

The game is the sole authority here — the token holds no `game_over` latch and
never calls back to ask. Nothing syncs state between them.


## Extensions

### Settings (`extensions/settings/`)

| Interface | Methods |
|-----------|---------|
| `IMinigameSettings` | `settings_exist(settings_id)`, `settings_exist_batch(...)` |
| `IMinigameSettingsDetails` | `settings_details(settings_id)` |
| `IMinigameSettingsSVG` | `settings_svg(settings_id)` |

**Interface ID**: `0x0379f4343538c65a38349fb1318328629dd950d3624101aeaac1b4bd45a39eff`

`SettingsComponent` registers the interface id and exposes
`get_settings_id(token_id, token_address)`. It no longer announces created
settings to the token: that announcement dispatched to a token-side settings
surface that only the retired generation had, and the game is the source of
truth for which settings exist.

### Objectives (`extensions/objectives/`)

| Interface | Methods |
|-----------|---------|
| `IMinigameObjectives` | `objective_exists(id)`, `completed_objective(token_id, id)` |
| `IMinigameObjectivesDetails` | `objectives_details(token_id)` |
| `IMinigameObjectivesSVG` | `objectives_svg(token_id)` |

**Interface ID**: `0x0213cfcf73543e549f00c7cad49cf27a1e544d71315ff981930aaf77ac0709bd`

`ObjectivesComponent` registers the interface id. Objective IDs pack into the
token id as inert data the game interprets — the token has no completion
machinery, so `completed_objective` on `token_metadata` is always false.

## Building a game

The game contract embeds the TOKEN component; there is no separate game
component to embed. See `test_common::mocks::standard_game_mock` for the full
wiring — ERC721 + SRC5 + Ownable + `MinigameTokenComponent` (via
`MinigameTokenMixinImpl`) + optionally `SettingsComponent`.

```cairo
#[starknet::contract]
mod MyGame {
    component!(path: MinigameTokenComponent, storage: minigame_token, event: MinigameTokenEvent);
    // ERC721, SRC5, Ownable also required — Ownable administers the game-fee surface.

    // REQUIRED: the game answers for its own state.
    impl MinigameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: felt252) -> u32 { ... }
        fn game_over(self: @ContractState, token_id: felt252) -> bool { ... }
    }
}
```

## Game Lifecycle

1. **Init**: `MinigameTokenComponent::initializer(game_fee_recipient, license, fee_numerator)`
2. **Mint**: `mint()` (`IMinigameTokenMinter`) — the token is this contract
3. **Guard**: `assert_owner_and_playable(token_id, caller)` before actions — internal, zero syscalls
4. **Play**: update game state, then `refresh_metadata(token_id)` (ERC-4906)
5. **Complete**: return `true` from `game_over()` when finished

## Retired

The `minigame::minigame` token helpers moved to `token::libs`
(`assert_token_ownership`, `get_player_name`) — they are for a SEPARATE
contract acting on someone else's token (a minter, a dungeon, a tournament),
so they belong with the token. `require_owned_token` was dropped, unused.

`IMinigameDetails` / `IMinigameDetailsSVG` were removed too: nothing in the
workspace called them, and they describe a RENDERER surface — SVG generation is
large enough that games put it on a separate contract, which then exposes its
own interface. A game that wants detail rows defines them where the renderer
lives; `GameDetail` remains available as a struct for that.

`IMinigame` itself (and `IMINIGAME_ID`, `mint_game`, `mint_game_batch`,
`IMinigameTokenUri`) was removed once the game became its own token: the
address views were roundtrips returning the contract's own address, the mint
methods self-dispatched to the token's `mint`, and `token_uri` is served by
ERC721Metadata. Consumers now validate a game with
`supports_interface(IMINIGAME_TOKEN_ID)`.

`MinigameComponent` and the `minigame::minigame` lib (`pre_action`,
`post_action`, `register_game`, `update_game`) were removed with the
registry-backed generation. They existed to register a game into a registry and
to sync mutable token state — neither exists now. To build against that
generation, pin `v2.0.0` or earlier.
