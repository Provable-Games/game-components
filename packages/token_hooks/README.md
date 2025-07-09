# Game Components Token Package

This package provides a comprehensive token system for game components with support for multiple extensions.

## Overview

The token package includes:

- **Core Token Component**: Basic token functionality with game integration
- **Extensions**: Modular extensions for different token features
- **Mixin Component**: Combines all extensions into a single convenient interface (similar to OpenZeppelin's approach)

## Extensions

### Available Extensions

1. **Multi-Game** (`IMinigameTokenMultiGame`): Support for multiple games within a single token contract
2. **Objectives** (`IMinigameTokenObjectives`): Token-level objectives and completion tracking
3. **Settings** (`IMinigameTokenSettings`): Game settings management
4. **Minter** (`IMINIGAME_TOKEN_MINTER_ID`): Minting controls and permissions
5. **Soulbound** (`IMINIGAME_TOKEN_SOULBOUND_ID`): Non-transferable token support

## Token Mixin Component

The `TokenMixinComponent` provides a single interface that combines all token extensions, similar to OpenZeppelin's `ERC721ABI`. This makes it easy to create contracts with full token functionality without having to individually implement each extension.

### Features

- **Combined Interface**: Single `IMinigameTokenABI` interface that includes all extension methods
- **Flexible Initialization**: Choose which extensions to enable during deployment
- **OpenZeppelin Integration**: Built on top of OpenZeppelin's ERC721 component
- **Modular Design**: Can still use individual components if you don't need all features

## Usage

### Using the Full Mixin (Recommended)

```cairo
#[starknet::contract]
pub mod MyTokenContract {
    use game_components_token::mixin::TokenMixinComponent;
    use game_components_token::token::TokenComponent;
    use game_components_token::extensions::multi_game::multi_game::MultiGameComponent;
    use game_components_token::extensions::objectives::objectives::TokenObjectivesComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;

    // Component declarations
    component!(path: TokenMixinComponent, storage: token_mixin, event: TokenMixinEvent);
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
    component!(path: TokenObjectivesComponent, storage: token_objectives, event: TokenObjectivesEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Single mixin implementation provides all functionality
    #[abi(embed_v0)]
    impl TokenMixinImpl = TokenMixinComponent::TokenMixinImpl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: Option<ContractAddress>,
    ) {
        // Initialize with all extensions enabled
        self.token_mixin.initializer(
            name,
            symbol, 
            base_uri,
            game_address,
            true, // supports_multi_game
            true, // supports_objectives
            true, // supports_settings
            true, // supports_minter
            true, // supports_soulbound
        );
    }
}
```

### Using Individual Components

If you only need specific functionality, you can use individual components:

```cairo
#[starknet::contract]
pub mod SimpleTokenContract {
    use game_components_token::token::TokenComponent;
    use game_components_token::extensions::objectives::objectives::TokenObjectivesComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;

    // Component declarations
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: TokenObjectivesComponent, storage: token_objectives, event: TokenObjectivesEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Individual implementations
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    #[abi(embed_v0)]
    impl TokenObjectivesImpl = TokenObjectivesComponent::TokenObjectivesImpl<ContractState>;

    #[constructor]
    fn constructor(ref self: ContractState, name: ByteArray, symbol: ByteArray, game_address: ContractAddress) {
        // Initialize only what you need
        self.erc721.initializer(name, symbol, "");
        self.token.initializer(Option::Some(game_address));
        self.token_objectives.initializer();
    }
}
```

## API Reference

### Core Token Methods

- `token_metadata(token_id: u64) -> TokenMetadata`: Get token metadata
- `is_playable(token_id: u64) -> bool`: Check if token is currently playable
- `settings_id(token_id: u64) -> u32`: Get the settings ID for a token
- `player_name(token_id: u64) -> ByteArray`: Get the player name for a token
- `mint(...)`: Mint a new token with optional extensions
- `update_game(token_id: u64)`: Update game state for a token

### Multi-Game Extension Methods

- `game_count() -> u64`: Total number of registered games
- `register_game(...)`: Register a new game
- `game_metadata(game_id: u64) -> GameMetadata`: Get game information
- `is_game_registered(contract_address: ContractAddress) -> bool`: Check if game is registered

### Objectives Extension Methods

- `objectives_count(token_id: u64) -> u32`: Number of objectives for a token
- `objectives(token_id: u64) -> Array<TokenObjective>`: Get all objectives
- `all_objectives_completed(token_id: u64) -> bool`: Check completion status
- `create_objective(...)`: Create a new objective

### Settings Extension Methods

- `create_settings(...)`: Create game settings configuration

## Examples

See `src/examples/full_token_example.cairo` for complete examples of both mixin usage and individual component usage.

## Dependencies

- **OpenZeppelin Contracts for Cairo**: ERC721 implementation and SRC5 introspection
- **Game Components Minigame**: Minigame interfaces and structures
- **Game Components Metagame**: Context and metadata structures

## Contributing

When adding new extensions:

1. Create the extension component in `src/extensions/your_extension/`
2. Add the interface with appropriate interface ID constant
3. Update the mixin component to include the new extension
4. Add initialization logic and interface registration
5. Update this README with the new functionality

## Interface IDs

All extensions use unique interface IDs for SRC5 introspection:

- `IMINIGAME_TOKEN_ID`: Core token interface
- `IMINIGAME_TOKEN_MULTIGAME_ID`: Multi-game extension
- `IMINIGAME_TOKEN_OBJECTIVES_ID`: Objectives extension  
- `IMINIGAME_TOKEN_SETTINGS_ID`: Settings extension
- `IMINIGAME_TOKEN_MINTER_ID`: Minter extension
- `IMINIGAME_TOKEN_SOULBOUND_ID`: Soulbound extension 