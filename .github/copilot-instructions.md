## Project Context

Game Components is a Cairo/StarkNet library providing modular smart contract components for building on-chain games. It offers a flexible architecture with three core components (Metagame, Minigame, and MinigameToken) that work together to enable NFT-based game instances with customizable settings, objectives, and lifecycle management.

## Technology Stack

We use Cairo for smart contract development, not Solidity.

We use Scarb as our build tool, not Foundry or Hardhat.

We use Starknet Foundry (snforge) for testing, not traditional Ethereum testing frameworks.

We use OpenZeppelin contracts for token standards and introspection.

Optional: Dojo v1.5.1 can be used for enhanced game engine features.

## Code Review Priorities

### Security First

Always prioritize security in smart contract code reviews. Look for:

- Reentrancy vulnerabilities
- Access control issues
- Integer overflow/underflow risks
- Unsafe external calls
- Missing validation checks

Smart contract vulnerabilities can lead to catastrophic fund losses, so every edge case must be analyzed.

### Gas Optimization

Review code for gas efficiency without sacrificing readability. Users need efficient transactions while maintainers need clear code.

### Test Coverage

This project enforces a minimum 90% test coverage using cairo-coverage. Any code changes without adequate tests should be flagged in reviews.

## Cairo-Specific Guidelines

When reviewing Cairo code:

- Verify correct usage of component architecture with `#[starknet::component]`
- Check SRC5 interface discovery implementation for capability detection
- Ensure proper storage isolation using `#[substorage(v0)]`
- Validate dispatcher pattern usage for cross-contract calls
- Confirm extensive use of Option types for optional parameters
- Verify interface IDs are defined as constants (e.g., `IMINIGAME_ID`)

## Testing Standards

All code must include:

- Comprehensive unit tests for all new functions
- Edge cases and boundary conditions
- Integration tests for cross-contract interactions
- Fuzz tests for user input handling

Test files should be placed in:

- Unit tests: `tests/unit/`
- Integration tests: `tests/integration/`
- Fuzz tests: `tests/fuzz/`

Test names must follow pattern: `test_function_name_scenario_expected_result`

## Code Style Requirements

### Documentation

Every function must include:

- Clear explanation of what it does and why
- Parameter descriptions with types and constraints
- Return value documentation
- Example usage when appropriate

Use descriptive variable names (e.g., `liquidity_unlock_timestamp` not `t`).

### Contract Structure

Contracts must follow this organization:

1. Interfaces
2. Events
3. Storage
4. Constructor
5. External functions
6. Internal functions

### Error Handling

All error messages must be implemented as descriptive constants.

## Critical Infrastructure Rules

### Never Modify Without Understanding

The following files are critical shared infrastructure - modifications can break many tests:

- Mock contracts in `packages/*/src/tests/mocks/` directories
- Test utilities in `packages/utils/` directory
- Any shared test infrastructure across packages

Before modifying any test infrastructure:

1. Run `grep -r "filename" tests/` to find all usages
2. Understand dependencies and create new mocks instead of modifying existing ones

### Known Issues to Consider

- The `test_dojo` package is excluded from main workspace - build separately with `sozo`
- All packages use workspace versioning (1.5.1)
- Events must be emitted for all state changes

## Integration Considerations

### Game Architecture

Review for proper implementation of:

- `IMinigameTokenData` trait with `score()` and `game_over()` functions
- Optional extensions (settings, objectives, context, minter, renderer)
- Game lifecycle: Setup → Mint → Play → Sync → Complete
- Token metadata structure and state tracking

### Starknet Specifics

Review for proper usage of:

- Account abstraction features
- L1-L2 messaging patterns
- STARK-friendly cryptography

## Build and Test Commands

The following commands must pass without warnings or errors:

- `scarb build` - Build entire workspace
- `cd packages/test_starknet && snforge test` - Run StarkNet tests
- `cd packages/test_dojo && sozo test` - Run Dojo tests (requires sozo)
- `snforge test --coverage` - Run tests with coverage
- `cairo-coverage` - Generate coverage report
- `scarb fmt -w` - Format code

## Review Checklist

When reviewing PRs, verify:

- [ ] No security vulnerabilities introduced
- [ ] Test coverage maintained above 90%
- [ ] All new functions have comprehensive documentation
- [ ] Code follows established patterns in the codebase
- [ ] No modifications to critical shared infrastructure
- [ ] Build and tests pass without warnings
- [ ] Gas optimization considered
- [ ] Integration compatibility maintained

## Philosophy

Remember: In a modular game components library, flexibility and extensibility are key. Each component should be usable independently while also working seamlessly together. Always consider how changes affect both standalone usage and integrated scenarios.

Consistency trumps personal preference. If existing components use pattern X, don't introduce pattern Y without strong justification.

## Component Dependencies

When reviewing changes, ensure proper relationships are maintained:

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
