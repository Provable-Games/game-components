# Registry

Game registration and discovery system. Provides `MinigameRegistryComponent` for tracking games, metadata, and royalties. Games self-register by calling `register_game()`.

## Features

- Game self-registration with metadata (name, description, genre, etc.)
- Address-to-ID and ID-to-address lookups
- Game metadata storage including developer, publisher, and client URL
- Royalty fraction management (basis points)
- Hooks pattern for custom registration behavior
- SRC5 interface validation on registration

**Interface ID**: `0x014a8d6e4bf56a4bbf869257d1f846e5a2ac1e3508466147556f186143409be1`

## Interface

### IMinigameRegistry

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

Use `MinigameRegistryHooksEmptyImpl` for the no-op default.

## Events

| Event | Fields | Description |
|-------|--------|-------------|
| `GameRegistryUpdate` | `id, contract_address` | Game registered |
| `GameMetadataUpdate` | `id, contract_address, name, description, ...` | Full metadata stored |
| `GameRoyaltyUpdate` | `game_id, royalty_fraction` | Royalty updated |

## Usage

```cairo
use game_components_embeddable_game_standard::registry::registry_component::MinigameRegistryComponent;

#[starknet::contract]
mod MyRegistry {
    component!(path: MinigameRegistryComponent, storage: registry, event: RegistryEvent);

    #[abi(embed_v0)]
    impl RegistryImpl = MinigameRegistryComponent::MinigameRegistryImpl<ContractState>;

    // Use empty hooks or implement custom hooks
    impl RegistryHooksImpl = MinigameRegistryComponent::MinigameRegistryHooksEmptyImpl<ContractState>;

    fn constructor(ref self: ContractState) {
        // Call initializer to register SRC5 interface
        self.registry.initializer();
    }
}
```

## Dependencies

- `game_components_interfaces` - Registry structs and interface definitions
- `openzeppelin_introspection` - SRC5 interface registration
