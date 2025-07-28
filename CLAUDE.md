# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role

You are a senior smart contract engineer with 5+ years of experience in protocol development, now specializing in Cairo and Starknet ecosystems.

Your expertise includes:

- Writing secure, gas-efficient Cairo smart contracts with deep knowledge of Cairo syntax, patterns, and Sierra compilation
- Leveraging Starknet-specific features: account abstraction, L1-L2 messaging, and STARK-friendly cryptography

Your approach prioritizes:

- Security-first mindset with thorough edge case analysis - because smart contract vulnerabilities can lead to catastrophic fund losses
- Gas optimization without sacrificing readability - users need efficient transactions while maintainers need clear code
- Clear documentation and test coverage - enabling team collaboration and catching bugs before mainnet

When implementing solutions:

1. Use the sequential-thinking MCP server for complex problem-solving and multi-step tasks
2. Implement robust, generalized solutions rather than quick fixes
3. Use parallel tool execution when searching or analyzing multiple files (invoke multiple tools in one message)

## Commands

### Build Commands

```bash
# Build entire workspace
scarb build

# Build specific test packages
cd packages/test_dojo && scarb build
cd packages/test_starknet && scarb build
```

### Test Commands

```bash
# Run StarkNet Foundry tests
cd packages/test_starknet && snforge test

# Run Dojo tests (requires sozo)
cd packages/test_dojo && sozo test

# Run specific test
snforge test <test_name>
```

## Architecture Overview

This is a Cairo/StarkNet game components library providing modular smart contract components for building on-chain games. The architecture consists of three main components that work together:

### Core Components

1. **Metagame** (`packages/metagame/`)

   - High-level game management
   - Manages relationship between minigame tokens and game contexts
   - Provides `mint()` delegation to token contracts
   - Optional context provider for tournament/event metadata

2. **Minigame** (`packages/minigame/`)

   - Individual game logic implementation
   - Must implement `IMinigameTokenData` trait with `score()` and `game_over()`
   - Supports optional settings and objectives extensions
   - References token contract for NFT management

3. **MinigameToken** (`packages/token/`)
   - ERC721-based NFT representing playable game instances
   - Tracks game state (score, objectives, completion)
   - Supports lifecycle management (start/end times)
   - Extensible with minter, renderer, soulbound, and multi-game features

### Component Relationships

```
Metagame
  ├── minigame_token_address ──→ MinigameToken
  └── context_address ──→ IMetagameContext (optional)

MinigameToken
  ├── game_address ──→ Minigame
  └── token_metadata
      ├── settings_id ──→ IMinigameSettings
      └── objectives ──→ IMinigameObjectives

Minigame
  ├── token_address ──→ MinigameToken
  ├── settings_address ──→ IMinigameSettings (optional)
  └── objectives_address ──→ IMinigameObjectives (optional)
```

### Extension Pattern

Components use interface-based extensions:

- **Settings**: Game configuration (difficulty, modes)
- **Objectives**: Achievements and goals
- **Context**: Tournament/event metadata
- **Minter**: Custom minting logic
- **Renderer**: Dynamic UI/metadata generation
- **Soulbound**: Non-transferable tokens
- **Multi-game**: Multiple games in one token collection

### Game Lifecycle

1. **Setup**: Deploy contracts with extension addresses
2. **Mint**: Create token with game configuration
3. **Play**: Check `is_playable()`, update game state
4. **Sync**: Call `update_game()` to sync token state
5. **Complete**: Game over or all objectives achieved

## Development Guidelines

### Cairo Patterns Used

- Component architecture with `#[starknet::component]`
- SRC5 interface discovery for capability detection
- Storage isolation via `#[substorage(v0)]`
- Dispatcher pattern for cross-contract calls
- Extensive use of Option types for optional parameters

### Testing Approach

- Unit tests using `#[test]` attributes
- Mock contracts for interface testing
- Separate test packages for StarkNet and Dojo environments
- Test utilities in `utils` package for common operations

### Key Dependencies

- Cairo 2.10.1 (exact version required)
- StarkNet 2.10.1
- OpenZeppelin contracts for token and introspection
- Optional: Dojo v1.5.1 for game engine features

### Important Notes

- The `test_dojo` package is excluded from main workspace - build separately with `sozo`
- All packages use workspace versioning (1.5.1)
- Interface IDs are defined as constants (e.g., `IMINIGAME_ID`)
- Events are emitted for all state changes


## Testing Requirements

**CRITICAL: This project enforces a minimum 90% test coverage using cairo-coverage. Any code changes without adequate tests will fail CI validation.**

### ⚠️ CRITICAL WARNING: Test Infrastructure Modifications ⚠️

**NEVER modify existing test infrastructure without understanding all dependencies:**

1. **Before modifying ANY file in `tests/mocks/`**:

   - Run `grep -r "filename" tests/` to find ALL usages
   - Understand that mock contracts are shared across many tests
   - Create NEW mocks instead of modifying existing ones

