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

| Package | Purpose |
|---------|---------|
| **interfaces** | Centralized interface/struct definitions for all components |
| **metagame** | High-level game coordination, token delegation, context management |
| **minigame** | Individual game logic foundation (MUST implement `IMinigameTokenData`) |
| **token** | ERC721 with compile-time feature flags (<4MB optimization) |
| **leaderboard** | Tournament scoring and ranking |
| **registry** | Game registration and discovery |
| **tokenomics** | Ekubo TWAMM buyback and stream token distribution |
| **presets** | Ready-to-deploy contracts (LeaderboardPreset, AutonomousBuyback, StreamToken) |
| **utils** | Pure utilities: encoding, JSON, rendering |
| **test_common** | Shared mocks and example contracts (**do not modify existing mocks**) |
| **testing** | Test constants and addresses |

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
