# Minigame

Individual game logic foundation. Each game contract embeds this component and **must** implement the `IMinigameTokenData` trait to provide score and game state.

## Features

- Game lifecycle management (mint, play, complete)
- Required `IMinigameTokenData` trait for score and game-over queries
- Optional settings and objectives extensions
- Token integration for NFT-based game instances
- Pre/post action hooks for game state validation
- Batch operations for multi-token queries

## Interface

### IMinigame (Core)

| Method | Returns | Description |
|--------|---------|-------------|
| `token_address()` | `ContractAddress` | Associated MinigameToken |
| `settings_address()` | `ContractAddress` | Optional settings contract |
| `objectives_address()` | `ContractAddress` | Optional objectives contract |

`IMinigame` carries only the identity views. Minting goes through the token's
own `IMinigameTokenMinter::mint` (the game IS the token).

**Interface ID**: `0x3672f24df9fc27c3ad99aa4e9f0a7173ccf1786921339b91fa5297588600260`

### IMinigameTokenData (MUST IMPLEMENT)

| Method | Returns | Description |
|--------|---------|-------------|
| `score(token_id)` | `u32` | Current score for token |
| `game_over(token_id)` | `bool` | Whether game has ended |
| `score_batch(token_ids)` | `Array<u32>` | Batch scores |
| `game_over_batch(token_ids)` | `Array<bool>` | Batch game states |

### IMinigameDetails (Optional)

| Method | Returns | Description |
|--------|---------|-------------|
| `token_name(token_id)` | `ByteArray` | Display name for token |
| `token_description(token_id)` | `ByteArray` | Token description |
| `game_details(token_id)` | `Span<GameDetail>` | Key-value game details |

### InternalTrait

| Method | Description |
|--------|-------------|
| `initializer(creator, name, description, ...)` | Initialize and register game |
| `pre_action(token_id)` | Call before game actions |
| `post_action(token_id)` | Call after game actions |
| `get_player_name(token_id)` | Get player name from token |
| `require_owned_token(token_id)` | Assert caller owns token |
| `assert_game_token_playable(token_id)` | Assert token is playable |

## Extensions

### Settings (`extensions/settings/`)

Game configuration presets.

| Interface | Methods |
|-----------|---------|
| `IMinigameSettings` | `settings_exist(settings_id)`, `settings_exist_batch(...)` |
| `IMinigameSettingsDetails` | `settings_details(settings_id)` |
| `IMinigameSettingsSVG` | `settings_svg(settings_id)` |

**Interface ID**: `0x0379f4343538c65a38349fb1318328629dd950d3624101aeaac1b4bd45a39eff`

### Objectives (`extensions/objectives/`)

Achievement tracking.

| Interface | Methods |
|-----------|---------|
| `IMinigameObjectives` | `objective_exists(id)`, `completed_objective(token_id, id)` |
| `IMinigameObjectivesDetails` | `objectives_details(token_id)` |
| `IMinigameObjectivesSVG` | `objectives_svg(token_id)` |

**Interface ID**: `0x0213cfcf73543e549f00c7cad49cf27a1e544d71315ff981930aaf77ac0709bd`

## Usage

```cairo
use game_components_embeddable_game_standard::minigame::minigame_component::MinigameComponent;
use game_components_interfaces::minigame::IMinigameTokenData;
use openzeppelin_introspection::src5::SRC5Component;

#[starknet::contract]
mod MyGame {
    component!(path: MinigameComponent, storage: minigame, event: MinigameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        minigame: MinigameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Game-specific storage
        game_data: Map<u64, GameState>,
    }

    // REQUIRED: Implement IMinigameTokenData
    impl MinigameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: u64) -> u32 {
            self.game_data.read(token_id).score
        }
        fn game_over(self: @ContractState, token_id: u64) -> bool {
            self.game_data.read(token_id).is_finished
        }
        // ... batch methods
    }

    #[abi(embed_v0)]
    impl MinigameImpl = MinigameComponent::MinigameImpl<ContractState>;
}
```

## Game Lifecycle

1. **Init**: Deploy with `token_address`, optional `settings_address`/`objectives_address`
2. **Mint**: Call `mint()` (`IMinigameTokenMinter`) to create playable token
3. **Validate**: Use `assert_game_token_playable(token_id)` before actions
4. **Play**: Update game state, `pre_action()`/`post_action()` hooks
5. **Complete**: Return `true` from `game_over()` when finished

## Dependencies

- `game_components_interfaces` - Interface and struct definitions
- `openzeppelin_introspection` - SRC5 interface registration
