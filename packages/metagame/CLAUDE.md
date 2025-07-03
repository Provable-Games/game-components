# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Metagame Package Overview

The metagame package provides a high-level game management component for Starknet-based games. It acts as an orchestration layer between game contracts and the token system, managing game tokens with rich metadata and optional context data.

## Development Commands

### Building

```bash
# Build the metagame package
scarb build -p game_components_metagame

# Build with dependencies
scarb build
```

### Testing

```bash
# Run tests using Starknet Foundry (recommended)
cd ../../test_starknet && snforge test

# Run tests with Dojo integration
cd ../../test_dojo && sozo test
```

## Architecture

### Core Components

1. **IMetagame Interface** (`src/interface.cairo`):

   - `minigame_token_address()`: Returns the token contract address
   - `context_address()`: Returns optional context contract address
   - Interface ID: `0x0260d5160a283a03815f6c3799926c7bdbec5f22e759f992fb8faf172243ab20`

2. **MetagameComponent** (`src/metagame.cairo`):

   - Embeddable component for game contracts
   - Handles token minting with extensive metadata
   - Manages game registration and validation

3. **Context Extension** (`src/extensions/context/`):
   - Optional context system for attaching arbitrary metadata to tokens
   - `IMetagameContext` interface for context queries
   - Supports both embedded and external context storage

### Key Patterns

1. **Component-Based Design**: The metagame is implemented as a Cairo component that can be embedded into game contracts using `component!(path: metagame_component, storage: metagame, event: MetagameEvent)`.

2. **Metadata-Rich Token Minting**: The `_mint_with_details` function accepts comprehensive game metadata:

   - Player information
   - Game settings and objectives
   - Timing data (start/end)
   - Rendering configuration
   - Optional context data

3. **Game Registration**: Uses `assert_game_registered` to ensure only authorized games can mint tokens.

4. **Interface Discovery**: Implements SRC5 for runtime capability detection.

### Integration Points

- **Dependencies**:

  - `game_components_token`: For NFT functionality
  - `game_components_utils`: For utility functions
  - `openzeppelin_introspection`: For SRC5 support

- **Used By**: Game contracts that need standardized token management with metadata

### Important Implementation Notes

1. When implementing a game contract using this component:

   - Embed the component in your contract's storage
   - Initialize with token and optional context addresses
   - Register games before allowing token minting

2. Context data structure:

   - `GameContextDetails`: Contains name, description, ID, and key-value pairs
   - Context can be stored in the metagame contract or a separate context contract

3. The component provides internal functions prefixed with `_` that should be wrapped by the implementing contract with appropriate access controls.

## Role

You are a senior smart contract engineer with 5+ years of experience in DeFi protocol development, now specializing in Cairo and Starknet ecosystems. You work on the Beedle liquidity bootstrapping protocol team.

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
- [ ] `scarb test` passes with all tests green
- [ ] `cairo-coverage` shows 90%+ coverage for modified files
- [ ] New tests added for any new functionality

**Do not consider any task complete until ALL criteria are met.**
**Do not stop until all tasks are complete.**
