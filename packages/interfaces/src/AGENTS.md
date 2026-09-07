## Package: interfaces

Single source of truth for all game component interface definitions. Other packages import from here for cross-contract calls and SRC5 interface detection.

## Interface Modules

| Module | Interfaces | Purpose |
|--------|------------|---------|
| `metagame` | `IMetagame`, `IMetagameContext`, `IMetagameCallback` | Game management, context extensions |
| `minigame` | `IMinigame`, `IMinigameTokenData`, `IMinigameSettings`, `IMinigameObjectives` | Game logic, score/game_over queries |
| `token` (`token/core`) | `IMinigameToken` | THE minigame token standard: gas-optimized token embedded in the game contract itself (self-bound, no registry, no mutable state), plus the `IMinigameTokenMinter` surface |
| `token/game_fee` | `IMinigameTokenGameFee` | Game fee recipient (payout sink) + license + fee rate on the standard token (replaces the registry's `game_fee_info`); setters gated on the game contract's Ownable owner |
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
pub const IMINIGAME_TOKEN_GAME_FEE_ID: felt252 = 0x...;
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

**IMinigame** (identity views only — self-bound game returns its own address):
- `token_address() -> ContractAddress`
- `settings_address() -> ContractAddress`
- `objectives_address() -> ContractAddress`

**ILeaderboard**:
- `submit_score(tournament_id, token_id, score, position) -> LeaderboardResult`
- `get_entries(tournament_id) -> Array<LeaderboardEntry>`
- `qualifies(tournament_id, score) -> bool`

## Computing SRC5 Interface IDs

Use `src5_rs parse` to compute interface IDs. The tool is normally pre-installed at
`~/.cargo/bin/src5_rs`; if it is missing it is NOT on crates.io, install it from source:

```bash
cargo install --git https://github.com/ericnordelo/src5-rs   # v2.0.0
```

Sanity-check the setup before trusting a new ID: rerun the derivation for the
CURRENT constant first and confirm it reproduces byte for byte. If it does not,
the stripped input is wrong, not the constant.

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

### Methods excluded from `IMINIGAME_TOKEN_ID`

`IMINIGAME_TOKEN_ID` is derived over `IMinigameToken` **minus** `refresh_metadata`.
Omit that method from the stripped input file or the constant will not reproduce
(the per-selector breakdown is kept in the doc comment above the constant in
`token/core.cairo`).

The ID is registered on-chain by every deployed token contract. Rederiving it to
cover an additive, optional method would make
`supports_interface(IMINIGAME_TOKEN_ID)` return false on all of them and break
interface discovery for every existing consumer — a breaking change across the
ecosystem in exchange for nothing a caller can act on. The ID identifies the
original surface, which those contracts all still implement in full.

Apply the same reasoning to future additive methods: extend the trait, leave the ID
alone, and note the exclusion here. Change the ID only for a genuinely breaking
change to the existing surface.

### `IMINIGAME_TOKEN_ID` value history

The VALUE is not casually changeable — deployed contracts register it on-chain,
and a change makes `supports_interface(IMINIGAME_TOKEN_ID)` return false on every
one of them. It moves only for a genuinely breaking change to the existing
surface (the rule above), and every move must be recorded here.

| Value | Since | Why it moved |
| --- | --- | --- |
| `0x15951d6d…b7aea` | lite token introduced | — (named `IMINIGAME_TOKEN_LITE_ID` then) |
| `0x20253de95bcdb23620c88405a5f97da040b91de832ad98a34b45c4f3331d13b` | 2.1.1 | surface changes at the lite→standard transition; the constant took the `IMINIGAME_TOKEN_ID` name |
| `0x1238d845bb65d15a4ae71f27bef35d008ad496acb4c3b840c5de17bf0111559` | this change | `is_playable` renamed to `is_lifecycle_open` — a breaking rename of an existing entrypoint, so the ID moves with it |

Rederive after any change to the surface, and paste the tool's per-selector rows
into the doc comment above the constant:

```bash
src5_rs parse /tmp/src5_input.cairo   # trait minus refresh_metadata, stripped per above
```

A wrong ID does NOT fail to compile. It fails at runtime, silently, as
`supports_interface` returning false everywhere — never hand-edit the constant
or XOR it by eye, always paste what `src5_rs` printed.

## Dependencies

None - this is a leaf package with no internal dependencies. Uses only:
- `starknet` stdlib
- `ekubo` (for tokenomics interfaces only)
