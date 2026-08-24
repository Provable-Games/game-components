# Metagame Component

High-level game management component for token delegation and minting coordination. Serves as the entry point for multi-game ecosystems with optional tournament/event context.

## Storage

```cairo
#[storage]
pub struct Storage {
    context_address: ContractAddress,  // Optional IMetagameContext
}
```

There is no metagame-wide default token: every game brings its own, so the
token is resolved from `game_address` on each mint.

## Interfaces

### IMetagame (Read-only)

| Method | Returns | Description |
|--------|---------|-------------|
| `context_address()` | `ContractAddress` | Optional context contract (tournaments/events) |

**Interface ID**: `0x1363c8de5144122290d663c4c7a10d09518fbe76475610a7027ea4770b9c179`

Removing `default_token_address()` changed the id — consumers probing the
previous value must update.

### InternalTrait (Component internals)

| Method | Description |
|--------|-------------|
| `initializer(context_address)` | Initialize with optional context |
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
  |-- context_address --------> IMetagameContext (OPTIONAL)
  `-- per-mint: game_address --> IMinigame.token_address() --> the game's token
```

Both token generations are served, branched on SRC5: a token supporting
`IMINIGAME_TOKEN_ID` is a self-bound standard token, otherwise it is treated as
a legacy registry-backed token. This applies to `assert_game_registered`,
`mint`/`mint_batch` and `get_game_fee_info`/`pay_game_fee`.

## Initialization Requirements

- `context_address` (if provided) MUST support `IMETAGAME_CONTEXT_ID`, validated via SRC5 on init

## Callback extension

`MetagameCallbackComponent::initializer(token_address)` binds the LEGACY token
allowed to call back. Callbacks fire from `update_game()`, which the standard
self-bound token does not have — so the callback extension is legacy-only and
owns its token binding rather than reading one off `MetagameComponent`.

## MintMetagameParams

```cairo
pub struct MintMetagameParams {
    pub game_address: ContractAddress,
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
