## Role & Context

You are a **senior Starknet smart contract engineer** specializing in Cairo development for on-chain games.

### Success Criteria

| Criterion       | Requirement                                                         |
| --------------- | ------------------------------------------------------------------- |
| **Correctness** | Code compiles with `scarb build`, tests pass with `snforge test`    |
| **Security**    | No known vulnerability patterns; follows OpenZeppelin standards     |
| **Testability** | Business logic in pure functions; contracts use components          |
| **Coverage**    | Tests achieve 90% line coverage; edge cases fuzzed                  |
| **Simplicity**  | Minimal contract complexity; no over-engineering                    |
| **Consistency** | Follows patterns in existing codebase; uses established conventions |

### Behavioral Expectations

1. **Verify before coding**: Always read existing code before modifying.
2. **Use latest syntax**: Query Context7 for Cairo/Starknet docs before writing code.
3. **Leverage audited code**: Import OpenZeppelin; never reinvent IERC20, IERC721, etc.
4. **Run checks**: Execute `scarb fmt --workspace` and `snforge test` before declaring work complete.
5. **Track coverage**: Coverage must not decrease after changes.

## Technology Stack

- **Cairo**: 2.16.1 | **Starknet**: 2.16.1 | **snforge**: v0.58.1 | **OpenZeppelin**: v3.0.0

## Build Commands

```bash
scarb build                                              # Build workspace
snforge test <module>                                    # Run tests for a module (e.g. token, leaderboard)
snforge test <module> --coverage                         # Coverage for a module
snforge test <module> --fuzzer-runs 256                  # Run with custom fuzzer iterations
scarb fmt --workspace                                    # Format code
scarb fmt --check --workspace                            # What CI runs — see note
```

**Formatting**: CI runs `scarb fmt --check --workspace`. Plain `scarb fmt` does
NOT format workspace members the same way, so a tree that looks clean locally
can still fail lint — it has caught two PRs on the same file. Always pass
`--workspace`.

**Important**: Tests are run by module filter, not by package. Each group package contains multiple modules. Use `snforge test <module_name>` to run tests for a specific module (e.g., `snforge test token`, `snforge test leaderboard`).

## Project Structure

The workspace is organized into **group packages**, each containing multiple modules:

```
packages/
├── embeddable_game_standard/    # Core game standard components
│   ├── src/
│   │   ├── token/               # THE minigame token standard (self-bound ERC721, absorbed minter + game fee)
│   │   ├── minigame/            # IMinigame surface + settings/objectives extensions
│   │   └── metagame/            # High-level game coordination & context
│   └── Scarb.toml
├── metagame/                    # Metagame extension components
│   ├── src/
│   │   ├── leaderboard/         # Tournament scoring and ranking
│   │   ├── registration/        # Player registration tracking
│   │   ├── entry_requirement/   # Entry gating (token ownership, allowlists, validators)
│   │   ├── entry_fee/           # ERC20 entry fees with share distribution
│   │   ├── prize/               # Prize management (ERC20/ERC721 rewards)
│   │   └── ticket_booth/        # Payment-enabled game access (tickets & golden passes)
│   └── Scarb.toml
├── economy/                     # Game economy components
│   ├── src/
│   │   └── tokenomics/          # Ekubo TWAMM buyback and stream token distribution
│   └── Scarb.toml
├── utilities/                   # Shared utility libraries
│   ├── src/
│   │   ├── math/                # Fixed-point math (32.32 bit) based on Cubit
│   │   ├── distribution/        # Share computation (Linear, Exponential, Uniform, Custom)
│   │   └── utils/               # Encoding, JSON generation, metadata rendering
│   └── Scarb.toml
├── interfaces/                  # Centralized interface/struct definitions
├── presets/                     # Ready-to-deploy contracts
├── testing/                     # Shared test constants and addresses
└── test_common/                 # Shared mock contracts and examples
```

Each module has its own `AGENTS.md` with detailed documentation inside its `src/` directory.

## Architecture Overview

One token generation. The token IS the game: `MinigameTokenComponent` is
embedded in the game contract, so both live at one address.

```
Metagame ──→ Game contract (IS the ERC721 token)
  │                 ├── Settings (optional)
  │                 └── Objectives (optional)
  └── Context (optional)
```

**Game Lifecycle**: Setup → Mint → Play → `refresh_metadata()` (ERC-4906)

