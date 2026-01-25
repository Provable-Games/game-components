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
scarb build                                    # Build workspace
cd packages/test_starknet && snforge test      # Run all tests
cd packages/test_starknet && snforge test --coverage  # Coverage
scarb fmt -w                                   # Format code
```

## Package Overview

Each package has its own `AGENTS.md` with detailed documentation.

| Package         | Purpose                                                                       |
| --------------- | ----------------------------------------------------------------------------- |
| **interfaces**  | Centralized interface/struct definitions for all components                   |
| **metagame**    | High-level game coordination, token delegation, context management            |
| **minigame**    | Individual game logic foundation (MUST implement `IMinigameTokenData`)        |
| **token**       | ERC721 with compile-time feature flags (<4MB optimization)                    |
| **leaderboard** | Tournament scoring and ranking                                                |
| **registry**    | Game registration and discovery                                               |
| **tokenomics**  | Ekubo TWAMM buyback and stream token distribution                             |
| **presets**     | Ready-to-deploy contracts (LeaderboardPreset, AutonomousBuyback, StreamToken) |
| **utils**       | Pure utilities: encoding, JSON, rendering                                     |
| **test_common** | Shared mocks and example contracts (**do not modify existing mocks**)         |
| **testing**     | Test constants and addresses                                                  |

## Architecture Overview

```
Metagame ──→ MinigameToken (ERC721) ──→ Minigame
                 │                         │
                 └── Registry              ├── Settings (optional)
                                           └── Objectives (optional)
```

**Game Lifecycle**: Setup → Mint → Play → Sync (`update_game()`) → Complete (`game_over()`)

## Key Patterns

- `#[starknet::component]` for reusable architecture
- SRC5 interface discovery (`supports_interface`)
- `#[substorage(v0)]` for storage isolation
- Dispatcher pattern for cross-contract calls
- Interface IDs as constants (e.g., `IMINIGAME_ID`)

## CI Configuration

The `validate-config` job in CI automatically verifies that the package count matches `codecov.yml`. If they diverge, CI will fail with an actionable error message.

### Adding a New Package

When adding a new package with tests, update **both** files:

1. **`.github/workflows/test.yml`** - Add the package to the matrix:

   ```yaml
   matrix:
     package:
       - game_components_metagame
       - game_components_minigame
       # ... existing packages ...
       - game_components_NEW_PACKAGE # ← Add here
   ```

   For memory-intensive packages (like `token` or `minigame`), use the `include`/`exclude` pattern to assign a larger runner (e.g., `ubuntu-latest-4` or `ubuntu-latest-16`).

2. **`codecov.yml`** - Update the build count:
   ```yaml
   notify:
     after_n_builds: 9 # ← Must equal total package count in matrix
   ```

### Current Matrix (8 packages)

| Package                       | Runner             |
| ----------------------------- | ------------------ |
| `game_components_metagame`    | `ubuntu-latest`    |
| `game_components_minigame`    | `ubuntu-latest-4`  |
| `game_components_registry`    | `ubuntu-latest`    |
| `game_components_token`       | `ubuntu-latest-32` |
| `game_components_tokenomics`  | `ubuntu-latest`    |
| `game_components_utils`       | `ubuntu-latest`    |
| `game_components_leaderboard` | `ubuntu-latest`    |
| `game_components_presets`     | `ubuntu-latest`    |
