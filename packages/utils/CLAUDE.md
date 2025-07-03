# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Cairo/Starknet monorepo for game components, specifically the `utils` package which provides encoding, JSON handling, and rendering utilities for blockchain games on Starknet.

## Common Development Commands

### Building
```bash
scarb build
```

### Testing
```bash
# Run all tests
snforge test

# Run a specific test
snforge test test_settings_json

# Run tests with output
snforge test -- --nocapture
```

### Workspace Commands
The monorepo uses Scarb workspaces. From the root directory:
```bash
# Build all packages (except test_dojo)
scarb build

# Build only utils package
scarb build -p game_components_utils
```

## Architecture

This package is part of a larger game components library with the following structure:

- **Dependencies**: This utils package depends on:
  - `game_components_metagame` - Game metadata and context management
  - `game_components_minigame` - Mini-game logic with objectives and settings
  - External libraries: `alexandria_encoding`, `graffiti`

- **Core Modules**:
  - `encoding.cairo` - Base64 encoding and byte manipulation utilities
  - `json.cairo` - JSON creation utilities for game settings, objectives, and contexts
  - `renderer.cairo` - SVG rendering for game NFT metadata

- **Key Patterns**:
  - All JSON creation functions use the `graffiti` library's `JsonImpl`
  - The renderer creates on-chain SVG images for game NFTs with base64 encoding
  - Byte manipulation uses custom trait implementations for efficient size calculations

## Testing Approach

Tests are written using Starknet Foundry (snforge) and located inline with the source files. The project uses two testing approaches:
- Pure Starknet tests (in `test_starknet` package)
- Dojo framework tests (in `test_dojo` package, excluded by default)

## Important Notes

- This is NOT a JavaScript/TypeScript project - it's Cairo code for Starknet blockchain
- Version requirements: Scarb 2.10.1, Cairo 2.10.1, Starknet Foundry 0.45.0
- The workspace excludes `test_dojo` by default as it requires separate building with `sozo`