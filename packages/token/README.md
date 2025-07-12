# Token Components Optimized

> **Revolutionary Configurable Direct Components Architecture**
> 
> Solves the Starknet 4MB contract size limit with compile-time optimization and runtime sophistication.

## 🎯 **Problem Solved**

Traditional token examples exceeded Starknet's 4MB limit:
- SimpleTokenContract: 7.6MB
- AdvancedTokenContract: 7.8MB
- FullFeaturedTokenContract: 9.0MB

This architecture provides **compile-time optimization** with **runtime sophistication**.

## 🏗️ **Architecture Overview**

### 1. **Configuration Layer** (`src/config.cairo`)
Compile-time feature flags that eliminate unused code:
```cairo
pub const MINTER_ENABLED: bool = true;
pub const MULTI_GAME_ENABLED: bool = false;
pub const OBJECTIVES_ENABLED: bool = true;
pub const CONTEXT_ENABLED: bool = false;
pub const SOULBOUND_ENABLED: bool = false;
pub const RENDERER_ENABLED: bool = false;
```

### 2. **Core Layer** (`src/core/`)
Single sophisticated `CoreTokenComponent` that preserves ALL logic from original TokenComponent:
- Complex game address validation
- Dynamic interface checking with `supports_interface` calls
- Multi-game metadata lookups vs single-game validation
- Settings/objectives validation when components available
- Conditional feature execution based on availability

### 3. **Features Layer** (`src/features/`)
Six independent components:
- **Minter** - Minter tracking and registry
- **MultiGame** - Multi-game support and metadata
- **Objectives** - Token objectives management
- **Context** - Game context handling
- **Soulbound** - Soulbound token functionality
- **Renderer** - Custom renderer support

### 4. **Integration Layer** (`src/integration/`)
Helper traits, patterns, and comprehensive examples.

## 🚀 **Key Innovation**

Compile-time optimization with runtime sophistication:
```cairo
// Compile-time optimization
let minted_by = if config::MINTER_ENABLED {
    // Runtime sophistication - only compiled if enabled
    if src5_component.supports_interface(IMINIGAME_TOKEN_MINTER_ID) {
        let minter_component = get_dep_component!(ref self, Minter);
        minter_component.on_mint_with_minter(caller)
    } else {
        0
    }
} else {
    0
};
```

## 📦 **Usage**

### Basic Token (Minimal Size)
```cairo
// In your config.cairo
pub const MINTER_ENABLED: bool = false;
pub const MULTI_GAME_ENABLED: bool = false;
pub const OBJECTIVES_ENABLED: bool = false;
pub const CONTEXT_ENABLED: bool = false;
pub const SOULBOUND_ENABLED: bool = false;
pub const RENDERER_ENABLED: bool = false;

// In your contract
#[starknet::contract]
mod MyToken {
    use game_components_token_optimized::core::CoreTokenComponent;
    use game_components_token_optimized::core::traits::*;
    
    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
    
    #[abi(embed_v0)]
    impl CoreTokenImpl = CoreTokenComponent::CoreTokenImpl<ContractState>;
    
    impl CoreTokenInternalImpl = CoreTokenComponent::InternalImpl<ContractState>;
    
    // Use NoOp implementations for disabled features
    impl MinterImpl = NoOpMinter<ContractState>;
    impl MultiGameImpl = NoOpMultiGame<ContractState>;
    impl ObjectivesImpl = NoOpObjectives<ContractState>;
    impl ContextImpl = NoOpContext<ContractState>;
    impl SoulboundImpl = NoOpSoulbound<ContractState>;
    impl RendererImpl = NoOpRenderer<ContractState>;
}
```

### Advanced Token (Select Features)
```cairo
// In your config.cairo
pub const MINTER_ENABLED: bool = true;
pub const MULTI_GAME_ENABLED: bool = true;
pub const OBJECTIVES_ENABLED: bool = true;
pub const CONTEXT_ENABLED: bool = false;
pub const SOULBOUND_ENABLED: bool = false;
pub const RENDERER_ENABLED: bool = false;

// In your contract
#[starknet::contract]
mod MyAdvancedToken {
    use game_components_token_optimized::core::CoreTokenComponent;
    use game_components_token_optimized::features::{
        MinterComponent, MultiGameComponent, ObjectivesComponent
    };
    
    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
    component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    
    // Enable selected features
    impl MinterOptionalImpl = MinterComponent::MinterOptionalImpl<ContractState>;
    impl MultiGameOptionalImpl = MultiGameComponent::MultiGameOptionalImpl<ContractState>;
    impl ObjectivesOptionalImpl = ObjectivesComponent::ObjectivesOptionalImpl<ContractState>;
    
    // Disable unused features
    impl ContextImpl = NoOpContext<ContractState>;
    impl SoulboundImpl = NoOpSoulbound<ContractState>;
    impl RendererImpl = NoOpRenderer<ContractState>;
}
```

## 🔧 **Integration Patterns**

### Helper Macros
```cairo
use game_components_token_optimized::integration::macros::*;

// Automatically configure based on enabled components
configure_token_features!(ContractState);
```

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

## 🎨 **Examples**

See `src/examples/` for comprehensive examples:
- `minimal_token.cairo` - Smallest possible token
- `gaming_token.cairo` - Game-optimized token
- `full_featured_token.cairo` - All features enabled
- `custom_integration.cairo` - Custom trait implementations

## 🏆 **Benefits**

1. **Compile-time Optimization**: Unused features are completely eliminated
2. **Runtime Sophistication**: Enabled features retain full complexity
3. **Developer Choice**: Pick exactly what you need
4. **Zero Dependencies**: Disabled features add zero overhead
5. **Gradual Adoption**: Enable features as needed
6. **Full Compatibility**: Works with existing game components

## 📚 **API Reference**

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
- `IMultiGameComponent` - Multi-game support
- `IObjectivesComponent` - Objectives management
- `IContextComponent` - Context handling
- `ISoulboundComponent` - Soulbound functionality
- `IRendererComponent` - Custom rendering

## 🔗 **Dependencies**

```toml
[dependencies]
starknet = "2.8.2"
game_components_minigame = { path = "../minigame" }
game_components_metagame = { path = "../metagame" }
game_components_utils = { path = "../utils" }

[dependencies.openzeppelin]
git = "https://github.com/OpenZeppelin/cairo-contracts.git"
tag = "v0.18.0"
```

## 🤝 **Contributing**

1. Features should be completely independent
2. Use the `OptionalTrait` pattern for core integration
3. Provide both enabled and NoOp implementations
4. Include comprehensive examples
5. Update configuration constants as needed

---

**Built with ❤️ for the Starknet gaming ecosystem** 