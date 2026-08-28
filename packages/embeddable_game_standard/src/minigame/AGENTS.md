# Minigame Module

The interfaces a game contract implements, plus two optional extensions. There
is no `MinigameComponent` and no `IMinigame`: a game embeds
`MinigameTokenComponent` directly and IS its own token, so it is identified by
`IMINIGAME_TOKEN_ID` rather than a separate game id.

## What lives here

| Path | Purpose |
|------|---------|
| `interface.cairo` | `IMinigameTokenData`, `IMinigameDetails`, `IMinigameDetailsSVG` |
| `structs.cairo` | `GameDetail` |
| `extensions/settings/` | `SettingsComponent` — settings presets |
| `extensions/objectives/` | `ObjectivesComponent` — achievement tracking |

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

### IMinigameDetails (Optional)

| Method | Returns | Description |
|--------|---------|-------------|
| `token_name(token_id)` | `ByteArray` | Display name for token |
| `token_description(token_id)` | `ByteArray` | Token description |
| `game_details(token_id)` | `Span<GameDetail>` | Key-value game details |

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
