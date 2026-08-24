## Package: interfaces

Single source of truth for all game component interface definitions. Other packages import from here for cross-contract calls and SRC5 interface detection.

## Interface Modules

| Module | Interfaces | Purpose |
|--------|------------|---------|
| `metagame` | `IMetagame`, `IMetagameContext`, `IMetagameCallback` | Game management, context extensions |
| `minigame` | `IMinigame`, `IMinigameTokenData`, `IMinigameSettings`, `IMinigameObjectives` | Game logic, score/game_over queries |
| `token` (`token/core`) | `IMinigameToken` | THE minigame token standard: gas-optimized token embedded in the game contract itself (self-bound, no registry, no mutable state), plus the `IMinigameTokenMinter` surface |
| `token/legacy` | `IMinigameTokenLegacy`, `IMinigameTokenMinter`, `IMinigameTokenObjectives`, `IMinigameTokenSettings`, `IMinigameTokenRenderer` | Original multi-game ERC721 token with extensions (kept for deployed denshokan) |
| `registry` | `IMinigameRegistry` | Game registration and metadata lookup |
| `leaderboard` | `ILeaderboard`, `ILeaderboardAdmin`, `IGameDetails` | Tournament scoring and rankings |
| `tokenomics/buyback` | `IBuyback`, `IBuybackAdmin` | Autonomous buyback via Ekubo TWAMM |
| `tokenomics/stream` | `IStreamToken`, `IStreamTokenFactory` | Token distribution streams |

## Struct Modules

| Module | Structs |
|--------|---------|
| `structs/token` | `TokenMetadata`, `Lifecycle`, `MintBatchRecipient`, `MintParams`, `PlayerNameUpdate` |
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
pub const IMINIGAME_TOKEN_LEGACY_ID: felt252 = 0x...;
pub const IMINIGAME_TOKEN_MINTER_ID: felt252 = 0x...;
pub const IMINIGAME_REGISTRY_ID: felt252 = 0x...;
pub const ILEADERBOARD_ID: felt252 = 0x...;
```

## Usage Patterns

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
    TokenMetadata, Lifecycle, MintBatchRecipient,
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

## Computing SRC5 Interface IDs

Use `src5_rs parse` to compute interface IDs. The tool is pre-installed at `~/.cargo/bin/src5_rs`.

**Critical:** `src5_rs` v2.0.0 cannot parse modern Cairo `<TState>` generics or `self` parameters. You must create a temporary stripped-down file:

1. Remove `<TState>` generic from the trait
2. Remove `self: @TState` / `ref self: TState` from all function signatures
3. Include struct definitions inline (the tool doesn't resolve imports)
4. Remove `#[starknet::interface]` and `pub` modifiers

Example — to compute the ID for:

```cairo
#[starknet::interface]
pub trait IMinigameTokenObjectives<TState> {
    fn create_objective(
        ref self: TState,
        game_address: ContractAddress,
        creator_address: ContractAddress,
        objective_id: u32,
        objective_details: GameObjectiveDetails,
    );
}
```

Create `/tmp/src5_input.cairo`:

```cairo
use starknet::ContractAddress;

struct GameObjective {
    name: ByteArray,
    value: ByteArray,
}

struct GameObjectiveDetails {
    name: ByteArray,
    description: ByteArray,
    objectives: Span<GameObjective>,
}

trait IMinigameTokenObjectives {
    fn create_objective(
        game_address: ContractAddress,
        creator_address: ContractAddress,
        objective_id: u32,
        objective_details: GameObjectiveDetails,
    );
}
```

Then run:

```bash
src5_rs parse /tmp/src5_input.cairo
```

The tool outputs the extended function selectors and the final XOR'd interface ID.

**Important notes:**
- `ByteArray` expands to `(Array<bytes31>,felt252,usize)` — note `usize`, not `u32`
- `bool` expands to `E((),())` (an enum)
- `Span<T>` expands to `(@Array<T>)`
- For multi-function interfaces, the ID is the XOR of all extended function selectors
- For single-function interfaces, the ID equals the single extended function selector
- Always update the EFS comment above the constant to match the tool's output

### Methods excluded from `IMINIGAME_TOKEN_LEGACY_ID`

`IMinigameTokenLegacy::refresh_metadata` and `refresh_metadata_batch` are **not**
part of the `IMINIGAME_TOKEN_LEGACY_ID` derivation. Omit both from the stripped
input file or the constant will not reproduce.

The ID is registered on-chain by every deployed token contract. Rederiving it to
cover two additive, optional methods would make
`supports_interface(IMINIGAME_TOKEN_LEGACY_ID)` return false on all of them and
break interface discovery for every existing consumer — a breaking change across
the ecosystem in exchange for nothing a caller can act on. The ID identifies the
original surface, which those contracts all still implement in full.

Apply the same reasoning to future additive methods: extend the trait, leave the ID
alone, and note the exclusion here. Change the ID only for a genuinely breaking
change to the existing surface.

The same refresh exclusion applies to `IMINIGAME_TOKEN_ID` (the standard token):
it is derived over `IMinigameToken` minus `refresh_metadata` (the per-selector
breakdown is kept in the doc comment above the constant in `token/core.cairo`).

### Frozen ID values across the standard/legacy rename

Both token interface-id VALUES are frozen — deployed contracts register them
on-chain. When the lite token became the standard, only the NAMES moved:

| Constant (today) | Value | Was named |
| --- | --- | --- |
| `IMINIGAME_TOKEN_ID` | `0x15951d6d145a5a13c454bd75f0787e43e531a80a4bfb42a01fc4859e6fb7aea` | `IMINIGAME_TOKEN_LITE_ID` |
| `IMINIGAME_TOKEN_LEGACY_ID` | `0x246f614bd76b91c378a91877851f2ccdb99278e9fb77c782a22355059ce9906` | `IMINIGAME_TOKEN_ID` |

## Dependencies

None - this is a leaf package with no internal dependencies. Uses only:
- `starknet` stdlib
- `ekubo` (for tokenomics interfaces only)
