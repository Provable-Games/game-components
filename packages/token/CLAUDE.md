# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build Commands
```bash
# Build all packages in workspace
scarb build

# Build specific package
scarb build -p game_components_token

# Clean build artifacts
scarb clean
```

### Test Commands
```bash
# Run all Starknet tests
cd packages/test_starknet && snforge test

# Run specific test
cd packages/test_starknet && snforge test test_name

# Run tests with verbose output
cd packages/test_starknet && snforge test -v
```

### Development Commands
```bash
# Format code
scarb fmt

# Check formatting without modifying
scarb fmt --check

# Check dependencies
scarb check
```

## Architecture Overview

This is a Cairo smart contract library for gaming tokens on StarkNet, part of a monorepo with multiple packages:

- **token/** (current package) - Game-enabled ERC721 tokens with extensions
- **metagame/** - High-level game management
- **minigame/** - Individual game instances
- **utils/** - Shared utilities
- **test_starknet/** - Testing framework integration

### Token Package Architecture

The token package implements a component-based architecture with:

1. **Core Token Component** (`src/token.cairo`):
   - Extends OpenZeppelin's ERC721
   - Manages token lifecycle (start/end times)
   - Tracks game state and completion
   - Emits events for game updates

2. **Extension System** (`src/extensions/`):
   - **MultiGame**: Support for multiple games per token
   - **Objectives**: Track game objective completion
   - **Settings**: Different game configurations
   - **Minter**: Track token creator
   - **Soulbound**: Non-transferable tokens

3. **Interface Detection**:
   - Uses SRC5 (Cairo's EIP-165) for runtime capability detection
   - Extensions self-register their interfaces
   - Check support before using extension features

### Key Development Patterns

1. **Component Usage**:
   ```cairo
   component!(path: TokenComponent, storage: token, event: TokenEvent);
   ```

2. **Extension Detection**:
   ```cairo
   let supports_feature = src5_component.supports_interface(INTERFACE_ID);
   ```

3. **Token Creation Flow**:
   - Call `mint()` with game address and optional parameters
   - Token metadata includes lifecycle, settings, and objectives
   - Games update token state via `update_game()`

### Important Entry Points

- `IMinigameToken::mint()` - Create new game tokens
- `IMinigameToken::update_game()` - Sync token with game state
- `IMinigameToken::token_metadata()` - Get comprehensive token info
- `IMinigameToken::is_playable()` - Check if token can be played

### Testing Approach

Tests use Starknet Foundry (snforge) with mock contracts. Test files are in `packages/test_starknet/` and follow patterns like:
- Deploy mock contracts
- Test component interactions
- Verify event emissions
- Check interface support