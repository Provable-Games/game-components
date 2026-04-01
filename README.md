# Game Components Library

<!-- Version badges - keep in sync with Scarb.toml -->

[![Scarb](https://img.shields.io/badge/Scarb-2.16.1-blue)](https://github.com/software-mansion/scarb)
[![Starknet Foundry](https://img.shields.io/badge/snforge-0.58.1-purple)](https://foundry-rs.github.io/starknet-foundry/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Docs](https://img.shields.io/badge/Docs-Embeddable%20Game%20Standard-blue)](https://docs.provable.games/embeddable-game-standard)
[![codecov](https://codecov.io/gh/Provable-Games/game-components/branch/next/graph/badge.svg?token=YNYQOJ76VV)](https://codecov.io/gh/Provable-Games/game-components)

A modular Cairo smart contract library for building on-chain games on Starknet. Provides reusable components for managing game state, player tokens, and tournament/event systems with comprehensive testing and deployment tools.

## Architecture

### Component Relationships

```
Metagame
  ├── minigame_token_address ──→ MinigameToken (ERC721)
  ├── context_address ──→ IMetagameContext (optional)
  └── IMetagameCallback ◀── update_game() dispatches callbacks

MinigameToken
  ├── game_address ──→ Minigame
  ├── registry_address ──→ Registry (multi-game mode)
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
4. **Sync**: Call `update_game()` to synchronize token state with game results. If the minter implements `IMetagameCallback`, callbacks are dispatched automatically (`on_game_action`, `on_game_over`, `on_objective_complete`)
5. **Complete**: Game ends when `game_over()` returns true or all objectives achieved

## Packages

### Embeddable Game Standard

Core components for onboarding games onto Starknet.

| Module | Description | Docs |
|--------|-------------|------|
| [**token**](packages/embeddable_game_standard/src/token/) | ERC721 NFT representing playable game instances with compile-time feature flags (<4MB optimization) | [README](packages/embeddable_game_standard/src/token/README.md) |
| [**minigame**](packages/embeddable_game_standard/src/minigame/) | Individual game logic foundation requiring `IMinigameTokenData` implementation | [README](packages/embeddable_game_standard/src/minigame/README.md) |
| [**metagame**](packages/embeddable_game_standard/src/metagame/) | High-level game management, token delegation, and context coordination | [README](packages/embeddable_game_standard/src/metagame/README.md) |
| [**registry**](packages/embeddable_game_standard/src/registry/) | Game registration, discovery, and metadata management | [README](packages/embeddable_game_standard/src/registry/README.md) |

### Metagame

Components for applications that coordinate and interact with games.

| Module | Description | Docs |
|--------|-------------|------|
| [**leaderboard**](packages/metagame/src/leaderboard/) | Tournament scoring, ranking, and multi-tournament support | [README](packages/metagame/src/leaderboard/README.md) |
| [**registration**](packages/metagame/src/registration/) | Player registration tracking for tournaments, quests, and other contexts | [README](packages/metagame/src/registration/README.md) |
| [**entry_requirement**](packages/metagame/src/entry_requirement/) | Entry gating via token ownership, allowlists, or external validators | [README](packages/metagame/src/entry_requirement/README.md) |
| [**entry_fee**](packages/metagame/src/entry_fee/) | Entry fee management with ERC20 deposits and share distribution | [README](packages/metagame/src/entry_fee/README.md) |
| [**prize**](packages/metagame/src/prize/) | Prize management for ERC20/ERC721 rewards with claim tracking | [README](packages/metagame/src/prize/README.md) |
| [**ticket_booth**](packages/metagame/src/ticket_booth/) | Payment-enabled game access with tickets and golden passes | — |

### Game Economy

| Module | Description | Docs |
|--------|-------------|------|
| [**tokenomics**](packages/economy/src/tokenomics/) | Ekubo TWAMM buyback and stream token distribution | [README](packages/economy/src/tokenomics/README.md) |

### Utilities

| Module | Description | Docs |
|--------|-------------|------|
| [**math**](packages/utilities/src/math/) | Fixed-point math library (32.32 bit) based on Cubit | [README](packages/utilities/src/math/README.md) |
| [**distribution**](packages/utilities/src/distribution/) | Share computation with Linear, Exponential, Uniform, and Custom distributions | [README](packages/utilities/src/distribution/README.md) |
| [**utils**](packages/utilities/src/utils/) | Encoding, JSON generation, and token metadata rendering | [README](packages/utilities/src/utils/README.md) |
| [**renderer**](packages/utilities/src/renderer/) | SVG/HTML rendering and font embedding for token metadata | — |

### Presets

| Package | Description | Docs |
|---------|-------------|------|
| [**presets**](packages/presets/) | Ready-to-deploy contracts (LeaderboardPreset, AutonomousBuyback, StreamToken) | [README](packages/presets/src/README.md) |

### Cross-Cutting

| Package | Description | Docs |
|---------|-------------|------|
| [**interfaces**](packages/interfaces/) | Centralized interface and struct definitions shared across all components | [README](packages/interfaces/src/README.md) |

### Testing Infrastructure

| Package | Description |
|---------|-------------|
| **testing** | Shared test constants and addresses |
| **test_common** | Shared mock contracts and example implementations |

## Quick Start

### Prerequisites

<!-- Keep versions in sync with Scarb.toml -->

- **Scarb**: 2.16.1
- **Starknet Foundry**: 0.58.1

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd game-components

# Build the entire workspace
scarb build

# Run tests for a specific module
snforge test --filter token

# Run tests with coverage
snforge test --filter token --coverage
```

### Basic Usage

```cairo
// Deploy a simple game token
use game_components_embeddable_game_standard::token::core::CoreTokenComponent;
use game_components_interfaces::minigame::{IMinigame, IMinigameTokenData};

#[starknet::contract]
mod MyGameToken {
    use super::CoreTokenComponent;

    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);

    #[abi(embed_v0)]
    impl CoreTokenImpl = CoreTokenComponent::CoreTokenImpl<ContractState>;
}
```

## Extension System

Game Components uses interface-based extensions for modularity:

| Extension | Purpose |
|-----------|---------|
| **Settings** | Game configuration (difficulty, modes, custom parameters) |
| **Objectives** | Achievements and goals tracking with completion rewards |
| **Context** | Tournament/event metadata and cross-game coordination |
| **Callback** | Automatic metagame notifications on score/game_over/objective events |
| **Minter** | Custom minting logic and access control |
| **Renderer** | Dynamic UI/metadata generation for tokens |
| **Soulbound** | Non-transferable tokens for achievements |
| **Skills** | Per-token skills address overrides with batch operations |
| **Multi-game** | Support multiple games in one token collection |

### Implementation Pattern

```cairo
// Check for extension availability
if src5_component.supports_interface(IMINIGAME_SETTINGS_ID) {
    let settings = IMinigameSettingsDispatcher { contract_address: settings_address };
    // Use extension functionality
}
```

## Development Workflow

### Build Commands

```bash
# Build entire workspace
scarb build

# Format code
scarb fmt -w
```

### Testing Commands

```bash
# Run all tests for a module
snforge test --filter token

# Run with coverage
snforge test --filter token --coverage

# Run a specific test by name
snforge test --filter test_mint_basic

# Run with custom fuzzer iterations
snforge test --filter token --fuzzer-runs 256
```

## Deployment Scripts

```bash
# Deploy mock contracts for testing
./scripts/deploy_mocks.sh

# Deploy optimized token contract
./scripts/deploy_optimized_token.sh

# Deploy StreamToken factory
./scripts/deploy_stream_token_factory.sh

# Create game settings
./scripts/create_settings.sh

# Create game objectives
./scripts/create_objectives.sh

# Create stream token
./scripts/create_stream_token.sh

# Mint game tokens
./scripts/mint_games.sh
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with love for the Starknet gaming ecosystem by [Provable Games](https://provable.games)**
