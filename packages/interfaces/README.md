# Interfaces

Centralized interface and struct definitions for all game components. Other packages import from here for cross-contract calls and SRC5 interface detection.

## Interface Modules

| Module | Interfaces | Purpose |
|--------|------------|---------|
| `metagame` | `IMetagame`, `IMetagameContext`, `IMetagameCallback` | Game management, context extensions |
| `minigame` | `IMinigame`, `IMinigameTokenData`, `IMinigameSettings`, `IMinigameObjectives` | Game logic, score/game_over queries |
| `token` | `IMinigameToken`, `IMinigameTokenMinter`, `IMinigameTokenObjectives`, `IMinigameTokenSettings`, `IMinigameTokenRenderer` | ERC721 token with extensions |
| `registry` | `IMinigameRegistry` | Game registration and metadata lookup |
| `leaderboard` | `ILeaderboard`, `ILeaderboardAdmin`, `IGameDetails` | Tournament scoring and rankings |
| `tokenomics/buyback` | `IBuyback`, `IBuybackAdmin` | Autonomous buyback via Ekubo TWAMM |
| `tokenomics/stream` | `IStreamToken`, `IStreamTokenFactory` | Token distribution streams |

## Struct Modules

| Module | Structs |
|--------|---------|
| `structs/token` | `TokenMetadata`, `Lifecycle`, `MintParams`, `PlayerNameUpdate` |
| `structs/minigame` | `GameDetail`, `MintGameParams`, `GameSettingDetails`, `GameSetting`, `GameObjective` |
| `structs/metagame` | `GameContextDetails`, `GameContext` |
| `structs/leaderboard` | `LeaderboardConfig`, `LeaderboardEntry`, `LeaderboardResult`, `LeaderboardStoreConfig` |
| `structs/registry` | `GameMetadata` |

## Interface ID Constants

```cairo
pub const IMETAGAME_ID: felt252 = 0x...;
pub const IMETAGAME_CONTEXT_ID: felt252 = 0x...;
pub const IMINIGAME_ID: felt252 = 0x...;
pub const IMINIGAME_SETTINGS_ID: felt252 = 0x...;
pub const IMINIGAME_OBJECTIVES_ID: felt252 = 0x...;
pub const IMINIGAME_TOKEN_ID: felt252 = 0x...;
pub const IMINIGAME_TOKEN_MINTER_ID: felt252 = 0x...;
pub const IMINIGAME_REGISTRY_ID: felt252 = 0x...;
pub const ILEADERBOARD_ID: felt252 = 0x...;
```

## Usage

### Cross-Contract Calls (Dispatcher Pattern)

```cairo
use game_components_interfaces::{
    IMinigameDispatcher, IMinigameDispatcherTrait,
    IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};

// Call another contract
let minigame = IMinigameDispatcher { contract_address: game_address };
let score = minigame.score(token_id);
let is_over = minigame.game_over(token_id);
```

### SRC5 Interface Registration

```cairo
use game_components_interfaces::{IMINIGAME_ID, IMINIGAME_SETTINGS_ID};
use openzeppelin_introspection::src5::SRC5Component;

// In component initialization
self.src5.register_interface(IMINIGAME_ID);

// Check if contract supports interface
let supports = src5_dispatcher.supports_interface(IMINIGAME_SETTINGS_ID);
```

### Importing Structs

```cairo
use game_components_interfaces::{
    TokenMetadata, Lifecycle, MintParams,
    GameMetadata, GameDetail,
    LeaderboardEntry, LeaderboardConfig,
};
```

## Key Interface Methods

**IMinigameTokenData** (required for minigame contracts):
- `score(token_id: u64) -> u32` - Get token's current score
- `game_over(token_id: u64) -> bool` - Check if game has ended

**IMinigame**:
- `is_playable(token_id: u64) -> bool` - Check if token can be played
- `update_game(token_id: u64)` - Sync token state with game state

**ILeaderboard**:
- `submit_score(tournament_id, token_id, score, position) -> LeaderboardResult`
- `get_entries(tournament_id) -> Array<LeaderboardEntry>`
- `qualifies(tournament_id, score) -> bool`

## Dependencies

None - this is a leaf package with no internal dependencies. Uses only:
- `starknet` stdlib
- `ekubo` (for tokenomics interfaces only)
