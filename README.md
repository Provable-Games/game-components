# Game Components Library

[![Cairo](https://img.shields.io/badge/Cairo-2.10.1-blue)](https://github.com/starkware-libs/cairo)
[![StarkNet](https://img.shields.io/badge/StarkNet-2.10.1-orange)](https://starknet.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Coverage](https://img.shields.io/badge/Coverage-90%25+-brightgreen)](./packages/test_starknet/coverage/)

A modular Cairo smart contract library for building on-chain games on StarkNet. Provides reusable components for managing game state, player tokens, and tournament/event systems with comprehensive testing and deployment tools.

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

- **Cairo**: 2.10.1 (exact version required)
- **StarkNet**: 2.10.1
- **StarkNet Foundry**: 0.45.0
- **Scarb**: Latest compatible version

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

**Revolutionary Size Optimization:**
- Traditional contracts: 7-9MB (exceeded StarkNet 4MB limit)
- Optimized architecture: <4MB with full feature sophistication
- Compile-time configuration eliminates unused features while preserving runtime complexity

### Additional Packages

#### 🧪 **test_starknet** (`packages/test_starknet/`)
StarkNet-native testing environment:
- **Purpose**: Fast, isolated testing with comprehensive coverage
- **Coverage**: 90%+ requirement enforced by cairo-coverage
- **Test Types**: Unit, integration, fuzz, lifecycle, and event testing
- **Mock Infrastructure**: Comprehensive mocks for all interfaces

```bash
cd packages/test_starknet
snforge test --coverage
cairo-coverage  # Generate detailed coverage reports
```

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
# Run StarkNet Foundry tests
cd packages/test_starknet && snforge test

# Run with coverage (required 90%+)
snforge test --coverage
cairo-coverage

# Run specific test
snforge test test_mint_basic
```

### ⚠️ **Critical Testing Requirements**

This project enforces **90% minimum test coverage** using cairo-coverage. Any code changes without adequate tests will fail CI validation.

**Test Coverage Protocol:**
1. Write comprehensive unit tests for all new functions
2. Include edge cases, boundary conditions, and failure scenarios  
3. Add integration tests for cross-contract interactions
4. Create fuzz tests for user inputs and mathematical operations
5. Run `cairo-coverage` locally before pushing

**Test Infrastructure Warnings:**
- **NEVER** modify existing test infrastructure without understanding all dependencies
- Run `grep -r "filename" tests/` before modifying any mock contracts
- Create NEW mocks instead of modifying existing ones
- Establish passing test baseline before making changes

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

### Configuration Files

- `Scarb.toml`: Workspace configuration and dependencies
- `CLAUDE.md`: Development guidelines and AI assistant instructions
- `argent_account.json`: Account configuration for deployments
- `deployments/`: Deployment artifacts and contract addresses

## 🌟 **Key Features**

### For Game Developers
- **Rapid Development**: Pre-built components eliminate boilerplate
- **Modular Design**: Pick only the extensions you need
- **Size Optimized**: Compile-time optimization stays under StarkNet limits
- **Battle Tested**: 90%+ test coverage with comprehensive edge case handling

### For Players
- **True Ownership**: ERC721 tokens represent actual game instances
- **Interoperability**: Games can interact through shared interfaces
- **Tournament Support**: Participate in cross-game events and competitions
- **Achievement System**: Objectives and progress tracking across games

### For Tournament Organizers
- **Metagame Integration**: Coordinate multiple games in single events
- **Context Management**: Rich metadata for tournaments and competitions
- **Player Tracking**: Cross-game player statistics and achievements
- **Flexible Configuration**: Support for various tournament formats

## 🤝 **Contributing**

### Development Guidelines

1. **Security First**: Thorough edge case analysis prevents fund losses
2. **Gas Optimization**: Efficient transactions without sacrificing readability
3. **Comprehensive Testing**: 90%+ coverage requirement with no exceptions
4. **Clear Documentation**: Enable team collaboration and maintainability

### Code Standards

- Follow existing Cairo patterns and component architecture
- Use SRC5 interface discovery for capability detection
- Implement proper storage isolation via `#[substorage(v0)]`
- Maintain dispatcher pattern for cross-contract calls
- Extensive use of Option types for optional parameters

### Pull Request Process

1. Ensure `scarb build && scarb test` passes with zero warnings
2. Verify 90%+ test coverage with `cairo-coverage`
3. Run `scarb fmt -w` to format code
4. Update documentation for any new features
5. Test deployment scripts if contract changes are made

## 📚 **Examples**

See individual package READMEs for detailed examples:
- [`packages/token/README.md`](packages/token/README.md) - Token optimization patterns
- [`packages/test_starknet/README.md`](packages/test_starknet/README.md) - Testing approaches

### Simple Game Implementation

```cairo
#[starknet::contract]
mod TicTacToe {
    use game_components_minigame::interface::{IMinigameTokenData};
    
    impl GameLogic of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: u64) -> u32 {
            // Return current game score
            self.game_scores.read(token_id)
        }
        
        fn game_over(self: @ContractState, token_id: u64) -> bool {
            // Check if game is complete
            self.check_win_condition(token_id) || self.is_board_full(token_id)
        }
    }
}
```

## 🔗 **Resources**

- **Cairo Documentation**: [cairo-lang.org](https://cairo-lang.org/)
- **StarkNet Developer Docs**: [starknet.io/developers](https://starknet.io/developers)
- **OpenZeppelin Cairo**: [github.com/OpenZeppelin/cairo-contracts](https://github.com/OpenZeppelin/cairo-contracts)

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ for the StarkNet gaming ecosystem by [Provable Games](https://provable.games)**