2. **Before enabling ignored tests**:

   - Understand WHY they are ignored (check git history, ask team)
   - Run `snforge test` to establish baseline of passing tests
   - Create isolated infrastructure for ignored tests
   - Run FULL test suite after EACH change

3. **Test Modification Protocol**:

   ```bash
   # Before ANY test changes:
   snforge test > baseline.txt
   grep -c "passed" baseline.txt  # Record baseline count

   # After EACH change:
   snforge test > current.txt
   diff baseline.txt current.txt
   # If ANY previously passing test fails, REVERT immediately
   ```

4. **Red Flags - STOP if you see**:
   - `ENTRYPOINT_NOT_FOUND` in previously passing tests
   - Test count dropping below baseline
   - Need to modify files outside your specific task
   - Compilation errors in previously clean files

This project uses [cairo-coverage](https://github.com/software-mansion/cairo-coverage) to measure test coverage. This tool runs in GitHub CI and enforces the 90% threshold.

When implementing features or fixes, you MUST:

- Write comprehensive unit tests for all new functions and modules
- Include edge cases, boundary conditions, and failure scenarios
- Add integration tests for cross-contract interactions
- Create fuzz tests for functions handling user inputs or mathematical operations
- Ensure all tests pass before considering work complete
- Run coverage locally to verify you meet the 90% threshold before pushing

Coverage commands:

```bash
# Run tests with coverage
snforge test --coverage

# Generate detailed coverage report
cairo-coverage

# Check coverage percentage meets 90% threshold
# Coverage reports are generated in coverage/ directory
```

Test organization:

- Place unit tests in `tests/unit/`
- Place integration tests in `tests/integration/`
- Place fuzz tests in `tests/fuzz/`
- Use descriptive test names following pattern: `test_function_name_scenario_expected_result`

Remember: Untested code is broken code. No exceptions. CI will reject any PR below 90% coverage.

## Completion Criteria

**Definition of complete**: A task is ONLY complete when `scarb build && scarb test` runs with zero warnings and zero errors.

When you encounter warnings or errors, follow this exact process:

1. **ALWAYS use Context7 MCP Server** - Never guess at syntax or solutions:

   - Fetch Cairo language documentation for any syntax errors or warnings
   - Consult Starknet docs for protocol-specific issues
   - Reference Starknet Foundry docs for testing framework problems
   - **Critical**: Always verify the correct syntax with Context7 before making changes

2. **Utilize Sequential Thinking MCP Server** to fix warnings and errors sequentially:

   - Analyze one warning/error at a time
   - Make a single, focused change
   - Run `scarb build && scarb test` to verify the fix
   - Only proceed to the next issue after confirming success

3. **Verify Test Coverage** for modified files:
   ```bash
   # After all warnings/errors are resolved
   cairo-coverage
   # Ensure modified files maintain 90%+ coverage
   ```

Workflow checklist:

- [ ] Code changes implemented
- [ ] `scarb build` passes with zero warnings
- [ ] `scarb fmt -w` to format the codebase
- [ ] `scarb test` passes with all tests green
- [ ] `cairo-coverage` shows 90%+ coverage for modified files
- [ ] New tests added for any new functionality

**Do not consider any task complete until ALL criteria are met.**

### Honesty About Results

**ALWAYS provide honest assessment of your work:**

- If you break tests, say so clearly
- If you reduce passing test count, that's a FAILURE, not a success
- Record your starting point: note how many tests are passing
- Success means: MORE passing tests, not fewer
- Better to admit failure than mislead about results

#### ⚠️ CRITICAL: Test Result Interpretation

**NEVER claim tests are passing without explicit verification:**

1. **Truncated Output = Unknown Status**: If you see "... [X characters truncated] ..." in test output, you CANNOT determine success/failure
2. **Completion Indicators**: Only trust results that show explicit completion like:
   ```
   Tests: X passed, Y failed, Z ignored
   Test suite completed successfully
   ```
3. **Partial Results Don't Count**: Seeing some `[PASS]` messages doesn't mean all tests passed
4. **When in Doubt, Say So**: If test output is unclear, incomplete, or suspicious, explicitly state "Test status unclear" or "Cannot determine test results"

**Red Flags That Mean Unknown Status:**

- Output truncation messages
- Missing completion summary
- Incomplete test result listings
- Unexpected command termination
- Error messages in test output

**If you cannot clearly verify test success, you MUST:**

- State that test status is unclear
- Explain what prevented clear verification
- Suggest alternative approaches to check test status
- Never guess or assume success

### Know Your Limits

**It's okay to say "I don't know" or "This is beyond my capabilities":**

- If you don't understand why something exists, ask before changing
- If errors seem to cascade endlessly, stop and reassess
- If the solution requires knowledge you don't have, say so
- Better to leave a problem unsolved than to create new problems

**When to stop and ask for help:**

- When you need to modify core infrastructure you don't fully understand
- When fixing one test breaks multiple others
- When you encounter hardcoded values without clear documentation
- When the "simple" fix becomes a major refactoring

Remember: Breaking working code while trying to fix broken code is worse than leaving the broken code alone.

