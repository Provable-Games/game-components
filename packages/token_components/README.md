# Token Components - True Component Composition

This package demonstrates **true component composition** for implementing selective token features. Instead of using callbacks or pre-built variants, you compose individual feature components together to create exactly the token functionality you need.

## 🏗️ Architecture Overview

### Individual Feature Components

| Component | Responsibility | Interface |
|-----------|---------------|-----------|
| `CoreTokenComponent` | ERC721 + Basic Token Functionality | `IMinigameToken` |
| `MinterComponent` | Minter Tracking | `IMinterToken` |
| `MultiGameComponent` | Multi-Game Support | `IMultiGameToken` |
| `ObjectivesComponent` | Objectives Tracking | `IObjectivesToken` |

### Composition Philosophy

**Mix and match** the exact components you need:

```cairo
// Want basic token + minter tracking + objectives?
component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
component!(path: MinterComponent, storage: minter, event: MinterEvent);
component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);

// Only expose the interfaces for features you've included
#[abi(embed_v0)]
impl TokenImpl = CoreTokenComponent::MinigameTokenImpl<ContractState>;
#[abi(embed_v0)]  
impl MinterImpl = MinterComponent::MinterImpl<ContractState>;
#[abi(embed_v0)]
impl ObjectivesImpl = ObjectivesComponent::ObjectivesImpl<ContractState>;
```

## 🚀 Quick Start Examples

### Basic Token (Core Features Only)

```cairo
#[starknet::contract]
pub mod BasicToken {
    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
    
    #[abi(embed_v0)]
    impl TokenImpl = CoreTokenComponent::MinigameTokenImpl<ContractState>;
}
```

### Composed Token (Multiple Features)

```cairo
#[starknet::contract]
pub mod ComposedToken {
    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    
    #[abi(embed_v0)]
    impl TokenImpl = CoreTokenComponent::MinigameTokenImpl<ContractState>;
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;
    #[abi(embed_v0)]
    impl ObjectivesImpl = ObjectivesComponent::ObjectivesImpl<ContractState>;
    
    // Orchestrate between components in custom methods
    #[external(v0)]
    fn mint_with_features(ref self: ContractState, ...) -> u64 {
        let token_id = self.core_token.mint(...);
        let minter_id = self.minter.register_minter(get_caller_address());
        self.minter.set_token_minter(token_id, minter_id);
        self.objectives.setup_objectives(token_id, ...);
        token_id
    }
}
```

## 📊 Comparison: Three Approaches

### 1. Callback Approach (Original)

```cairo
// One component with optional callbacks
component!(path: TokenComponent, storage: token, event: TokenEvent);

impl MinterCallback of TokenMinterCallback<ContractState> {
    fn on_mint_with_minter(ref self: ContractState, minter_address: ContractAddress) -> u64 {
        self.minter.add_minter(minter_address)
    }
}
```

#### ✅ Benefits: Maximum flexibility, single component maintenance  
#### ❌ Drawbacks: Callback complexity, all features compiled

### 2. Component Variants (Initial Attempt)

```cairo
// Pre-built component variants
component!(path: MinterTokenComponent, storage: token, event: TokenEvent); // Basic + Minter
component!(path: FullFeaturedTokenComponent, storage: token, event: TokenEvent); // Everything
```

#### ✅ Benefits: Simple selection, no callbacks  
#### ❌ Drawbacks: Limited combinations, maintenance overhead

### 3. True Composition (This Approach)

```cairo
// Individual components composed together
component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
component!(path: MinterComponent, storage: minter, event: MinterEvent);
component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);
```

#### ✅ Benefits: Full composability, single responsibility, compile-time optimization  
#### ❌ Drawbacks: Orchestration complexity, multiple components

## 🎼 Orchestration Pattern

The key insight is **orchestration at the contract level**:

```cairo
fn mint_with_features(ref self: ContractState, ...) -> u64 {
    // 1. Core functionality
    let token_id = self.core_token.mint(...);
    
    // 2. Optional features (only if components are included)
    if self.has_minter_component() {
        let minter_id = self.minter.register_minter(get_caller_address());
        self.minter.set_token_minter(token_id, minter_id);
    }
    
    if self.has_objectives_component() {
        self.objectives.setup_objectives(token_id, objectives);
    }
    
    token_id
}
```

## 🎯 Composition Patterns

### Minimal Token
```cairo
component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
```
**Interfaces**: `IMinigameToken`

### Analytics Token
```cairo
component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
component!(path: MinterComponent, storage: minter, event: MinterEvent);
```
**Interfaces**: `IMinigameToken` + `IMinterToken`

### Gaming Platform Token
```cairo
component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);
```
**Interfaces**: `IMinigameToken` + `IMultiGameToken` + `IObjectivesToken`

### Full-Featured Token
```cairo
component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
component!(path: MinterComponent, storage: minter, event: MinterEvent);
component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);
```
**Interfaces**: All interfaces

## 🎯 When to Use Each Approach

### Use True Composition When:
- **Exact feature control** - Want specific combinations
- **Performance critical** - Only compile what you use
- **Clear boundaries** - Each feature is independent
- **Interface segregation** - Only expose needed functionality

### Use Callback Approach When:
- **Maximum flexibility** - Need arbitrary feature combinations
- **Rapid prototyping** - Experimenting with features
- **Runtime configuration** - Dynamic feature toggling
- **Development convenience** - Single component simplicity

### Use Component Variants When:
- **Predefined use cases** - Standard feature sets
- **Simplicity over flexibility** - Don't need custom combinations
- **Clear upgrade paths** - Well-defined feature progression

## 📁 Package Structure

```
token_components/
├── src/
│   ├── components/                    # Individual feature components  
│   │   ├── core_token.cairo          # Basic ERC721 + minigame token
│   │   ├── minter.cairo             # Pure minter tracking
│   │   ├── multi_game.cairo         # Pure multi-game support
│   │   └── objectives.cairo         # Pure objectives tracking
│   ├── examples/                     # Composition examples
│   │   ├── simple_contract.cairo    # CoreTokenComponent only
│   │   ├── composable_contract.cairo # Multiple components
│   │   └── full_contract.cairo      # All components
│   ├── interface.cairo              # Feature interfaces
│   └── lib.cairo                    # Package entry point
└── README.md                        # This file
```

## 🔄 Benefits of True Composition

### ✅ **Full Composability**
- Any combination of features possible
- Add/remove features by including/excluding components
- No predefined limitations

### ✅ **Single Responsibility**
- Each component focuses on one feature
- Clear component boundaries
- Easy to test and maintain

### ✅ **Compile-time Optimization**
- Only included features are compiled
- Smaller bytecode for minimal configurations
- No runtime overhead for unused features

### ✅ **Interface Segregation**
- Only expose interfaces for included features
- No interface pollution
- Clear API surface

### ✅ **Independent Evolution**
- Components can be updated independently
- New features don't affect existing components
- Easy to deprecate unused features

## 🤔 Design Philosophy

This true composition approach prioritizes:

1. **Composability** over simplicity
2. **Single responsibility** over monolithic design
3. **Compile-time optimization** over runtime flexibility
4. **Interface clarity** over feature completeness
5. **Explicit selection** over implicit configuration

Perfect for production systems where you know your feature requirements and want optimal performance and clarity.

## 📝 License

Same as the main game-components package. 