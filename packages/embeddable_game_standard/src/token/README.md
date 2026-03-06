# Token Components

> **Configurable Direct Components Architecture**
>
> Solves the Starknet 4MB contract size limit using the Optional Trait / NoOp Trait pattern.

## Problem Solved

Traditional token contracts exceeded Starknet's 4MB limit by including all features. This architecture lets you include only the components you need.

## Architecture Overview

### 1. **Core Layer** (`src/token_component.cairo`)
Single `CoreTokenComponent` that preserves ALL logic from original TokenComponent:
- Complex game address validation
- Dynamic interface checking with `supports_interface` calls
- Multi-game metadata lookups vs single-game validation
- Settings/objectives validation when components available
- Conditional feature execution based on availability

### 2. **Extensions Layer** (`src/extensions/`)
Six independent components:
- **Minter** - Minter tracking and registry
- **Objectives** - Token objectives management
- **Context** - Game context handling
- **Soulbound** - Soulbound token functionality
- **Renderer** - Custom renderer support
- **Settings** - Game settings management

### 3. **NoOp Traits** (`src/noop_traits.cairo`)
Zero-cost trait implementations for disabled features. Contracts choose which component impls to wire up (real vs NoOp) at the contract level:

```cairo
// Enable minter with real implementation
impl MinterOptionalImpl = MinterComponent::MinterOptionalImpl<ContractState>;

// Disable other features with zero-cost NoOps
impl ObjectivesOptionalImpl = NoOpObjectives<ContractState>;
impl SettingsOptionalImpl = NoOpSettings<ContractState>;
impl ContextOptionalImpl = NoOpContext<ContractState>;
impl SoulboundOptionalImpl = NoOpSoulbound<ContractState>;
impl RendererOptionalImpl = NoOpRenderer<ContractState>;
```

## Usage

### Basic Token (Minimal Size)
```cairo
#[starknet::contract]
mod MyToken {
    use game_components_embeddable_game_standard::token::token_component::CoreTokenComponent;
    use game_components_embeddable_game_standard::token::noop_traits::*;

    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);

    #[abi(embed_v0)]
    impl CoreTokenImpl = CoreTokenComponent::CoreTokenImpl<ContractState>;

    impl CoreTokenInternalImpl = CoreTokenComponent::InternalImpl<ContractState>;

    // Use NoOp implementations for disabled features
    impl MinterImpl = NoOpMinter<ContractState>;
    impl ObjectivesImpl = NoOpObjectives<ContractState>;
    impl ContextImpl = NoOpContext<ContractState>;
    impl SoulboundImpl = NoOpSoulbound<ContractState>;
    impl RendererImpl = NoOpRenderer<ContractState>;
    impl SettingsImpl = NoOpSettings<ContractState>;
}
```

### Advanced Token (Select Features)
```cairo
#[starknet::contract]
mod MyAdvancedToken {
    use game_components_embeddable_game_standard::token::token_component::CoreTokenComponent;
    use game_components_embeddable_game_standard::token::extensions::{
        MinterComponent, ObjectivesComponent
    };
    use game_components_embeddable_game_standard::token::noop_traits::*;

    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);

    // Enable selected features
    impl MinterOptionalImpl = MinterComponent::MinterOptionalImpl<ContractState>;
    impl ObjectivesOptionalImpl = ObjectivesComponent::ObjectivesOptionalImpl<ContractState>;

    // Disable unused features
    impl ContextImpl = NoOpContext<ContractState>;
    impl SoulboundImpl = NoOpSoulbound<ContractState>;
    impl RendererImpl = NoOpRenderer<ContractState>;
    impl SettingsImpl = NoOpSettings<ContractState>;
}
```

## Integration Patterns

### Custom Trait Implementations
```cairo
// Override specific behaviors
impl CustomMinter of OptionalMinter<ContractState> {
    fn on_mint_with_minter(ref self: ContractState, minter: ContractAddress) -> u64 {
        // Custom minter logic
        42
    }
}
```

## Examples

See `src/tests/examples/` for comprehensive examples:
- `minimal_optimized_example.cairo` - Smallest possible token
- `full_token_contract.cairo` - All features enabled
- `single_game_token_contract.cairo` - Single game mode

## Benefits

1. **Compile-time Optimization**: Unused features are completely eliminated via NoOp traits
2. **Runtime Sophistication**: Enabled features retain full complexity
3. **Developer Choice**: Pick exactly what you need
4. **Zero Dependencies**: Disabled features add zero overhead
5. **Gradual Adoption**: Enable features as needed
6. **Full Compatibility**: Works with existing game components

## API Reference

### Core Token Interface
```cairo
trait ICoreToken<TState> {
    fn mint(ref self: TState, to: ContractAddress, game_address: ContractAddress, /* ... */);
    fn burn(ref self: TState, token_id: u64);
    fn token_uri(self: @TState, token_id: u64) -> ByteArray;
    // ... standard ERC721 methods
}
```

### Feature Interfaces
Each feature component provides its own interface:
- `IMinterComponent` - Minter management
- `IObjectivesComponent` - Objectives management
- `IContextComponent` - Context handling
- `ISoulboundComponent` - Soulbound functionality
- `IRendererComponent` - Custom rendering

## Contributing

1. Features should be completely independent
2. Use the `OptionalTrait` pattern for core integration
3. Provide both enabled and NoOp implementations
4. Include comprehensive examples
