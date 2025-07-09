# TokenComponent Examples

This directory contains three focused examples demonstrating different approaches to using the TokenComponent with the callback pattern. Each example shows a different level of feature enablement.

## 📁 Example Files

### 🔹 [`simple_token_example.cairo`](./simple_token_example.cairo)
**Basic token with no optional features**

- **Features**: None (all default callbacks)
- **Dependencies**: TokenComponent + ERC721 + SRC5
- **Use case**: Simple game tokens, prototyping, minimal gas costs
- **Best for**: Single-game tokens that don't need tracking or special features

```cairo
// All features OFF
impl MinterCallback: DefaultTokenMinterCallback<ContractState>,
impl ContextCallback: DefaultTokenContextCallback<ContractState>,
impl SoulboundCallback: DefaultTokenSoulboundCallback<ContractState>,
// ... etc
```

### 🔸 [`advanced_token_example.cairo`](./advanced_token_example.cairo)  
**Selective feature enablement (minter tracking)**

- **Features**: ✅ Minter tracking, ❌ Others (mixed callbacks)
- **Dependencies**: TokenComponent + MinterComponent + ERC721 + SRC5
- **Use case**: Tokens that need analytics on who minted what
- **Best for**: Gaming platforms tracking user engagement

```cairo
// Minter ON, others OFF  
impl MinterCallback: ComponentTokenMinterCallback,                    // ✅ Local component integration
impl ContextCallback: DefaultTokenContextCallback<ContractState>,     // ❌ Default (OFF)
impl SoulboundCallback: DefaultTokenSoulboundCallback<ContractState>, // ❌ Default (OFF)
// ... etc
```

### 🔷 [`full_featured_token_example.cairo`](./full_featured_token_example.cairo)
**Multiple features enabled (multi-game platform)**

- **Features**: ✅ Minter + Multi-game + Objectives, ❌ Others  
- **Dependencies**: TokenComponent + MinterComponent + MultiGameComponent + TokenObjectivesComponent + ERC721 + SRC5
- **Use case**: Complex gaming platforms with cross-game mechanics
- **Best for**: Gaming ecosystems, achievement systems, analytics platforms

```cairo
// Multiple features ON
impl MinterCallback: ComponentTokenMinterCallback,    // ✅ Minter tracking
impl MultiGameCallback: ComponentTokenMultiGameCallback, // ✅ Multi-game support  
impl ObjectivesCallback: ComponentTokenObjectivesCallback, // ✅ Objectives/achievements
impl ContextCallback: DefaultTokenContextCallback<ContractState>, // ❌ Could be enabled
// ... etc
```

## 🎯 Which Example Should I Use?

### Start Simple → Add Features
1. **Begin with**: `simple_token_example.cairo`
2. **Add minter tracking**: Upgrade to `advanced_token_example.cairo` pattern
3. **Add multi-game + objectives**: Upgrade to `full_featured_token_example.cairo` pattern

### By Use Case

| Use Case | Example | Features Needed |
|----------|---------|-----------------|
| Basic game token | Simple | None |
| Analytics tracking | Advanced | Minter |
| Achievement system | Full Featured | Minter + Objectives |
| Multi-game platform | Full Featured | Minter + Multi-game + Objectives |
| Soulbound tokens | Custom | Add SoulboundComponent callback |

## 🔧 The Callback Pattern

### Default Callbacks (Features OFF)
```cairo
impl MinterCallback: DefaultTokenMinterCallback<ContractState>, // No-op implementation
```

### Component Callbacks (Features ON)  
```cairo
use game_components_token::token::TokenComponent::ComponentTokenMinterCallback;
impl MinterCallback: ComponentTokenMinterCallback, // Uses MinterComponent
```

### Adding New Features
1. **Add the component** to your contract
2. **Import the component callback** from `game_components_token::token::TokenComponent`
3. **Replace the default callback** with the imported component callback
4. **Initialize the component** in constructor
5. **Done!** 🎉

## 🚀 Benefits of This Architecture

✅ **Pick & Choose**: Only include features you need  
✅ **Type Safety**: Compile-time guarantees  
✅ **Clean Code**: Clear separation of concerns  
✅ **Easy Upgrades**: Add features by importing callbacks and changing implementations  
✅ **Minimal Bloat**: No unused dependencies  
✅ **Performance**: Only pay for what you use  
✅ **Pre-built Integrations**: All component callbacks ready to import from TokenComponent  

## 📖 Available Features

| Feature | Component | Callback Trait | Import Path |
|---------|-----------|----------------|-------------|
| Minter Tracking | `MinterComponent` | `TokenMinterCallback` | `TokenComponent::ComponentTokenMinterCallback` |
| Multi-Game | `MultiGameComponent` | `TokenMultiGameCallback` | `TokenComponent::ComponentTokenMultiGameCallback` |
| Objectives | `TokenObjectivesComponent` | `TokenObjectivesCallback` | `TokenComponent::ComponentTokenObjectivesCallback` |
| Soulbound | `SoulboundComponent` | `TokenSoulboundCallback` | *Coming soon* |
| Context | `ContextComponent` | `TokenContextCallback` | *Coming soon* |
| Renderer | `RendererComponent` | `TokenRendererCallback` | *Coming soon* |

## 🔧 Complete Example: Adding Minter Tracking

```cairo
// 1. Add the component to your contract
component!(path: MinterComponent, storage: minter, event: MinterEvent);

// 2. Import the component callback
use game_components_token::token::TokenComponent::ComponentTokenMinterCallback;

// 3. Use the component callback in your TokenComponent implementation
impl TokenImpl = TokenComponent::Token<
    ContractState,
    impl SRC5: SRC5Component::HasComponent<ContractState>,
    impl ERC721: ERC721Component::HasComponent<ContractState>,
    impl MinterCallback: ComponentTokenMinterCallback, // ✅ Feature ON
    impl ContextCallback: DefaultTokenContextCallback<ContractState>, // ❌ Feature OFF
    // ... other callbacks
>;

// 4. Initialize the component
fn constructor(ref self: ContractState, /* ... */) {
    self.minter.initializer(); // Component automatically registers its SRC5 interface
}
```

## 🎮 Real-World Examples

### Gaming Studio
```cairo
// Use advanced_token_example.cairo
// Track which games mint the most tokens
```

### Multi-Game Platform  
```cairo
// Use full_featured_token_example.cairo
// Cross-game achievements and progression
```

### NFT Collection
```cairo
// Use simple_token_example.cairo
// Basic minting without extra complexity
``` 