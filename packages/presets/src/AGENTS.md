# Presets Package

## Purpose

Ready-to-deploy contracts for common use cases. Deploy directly without custom contract development.

---

## LeaderboardPreset

Multi-tournament leaderboard with score submission and ranking.

**Components:** `LeaderboardComponent`, `SRC5Component`

**Constructor:**
```cairo
fn constructor(ref self: ContractState, owner: ContractAddress)
```

**Features:**
- Multi-tournament support (separate leaderboards per `tournament_id`)
- Automatic score ranking
- Configurable leaderboard size per submission
- Position queries and qualification checks
- SRC5 interface support

---

## AutonomousBuyback

Autonomous token buyback via Ekubo TWAMM. Permissionless execution with owner-only configuration.

**Components:** `BuybackComponent`, `OwnableComponent`

**Constructor:**
```cairo
fn constructor(
    ref self: ContractState,
    owner: ContractAddress,
    global_config: GlobalBuybackConfig,
    positions_address: ContractAddress,
    extension_address: ContractAddress,
)
```

**Permissionless Functions:**
- `buy_back(params)` - Execute buyback with contract's token balance
- `claim_buyback_proceeds(sell_token, limit)` - Claim completed orders
- `sweep_buy_token_to_treasury()` - Transfer accumulated tokens

**Owner Functions:**
- `set_global_config(config)` - Update global defaults
- `set_token_config(sell_token, config)` - Per-token overrides

**Design:** Append-only, no emergency functions. Existing orders complete naturally.

---

## StreamToken

ERC20 token with built-in TWAMM distribution. Fully autonomous after deployment.

**Components:** `ERC20Component`, `StreamComponent`

**Constructor:**
```cairo
fn constructor(
    ref self: ContractState,
    name: ByteArray,
    symbol: ByteArray,
    total_supply: u128,
    factory: ContractAddress,
    positions_address: ContractAddress,
    core_address: ContractAddress,
    registry_address: ContractAddress,
    extension_address: ContractAddress,
    liquidity_config: LiquidityConfig,
    distribution_orders: Span<DistributionOrder>,
    premint_allocations: Span<PremintAllocation>,
)
```

**Features:**
- Standard ERC20 (OpenZeppelin)
- Premint allocations to specified recipients at deployment
- Multiple concurrent distribution orders
- Permissionless proceeds claiming
- No admin/owner after deployment
- Designed for `StreamTokenFactory` deployment

---

## Building Custom Presets

Compose components for custom contracts:

```cairo
#[starknet::contract]
mod MyPreset {
    use game_components_registry::registry::MinigameRegistryComponent;
    use openzeppelin_access::ownable::OwnableComponent;

    component!(path: MinigameRegistryComponent, storage: registry, event: RegistryEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl RegistryImpl = MinigameRegistryComponent::MinigameRegistryImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        registry: MinigameRegistryComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    // Implement hooks trait or use empty impl
    impl RegistryHooksImpl = MinigameRegistryComponent::MinigameRegistryHooksEmptyImpl<ContractState>;
}
```
