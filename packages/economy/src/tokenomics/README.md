# Tokenomics

Autonomous token buyback and distribution via Ekubo TWAMM (Time-Weighted Average Market Maker). Append-only design with no emergency functions for security.

## Features

- Permissionless buyback execution using Ekubo TWAMM DCA orders
- ERC20 stream token with autonomous TWAMM distribution
- Factory pattern for deploying stream tokens
- Global and per-token configuration for buyback parameters
- Append-only design (no emergency withdrawal, existing orders complete naturally)

## BuybackComponent

Permissionless buyback execution using Ekubo TWAMM DCA orders.

### IBuyback (Permissionless)

| Function | Description |
|----------|-------------|
| `buy_back(params: BuybackParams)` | Execute buyback with full contract balance |
| `claim_buyback_proceeds(sell_token, limit)` | Claim completed orders to treasury |
| `sweep_buy_token_to_treasury()` | Transfer accumulated buy tokens to treasury |
| `get_global_config()` | Global configuration defaults |
| `get_token_config(sell_token)` | Per-token override (None = use global) |
| `get_order_info(sell_token, index)` | Specific order details |
| `get_order_count(sell_token)` | Total orders for token |

### IBuybackAdmin (Owner-only)

| Function | Description |
|----------|-------------|
| `set_global_config(config)` | Update global defaults |
| `set_token_config(sell_token, config)` | Set/clear per-token config |

### Key Structs

```cairo
pub struct GlobalBuybackConfig {
    pub default_buy_token: ContractAddress,
    pub default_treasury: ContractAddress,
    pub default_minimum_amount: u128,
    pub default_min_delay: u64,      // 0 = immediate
    pub default_max_delay: u64,      // 0 = no limit
    pub default_min_duration: u64,
    pub default_max_duration: u64,
    pub default_fee: u128,
}

pub struct BuybackParams {
    pub sell_token: ContractAddress,
    pub start_time: u64,  // 0 = start immediately
    pub end_time: u64,
}
```

## StreamComponent

ERC20 token with autonomous TWAMM distribution orders.

### IStreamToken (Permissionless)

| Function | Description |
|----------|-------------|
| `burn(amount)` | Burn from caller |
| `burn_from(account, amount)` | Burn using allowance |
| `claim_distribution_proceeds(order_index)` | Claim proceeds to recipient |
| `get_order_count()` | Total distribution orders |
| `get_order(index)` | Order details |
| `is_initialized()` | Deployment state == 2 |

### IStreamTokenSetup (Factory-only)

| Function | Description |
|----------|-------------|
| `provide_initial_liquidity()` | Initialize pool and add LP |
| `start_distributions()` | Begin all distribution orders |

## StreamTokenFactory

Deploys autonomous stream tokens with TWAMM integration.

| Function | Description |
|----------|-------------|
| `create_token(params: CreateTokenParams)` | Deploy new stream token |
| `is_valid_token(address)` | Check if factory-deployed |
| `get_token_count()` | Total tokens deployed |

### Deployment Flow

1. User approves factory for paired token
2. `create_token()` deploys StreamToken
3. Factory transfers paired tokens to Ekubo positions
4. Factory calls `provide_initial_liquidity()`
5. Factory transfers stream tokens to Ekubo positions
6. Factory calls `start_distributions()`
7. Token is fully autonomous

## Usage

```cairo
// Buyback component
use game_components_tokenomics::buyback::BuybackComponent;
component!(path: BuybackComponent, storage: buyback, event: BuybackEvent);

// Stream component
use game_components_tokenomics::stream::StreamComponent;
component!(path: StreamComponent, storage: stream, event: StreamEvent);
```

## Dependencies

- `game_components_interfaces` - Buyback and stream interface definitions
- `ekubo` v4.0.1 - TWAMM integration for DCA orders
- `openzeppelin` - ERC20, Ownable components
