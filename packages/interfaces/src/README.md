# Interfaces

Centralized interface and struct definitions for all game components. Other packages import from here for cross-contract calls and SRC5 interface detection.

## Interface Modules

| Module | Interfaces | Purpose |
|--------|------------|---------|
| `metagame` | `IMetagame`, `IMetagameContext`, `IMetagameCallback` | Game management, context extensions |
| `minigame` | `IMinigame`, `IMinigameTokenData`, `IMinigameSettings`, `IMinigameObjectives` | Game logic, score and game-state queries |
| `token` (`token/core`) | `IMinigameToken` | THE minigame token standard: self-bound token embedded in the game contract (plus the `IMinigameTokenMinter` surface) |
| `leaderboard` | `ILeaderboard`, `ILeaderboardAdmin`, `IGameDetails` | Tournament scoring and rankings |
| `tokenomics/buyback` | `IBuyback`, `IBuybackAdmin` | Autonomous buyback via Ekubo TWAMM |
| `tokenomics/stream` | `IStreamToken`, `IStreamTokenFactory` | Token distribution streams |

## Struct Modules

| Module | Structs |
|--------|---------|
| `structs/token` | `TokenMetadata`, `Lifecycle`, `MintBatchRecipient`, `GameFeeTerms` |
| `structs/minigame` | `GameMetadata`, `GameDetail`, `GameSettingDetails`, `GameSetting`, `GameObjective` |
| `structs/metagame` | `GameContextDetails`, `GameContext` |
| `structs/leaderboard` | `LeaderboardConfig`, `LeaderboardEntry`, `LeaderboardResult`, `LeaderboardStoreConfig` |

## Interface ID Constants

```cairo
pub const IMETAGAME_CONTEXT_ID: felt252 = 0x...;
pub const IMINIGAME_ID: felt252 = 0x...;
pub const IMINIGAME_SETTINGS_ID: felt252 = 0x...;
pub const IMINIGAME_OBJECTIVES_ID: felt252 = 0x...;
pub const IMINIGAME_TOKEN_ID: felt252 = 0x...;
pub const IMINIGAME_TOKEN_MINTER_ID: felt252 = 0x...;
pub const ILEADERBOARD_ID: felt252 = 0x...;
```

## Usage

### Cross-Contract Calls (Dispatcher Pattern)

```cairo
use game_components_interfaces::token::core::{
    IMinigameTokenDataDispatcher, IMinigameTokenDataDispatcherTrait,
};

// Read game-owned data from another contract
let game_data = IMinigameTokenDataDispatcher { contract_address: game_address };
let score = game_data.score(token_id);
let is_over = game_data.game_over(token_id);
let is_new = game_data.new_game(token_id);
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
    TokenMetadata, Lifecycle, MintBatchRecipient,
    GameMetadata, GameDetail,
    LeaderboardEntry, LeaderboardConfig,
};
```

## Key Interface Methods

**IMinigameTokenData** (implemented by games for their token data):
- `score(token_id: felt252) -> u64` - Get token's current score
- `game_over(token_id: felt252) -> bool` - Check if game has ended
- `new_game(token_id: felt252) -> bool` - True for an existing token whose gameplay has not started; false for nonexistent or burned tokens. Initialization/setup alone does not start gameplay; commit/reveal games may derive this from zero commitments.
- `score_batch(token_ids: Span<felt252>) -> Array<u64>` - Get scores for multiple tokens
- `game_over_batch(token_ids: Span<felt252>) -> Array<bool>` - Get game-over states for multiple tokens

Adding `new_game` requires every `IMinigameTokenData` implementation to expose this
entrypoint. Existing deployed contracts do not acquire it automatically; callers
should invoke it only on deployments known to implement it, for example through an
allowlist or version check. A missing selector reverts the calling transaction. The
view has no independent SRC5 ID.

**IMinigame** (identity views only — self-bound game returns its own address):
- `token_address() -> ContractAddress`
- `settings_address() -> ContractAddress`
- `objectives_address() -> ContractAddress`

**ILeaderboard**:
- `submit_score(tournament_id, token_id, score, position) -> LeaderboardResult`
- `get_entries(tournament_id) -> Array<LeaderboardEntry>`
- `qualifies(tournament_id, score) -> bool`

## Dependencies

None - this is a leaf package with no internal dependencies. Uses only:
- `starknet` stdlib
- `ekubo` (for tokenomics interfaces only)