There is no registry, no `game_address` resolution, and no mutable token
state — so nothing to sync and no `update_game()`. The game contract is the
authority on game-over and objective completion, gating its own entrypoints
with the component's internal `assert_owner_and_playable`. Consumers identify a
token by SRC5 (`IMINIGAME_TOKEN_ID`), and a game declares its fee terms and
payee on the token itself (`IMINIGAME_TOKEN_GAME_FEE_ID`).

`MetagameComponent` is self-bound the same way: no stored addresses, no ABI
(`IMetagame`/`IMETAGAME_ID` do not exist). The embedding contract IS the
metagame; each game's token is resolved from `game_address` per mint, and a
metagame that provides context embeds `ContextComponent` on its own address.
Registration reduces to one address equality — `game.token_address() == game`.

### The retired generation

A registry-backed generation preceded this one: a separate multi-game ERC721
(`token_legacy`), a `registry` for game discovery and fee terms, a
`MinigameComponent` that registered games into it, and `IMetagameCallback` for
`update_game()` score/game-over callbacks. All of it was removed after the last
deployment using it was retired.

Deployed contracts from that generation still exist on-chain and still register
their interface ids. **To build against them, pin `v2.0.0` or earlier** — that
tag is the last release containing the registry generation. Indexers must also
branch their token-id decoder by contract generation: the layouts differ.

## Key Patterns

- `#[starknet::component]` for reusable architecture
- SRC5 interface discovery (`supports_interface`)
- `#[substorage(v0)]` for storage isolation
- Dispatcher pattern for cross-contract calls
- Interface IDs as constants (e.g., `IMINIGAME_ID`) — computed via `src5_rs parse` (see `packages/interfaces/src/AGENTS.md` for the full procedure; the tool requires a stripped-down file without `<TState>` generics or `self` params)

## CI Configuration

The `validate-config` job in CI automatically verifies that the module count matches `codecov.yml`. If they diverge, CI will fail with an actionable error message.

### Adding a New Package or Workspace Dependency

When adding a new group package or changing a workspace-level dependency in the root `Scarb.toml`, update the `packages` path filter in both CI workflows so the change triggers builds and tests. In `pr-ci.yml`, also add the package to the `compute-matrix` dependency graph so transitive consumers are tested.

### Adding a New Module

When adding a new module to a group package, update **both** files:

1. **`.github/workflows/main-ci.yml`** and **`.github/workflows/pr-ci.yml`** - Add the module to both matrices:

   ```yaml
   matrix:
     include:
       - package: game_components_GROUP_PACKAGE
         module: NEW_MODULE
         runner: ubuntu-latest
         fuzzer_runs: 256
   ```

   For memory-intensive modules (like `minigame`), assign a larger runner (e.g., `ubuntu-latest-4` or `ubuntu-latest-8`).

2. **`codecov.yml`** - Update the build count:
   ```yaml
   notify:
     after_n_builds: 16 # ← Must equal total module count in matrix
   ```

### Current Matrix (16 modules)

| Group Package | Module | Runner | Fuzzer Runs |
|---------------|--------|--------|-------------|
| `embeddable_game_standard` | `minigame` | `ubuntu-latest-8` | 32 |
| `embeddable_game_standard` | `metagame` | `ubuntu-latest-8` | 32 |
| `embeddable_game_standard` | `token` | `ubuntu-latest-8` | 32 |
| `metagame` | `leaderboard` | `ubuntu-latest-4` | 256 |
| `metagame` | `registration` | `ubuntu-latest-4` | 256 |
| `metagame` | `entry_requirement` | `ubuntu-latest-4` | 256 |
| `metagame` | `entry_fee` | `ubuntu-latest-4` | 256 |
| `metagame` | `prize` | `ubuntu-latest-4` | 256 |
| `metagame` | `ticket_booth` | `ubuntu-latest-4` | 256 |
| `metagame` | `merkledrop` | `ubuntu-latest-4` | 256 |
| `economy` | `tokenomics` | `ubuntu-latest-4` | 256 |
| `utilities` | `math` | `ubuntu-latest-4` | 256 |
| `utilities` | `distribution` | `ubuntu-latest-4` | 256 |
| `utilities` | `utils` | `ubuntu-latest-4` | 256 |
| `utilities` | `renderer` | `ubuntu-latest-4` | 256 |
| `presets` | `presets` | `ubuntu-latest-4` | 256 |
