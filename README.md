# Game Components Library

<!-- Version badges - keep in sync with Scarb.toml -->

[![Scarb](https://img.shields.io/badge/Scarb-2.15.1-blue)](https://github.com/software-mansion/scarb)
[![Starknet Foundry](https://img.shields.io/badge/snforge-0.55.0-purple)](https://foundry-rs.github.io/starknet-foundry/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Docs](https://img.shields.io/badge/Docs-Embeddable%20Game%20Standard-blue)](https://docs.provable.games/embeddable-game-standard)
[![codecov](https://codecov.io/gh/Provable-Games/game-components/branch/next/graph/badge.svg?token=YNYQOJ76VV)](https://codecov.io/gh/Provable-Games/game-components)

A modular Cairo smart contract library for building on-chain games on Starknet. Provides reusable components for managing game state, player tokens, and tournament/event systems with comprehensive testing and deployment tools.

## 🎯 **Overview**

Game Components is designed to solve the complexity of building on-chain games by providing three core architectural components that work seamlessly together:

- **🏆 Metagame**: High-level game management and tournament/event coordination
- **🎮 Minigame**: Individual game logic and mechanics implementation
- **🃏 MinigameToken**: ERC721-based NFTs representing playable game instances

## 🏗️ **Architecture**

### Component Relationships

```
Metagame
  ├── minigame_token_address ──→ MinigameToken (ERC721)
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

### Game Lifecycle

1. **Setup**: Deploy contracts with extension addresses configured
2. **Mint**: Create tokens with game configuration and metadata
3. **Play**: Validate `is_playable()` and update game state through minigame logic
4. **Sync**: Call `update_game()` to synchronize token state with game results
5. **Complete**: Game ends when `game_over()` returns true or all objectives achieved

## 🚀 **Quick Start**

### Prerequisites

<!-- Keep versions in sync with Scarb.toml -->

- **Scarb**: 2.15.1
- **Starknet Foundry**: 0.55.0

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd game-components

# Build the entire workspace
scarb build

# Run tests with coverage
cd packages/test_starknet && snforge test --coverage
```

### Basic Usage

```cairo
// Deploy a simple game token
use game_components_token::core::CoreTokenComponent;
use game_components_minigame::interface::{IMinigame, IMinigameTokenData};

#[starknet::contract]
mod MyGameToken {
    use super::CoreTokenComponent;

    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);

    #[abi(embed_v0)]
    impl CoreTokenImpl = CoreTokenComponent::CoreTokenImpl<ContractState>;
}
```

## 📦 **Packages**

### Core Components

#### 🏆 **Metagame** (`packages/metagame/`)

High-level game management providing:

- Token delegation and minting coordination
- Optional tournament/event context management
- Game registration and validation
- Cross-game player tracking

**Key Interfaces:**

```cairo
trait IMetagame<TContractState> {
    fn context_address(self: @TContractState) -> ContractAddress;
    fn default_token_address(self: @TContractState) -> ContractAddress;
}
```

#### 🎮 **Minigame** (`packages/minigame/`)

Individual game logic implementation requiring:

- Implementation of `IMinigameTokenData` trait with `score()` and `game_over()` methods
- Support for optional settings and objectives extensions
- Integration with token contracts for NFT lifecycle management

**Required Implementation:**

```cairo
trait IMinigameTokenData<TState> {
    fn score(self: @TState, token_id: u64) -> u32;
    fn game_over(self: @TState, token_id: u64) -> bool;
}
```

#### 🃏 **MinigameToken** (`packages/token/`)

ERC721-based NFT representing playable game instances with:

- **Optimized Architecture**: Compile-time feature flags eliminate unused code
- **Modular Extensions**: Minter, renderer, soulbound, multi-game, objectives, context
- **Lifecycle Management**: Start/end times, playability validation
- **Game State Tracking**: Score, objectives, completion status

### Additional Packages

#### 🛠️ **utils** (`packages/utils/`)

Shared utilities providing:

- JSON encoding/decoding helpers
- Renderer trait implementations
- Common data structures and patterns

## 🔧 **Development Workflow**

### Build Commands

```bash
# Build entire workspace
scarb build

# Build specific packages
cd packages/test_starknet && scarb build

# Format code
scarb fmt -w
```

### Testing Commands

```bash
# Run Starknet Foundry tests
cd packages/test_starknet && snforge test

# Run with coverage (required 90%+)
snforge test --coverage
cairo-coverage

# Run specific test
snforge test test_mint_basic
```

## 🎨 **Extension System**

Game Components uses interface-based extensions for modularity:

### Available Extensions

- **Settings**: Game configuration (difficulty, modes, custom parameters)
- **Objectives**: Achievements and goals tracking with completion rewards
- **Context**: Tournament/event metadata and cross-game coordination
- **Minter**: Custom minting logic and access control
- **Renderer**: Dynamic UI/metadata generation for tokens
- **Soulbound**: Non-transferable tokens for achievements
- **Multi-game**: Support multiple games in one token collection

### Implementation Pattern

```cairo
// Check for extension availability
if src5_component.supports_interface(IMINIGAME_SETTINGS_ID) {
    let settings = IMinigameSettingsDispatcher { contract_address: settings_address };
    // Use extension functionality
}
```

## 📱 **Deployment & Scripts**

### Deployment Scripts

```bash
# Deploy mock contracts for testing
./scripts/deploy_mocks.sh

# Deploy optimized token contract
./scripts/deploy_optimized_token.sh

# Create game settings
./scripts/create_settings.sh

# Create objectives
./scripts/create_objectives.sh

# Mint game tokens
./scripts/mint_games.sh
```

## 🌟 **Key Features**

### For Game Developers

- **Rapid Development**: Pre-built components eliminate boilerplate
- **Modular Design**: Pick only the extensions you need
- **Gas Optimized**: Designed to be gas efficient and stay under Starknet limits

### For Players

- **True Ownership**: ERC721 tokens represent actual game instances
- **Interoperability**: Games can interact through shared interfaces
- **Tournament Support**: Participate in cross-game events and competitions

### For Tournament Organizers

- **Flexible Configuration**: Support for various tournament formats
- **Metagame Integration**: Coordinate multiple games in single events
- **Context Management**: Rich metadata for tournaments and competitions
- **Player Tracking**: Cross-game player statistics and achievements

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ for the Starknet gaming ecosystem by [Provable Games](https://provable.games)**
