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
4. **Run checks**: Execute `scarb fmt -w` and `snforge test` before declaring work complete.
5. **Track coverage**: Coverage must not decrease after changes.

## Technology Stack

- **Cairo**: 2.15.1 | **Starknet**: 2.15.1 | **snforge**: v0.55.0 | **OpenZeppelin**: v3.0.0

## Build Commands

```bash
scarb build                                              # Build workspace
snforge test <module>                                    # Run tests for a module (e.g. token, leaderboard)
snforge test <module> --coverage                         # Coverage for a module
snforge test <module> --fuzzer-runs 256                  # Run with custom fuzzer iterations
scarb fmt -w                                             # Format code
```

**Important**: Tests are run by module filter, not by package. Each group package contains multiple modules. Use `snforge test <module_name>` to run tests for a specific module (e.g., `snforge test token`, `snforge test leaderboard`).

## Project Structure

The workspace is organized into **group packages**, each containing multiple modules:

```
packages/
├── embeddable_game_standard/    # Core game standard components
│   ├── src/
│   │   ├── token/               # ERC721 game token with compile-time feature flags
│   │   ├── minigame/            # Individual game logic foundation
│   │   ├── metagame/            # High-level game coordination & context
│   │   └── registry/            # Game registration and discovery
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

```
Metagame ──→ MinigameToken (ERC721) ──→ Minigame
  │  ▲               │                      │
  │  │               └── Registry            ├── Settings (optional)
  │  │                                       └── Objectives (optional)
  │  └── IMetagameCallback (on_game_action, on_game_over, on_objective_complete)
  └── Context (optional)
```

**Game Lifecycle**: Setup → Mint → Play → Sync (`update_game()`) → Complete (`game_over()`)

When `update_game()` is called, the token checks if the minter implements `IMetagameCallback` (via SRC5) and dispatches score/game_over/objective callbacks automatically.

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

   For memory-intensive modules (like `token` or `minigame`), assign a larger runner (e.g., `ubuntu-latest-4` or `ubuntu-latest-8`) and consider partitioning with `--partition INDEX/TOTAL`.

2. **`codecov.yml`** - Update the build count:
   ```yaml
   notify:
     after_n_builds: 33 # ← Must equal total matrix entry count (including partitions)
   ```

### Current Matrix (33 jobs across 16 modules)

All modules >60s are partitioned via `snforge --partition` for parallelism.

| Group Package | Module | Runner | Fuzzer Runs | Partitions |
|---------------|--------|--------|-------------|------------|
| `embeddable_game_standard` | `token` | `ubuntu-latest-8` | 64 | 4 |
| `embeddable_game_standard` | `minigame` | `ubuntu-latest-4` | 64 | 2 |
| `embeddable_game_standard` | `metagame` | `ubuntu-latest-4` | 64 | 2 |
| `embeddable_game_standard` | `registry` | `ubuntu-latest-4` | 64 | 2 |
| `metagame` | `leaderboard` | `ubuntu-latest-4` | 256 | 2 |
| `metagame` | `registration` | `ubuntu-latest-4` | 256 | 2 |
| `metagame` | `entry_requirement` | `ubuntu-latest-4` | 256 | 2 |
| `metagame` | `entry_fee` | `ubuntu-latest-4` | 256 | 2 |
| `metagame` | `prize` | `ubuntu-latest-4` | 256 | 2 |
| `metagame` | `ticket_booth` | `ubuntu-latest-4` | 256 | 2 |
| `economy` | `tokenomics` | `ubuntu-latest-4` | 256 | 2 |
| `utilities` | `math` | `ubuntu-latest-4` | 256 | 2 |
| `utilities` | `distribution` | `ubuntu-latest-4` | 256 | 1 |
| `utilities` | `utils` | `ubuntu-latest-4` | 256 | 2 |
| `utilities` | `renderer` | `ubuntu-latest-4` | 256 | 2 |
| `presets` | `presets` | `ubuntu-latest-4` | 256 | 2 |
