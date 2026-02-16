# Minigame Component

Individual game logic foundation. Each game contract embeds this component and MUST implement `IMinigameTokenData` trait to provide score and game state.

## Storage

```cairo
#[storage]
pub struct Storage {
    token_address: ContractAddress,      // Required MinigameToken
    settings_address: ContractAddress,   // Optional IMinigameSettings
    objectives_address: ContractAddress, // Optional IMinigameObjectives
}
```

## Interfaces

### IMinigame (Core)

| Method | Returns | Description |
|--------|---------|-------------|
| `token_address()` | `ContractAddress` | Associated MinigameToken |
| `settings_address()` | `ContractAddress` | Optional settings contract |
| `objectives_address()` | `ContractAddress` | Optional objectives contract |
| `mint_game(player_name, settings_id, ...)` | `u64` | Mint single game token |
| `mint_game_batch(mints)` | `Array<u64>` | Batch mint game tokens |

**Interface ID**: `0x02c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499704`

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

### InternalTrait (Component internals)

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

## Component Embedding

```cairo
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

## Relationships

```
Minigame
  |-- token_address -------> MinigameToken (REQUIRED)
  |-- settings_address ----> IMinigameSettings (OPTIONAL)
  |-- objectives_address --> IMinigameObjectives (OPTIONAL)
```

## Game Lifecycle

1. **Init**: Deploy with `token_address`, optional `settings_address`/`objectives_address`
2. **Mint**: Call `mint_game()` to create playable token
3. **Validate**: Use `assert_game_token_playable(token_id)` before actions
4. **Play**: Update game state, `pre_action()`/`post_action()` hooks
5. **Complete**: Return `true` from `game_over()` when finished

## Critical Requirements

Games MUST implement `IMinigameTokenData`:
- `score(token_id)` - Return current score
- `game_over(token_id)` - Return true when game ends
- Batch versions for multi-token queries

Token validates game supports `IMINIGAME_ID` via SRC5 on registration.
