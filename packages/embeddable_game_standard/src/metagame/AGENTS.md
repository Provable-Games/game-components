# Metagame Component

High-level game management component for token delegation and minting coordination. Serves as the entry point for multi-game ecosystems with optional tournament/event context.

## Storage

```cairo
#[storage]
pub struct Storage {
    context_address: ContractAddress,        // Optional IMetagameContext
    default_token_address: ContractAddress,  // Required MinigameToken
}
```

## Interfaces

### IMetagame (Read-only)

| Method | Returns | Description |
|--------|---------|-------------|
| `context_address()` | `ContractAddress` | Optional context contract (tournaments/events) |
| `default_token_address()` | `ContractAddress` | Default MinigameToken for minting |

**Interface ID**: `0x0260d5160a283a03815f6c3799926c7bdbec5f22e759f992fb8faf172243ab20`

### InternalTrait (Component internals)

| Method | Description |
|--------|-------------|
| `initializer(context_address, default_token_address)` | Initialize with optional context |
| `mint(game_address, player_name, settings_id, ...)` | Mint single token |
| `mint_batch(mints: Array<MintMetagameParams>)` | Batch mint tokens |
| `assert_game_registered(game_address)` | Validate game registration |

## Extensions

### Context (`extensions/context/`)

Optional tournament/event context management.

| Interface | Methods |
|-----------|---------|
| `IMetagameContext` | `has_context(token_id)` |
| `IMetagameContextDetails` | `context_details(token_id)` |
| `IMetagameContextSVG` | `context_svg(token_id)` |

**Interface ID**: `0x0c2e78065b81a310a1cb470d14a7b88875542ad05286b3263cf3c254082386e`

### Callback (`extensions/callback/`)

Automatic callbacks from token contracts on game state changes.

| Interface | Methods |
|-----------|---------|
| `IMetagameCallback` | `on_game_action(token_id, score)` |
| | `on_game_over(token_id, final_score)` |
| | `on_objective_complete(token_id)` |

**Interface ID**: `0x04d4f4758b99dcb4f1e2dc37c3a6e8c7a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6`

## Component Embedding

```cairo
#[starknet::contract]
mod MyMetagame {
    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        metagame: MetagameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[abi(embed_v0)]
    impl MetagameImpl = MetagameComponent::MetagameImpl<ContractState>;
}
```

## Relationships

```
Metagame
  |-- default_token_address --> MinigameToken (REQUIRED)
  |-- context_address --------> IMetagameContext (OPTIONAL)
```

## Initialization Requirements

- `default_token_address` MUST support `IMINIGAME_TOKEN_ID`
- `context_address` (if provided) MUST support `IMETAGAME_CONTEXT_ID`
- Both addresses validated via SRC5 introspection on init

## MintMetagameParams

```cairo
pub struct MintMetagameParams {
    pub game_address: Option<ContractAddress>,
    pub player_name: Option<felt252>,
    pub settings_id: Option<u32>,
    pub start: Option<u64>,
    pub end: Option<u64>,
    pub objective_id: Option<u32>,
    pub context: Option<GameContextDetails>,
    pub client_url: Option<ByteArray>,
    pub renderer_address: Option<ContractAddress>,
    pub to: ContractAddress,
    pub soulbound: bool,
}
```
