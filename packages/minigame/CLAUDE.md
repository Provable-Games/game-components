# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Cairo smart contract library for gaming components on StarkNet. The codebase is organized as a monorepo with multiple packages that work together to provide modular game functionality.

## Essential Commands

```bash
# Build the project
scarb build

# Run all tests
scarb test

# Run a specific test
scarb test test_function_name

# Format code
scarb fmt

# Check compilation without building
scarb check

# Clean build artifacts
scarb clean
```

## Architecture

The project follows a component-based architecture for StarkNet smart contracts:

1. **Core Components**:
   - `MinigameComponent`: Main game logic component implementing IMinigame interface
   - Integrates with token, settings, and objectives extensions
   - Uses SRC5 for interface introspection

2. **Package Dependencies**:
   - `minigame` depends on → `metagame`, `token`, `utils`
   - `token` provides token management and data structures
   - `utils` contains encoding, JSON, and rendering utilities
   - `metagame` handles game context and metadata

3. **Key Interfaces**:
   - `IMinigame`: Core minigame functionality (register_player, deregister_player, get_game_data)
   - `IMinigameTokenData`: Token-related data (score, game_over status)
   - `IMinigameDetails`: Game detail information
   - Extension interfaces in `extensions/` for settings and objectives

4. **Testing Structure**:
   - Separate test packages for StarkNet (`test_starknet`) and Dojo (`test_dojo`)
   - Mock contracts demonstrate initialization patterns
   - Tests show deployment flow: deploy contract → initialize minigame → initialize extensions

## Development Guidelines

1. **Import Patterns**: Use relative imports within packages and workspace imports for cross-package dependencies:
   ```cairo
   use minigame::interface::{IMinigame, IMinigameDispatcher};
   use metagame::context::interface::{IContext, IContextDispatcher};
   ```

2. **Component Usage**: When implementing new game logic, extend `MinigameComponent`:
   ```cairo
   component!(path: MinigameComponent, storage: minigame, event: MinigameEvent);
   ```

3. **Testing**: New features should include tests in the appropriate test package. Follow existing patterns in `test_starknet/src/tests/`

4. **Cairo Version**: This project uses Cairo 2.10.1. Ensure compatibility when adding new features.