# Registry Package

## Purpose

Game registration and discovery system. Provides `MinigameRegistryComponent` for tracking games, metadata, and royalties. Games self-register by calling `register_game()`.

## Storage

| Field | Type | Description |
|-------|------|-------------|
| `game_counter` | `u64` | Total registered games |
| `game_id_by_address` | `Map<ContractAddress, u64>` | Address to game ID lookup |
| `game_metadata` | `Map<u64, GameMetadata>` | Game ID to metadata |

## Interface: IMinigameRegistry<TState>

| Function | Description |
|----------|-------------|
| `register_game(...)` | Register new game, returns `game_id`. Caller must implement `IMINIGAME_ID` |
| `game_count()` | Total registered games |
| `game_id_from_address(address)` | Get game ID by contract address |
| `game_address_from_id(id)` | Get contract address by game ID |
| `game_metadata(id)` | Get full metadata for game |
| `is_game_registered(address)` | Check if address is registered |
| `set_game_royalty(id, fraction)` | Update royalty (owner of game creator token only) |

## GameMetadata Struct

```cairo
pub struct GameMetadata {
    pub contract_address: ContractAddress,
    pub name: ByteArray,
    pub description: ByteArray,
    pub developer: ByteArray,
    pub publisher: ByteArray,
    pub genre: ByteArray,
    pub image: ByteArray,
    pub color: ByteArray,
    pub client_url: ByteArray,
    pub renderer_address: ContractAddress,
    pub royalty_fraction: u128,  // Basis points (500 = 5%)
    pub skills_address: ContractAddress, // Address of skills provider contract
    pub created_at: u64,
}
```

## Hooks Pattern

Implement `MinigameRegistryHooksTrait` for custom registration behavior:

```cairo
pub trait MinigameRegistryHooksTrait<TContractState> {
    fn before_register_game(ref self: TContractState, caller: ContractAddress, creator: ContractAddress);
    fn after_register_game(ref self: TContractState, game_id: u64, creator: ContractAddress);
}
```

Use `MinigameRegistryHooksEmptyImpl` for no-op default.

## Events

- `GameRegistryUpdate { id, contract_address }` - Game registered
- `GameMetadataUpdate { id, contract_address, name, description, ..., skills_address }` - Full metadata stored
- `GameRoyaltyUpdate { game_id, royalty_fraction }` - Royalty updated

## Interface ID

```cairo
pub const IMINIGAME_REGISTRY_ID: felt252 = 0x014a8d6e4bf56a4bbf869257d1f846e5a2ac1e3508466147556f186143409be1;
```

## Usage

```cairo
use game_components_embeddable_game_standard::registry::registry_component::MinigameRegistryComponent;
component!(path: MinigameRegistryComponent, storage: registry, event: RegistryEvent);

// Call initializer in constructor to register SRC5 interface
self.registry.initializer();
```
