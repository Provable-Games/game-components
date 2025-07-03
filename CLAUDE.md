# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Cairo/Starknet smart contract library for building modular blockchain-based games. The project uses Scarb as the build tool and provides reusable game components following a component-based architecture.

## Development Commands

### Building
```bash
# Build all packages (excluding test_dojo)
scarb build

# Build specific package
scarb build -p game_components_metagame
```

### Testing

The project supports two testing approaches:

**Starknet Foundry Tests** (recommended for most testing):
```bash
# Run all Starknet tests
cd packages/test_starknet && snforge test

# Run specific test
cd packages/test_starknet && snforge test test_name
```

**Dojo Tests** (when testing Dojo integration):
```bash
# Must be built separately due to Dojo dependencies
cd packages/test_dojo && sozo test
```

### Required Tool Versions
- scarb: 2.10.1
- starknet-foundry: 0.31.0
- cairo: 2.10.1

## Architecture

The project follows a workspace structure with modular game components:

```
packages/
├── metagame/      # High-level game management
├── minigame/      # Individual game instances
├── token/         # NFT-like token system with extensions
├── utils/         # Shared utilities (encoding, JSON, rendering)
├── test_starknet/ # Pure Starknet tests
└── test_dojo/     # Dojo framework tests
```

### Key Design Patterns

1. **Component-Based Architecture**: Each package provides independent, reusable smart contract components that can be composed to build games.

2. **Extension Pattern**: The token package uses an extension system for modular functionality:
   - `extension_minter`: Minting capabilities
   - `extension_multi_game`: Cross-game compatibility
   - `extension_objectives`: Achievement/objective tracking
   - `extension_renderer`: Visual representation
   - `extension_soulbound`: Non-transferable tokens

3. **Dual Testing Strategy**: 
   - Use `test_starknet` for fast, isolated unit tests
   - Use `test_dojo` when testing Dojo model integration

4. **Interface-First Design**: Heavy use of Cairo interfaces (traits) for modularity and testability.

### Component Dependencies

- `metagame` depends on: token system, context extensions, OpenZeppelin introspection
- `minigame` depends on: basic utilities, objectives system
- `token` depends on: utilities for rendering and encoding
- All test packages depend on their respective components under test

### Important Notes

- The `test_dojo` package is commented out in the workspace Scarb.toml and must be built separately with `sozo`
- When modifying contracts, ensure compatibility with both Starknet-native and Dojo storage patterns
- The project uses OpenZeppelin's introspection standard (SRC5) for component discovery