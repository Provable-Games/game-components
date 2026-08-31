# Tokenomics Package

## Purpose

Autonomous token buyback and distribution via Ekubo TWAMM (Time-Weighted Average Market Maker). Append-only design with no emergency functions for security.

## Dependencies

- **Ekubo Protocol** v4.0.1 - TWAMM integration for DCA orders
- **OpenZeppelin** - ERC20, Ownable components

---

## BuybackComponent

Permissionless buyback execution using Ekubo TWAMM DCA orders.

### IBuyback<TState> (Permissionless)

| Function | Description |
|----------|-------------|
| `buy_back(params: BuybackParams)` | Execute buyback with full contract balance |
| `claim_buyback_proceeds(sell_token, limit)` | Claim completed orders to treasury |
| `sweep_buy_token_to_treasury()` | Transfer accumulated buy tokens to treasury |
| `get_global_config()` | Global configuration defaults |
| `get_token_config(sell_token)` | Per-token override (None = use global) |
| `get_order_info(sell_token, index)` | Specific order details |
| `get_order_count(sell_token)` | Total orders for token |
| `get_config_epoch(sell_token)` | Current config epoch (see below) |

### Config epochs

`buy_token` and `fee` are not stored per order and are not one mutable pair per
sell token either. Each order records an 8-bit **epoch**, and the pair lives in
`Map<(sell_token, epoch), EpochConfig>`.

A `buy_back` that sees a different pair from the current epoch's opens the NEXT
epoch. Orders already created keep naming the old one, so each rebuilds the
exact Ekubo `OrderKey` it was opened with. Consequences worth knowing:

- **The config is not frozen while orders are open.** The fee tier can be
  corrected at any time; earlier orders remain claimable. There is no
  `'Buy token mismatch'` / `'Fee mismatch'` any more — both are gone.
- **`get_order_info` / `get_order_key` stay correct after a claim**, because
  they resolve through the order's own epoch rather than shared state that used
  to be zeroed on a full drain.
- **`get_active_buy_token` / `get_active_fee` are latest-only** — what the next
  order would use, not a value open orders are pinned to.
- **One Ekubo position per sell token, for good.** The position id is no longer
  cleared on a full drain: Ekubo keys a sale by `(owner, salt, order_key)` with
  `salt` = the position id, so one NFT holds orders under many keys at once.
- **255 changes per sell token.** The 256th is refused with
  `'Config epochs exhausted'` rather than wrapping to epoch 0 and
  reinterpreting old orders under the wrong config.

The epoch costs 8 bits of the packed order record, so `MAX_ORDER_AMOUNT` is
`2**112 - 1` rather than `2**120 - 1`. Still ~5.2e15 tokens at 18 decimals.

### IBuybackAdmin<TState> (Owner-only)

| Function | Description |
|----------|-------------|
| `set_global_config(config)` | Update global defaults |
| `set_token_config(sell_token, config)` | Set/clear per-token config |

### Structs

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

pub struct TokenBuybackConfig {
    pub buy_token: ContractAddress,
    pub treasury: ContractAddress,
    pub minimum_amount: u128,
    pub min_delay: u64, pub max_delay: u64,
    pub min_duration: u64, pub max_duration: u64,
    pub fee: u128,
}

pub struct BuybackParams {
    pub sell_token: ContractAddress,
    pub start_time: u64,  // 0 = start immediately
    pub end_time: u64,
}
```

---

## StreamComponent

ERC20 token with autonomous TWAMM distribution orders.

### IStreamToken<TState> (Permissionless)

| Function | Description |
|----------|-------------|
| `burn(amount)` | Burn from caller |
| `burn_from(account, amount)` | Burn using allowance |
| `claim_distribution_proceeds(order_index)` | Claim proceeds to recipient |
| `get_order_count()` | Total distribution orders |
| `get_order(index)` | Order details |
| `is_initialized()` | Deployment state == 2 |

### IStreamTokenSetup<TState> (Factory-only)

| Function | Description |
|----------|-------------|
| `provide_initial_liquidity()` | Initialize pool and add LP |
| `start_distributions()` | Begin all distribution orders |

### Structs

```cairo
pub struct DistributionOrder {
    pub buy_token: ContractAddress,
    pub fee: u128,
    pub start_time: u64,  // 0 = start immediately
    pub end_time: u64,
    pub amount: u128,
    pub proceeds_recipient: ContractAddress,
}

pub struct LiquidityConfig {
    pub paired_token: ContractAddress,
    pub fee: u128,
    pub stream_token_amount: u128,
    pub paired_token_amount: u128,
    pub min_liquidity: u128,
}

pub struct CreateTokenParams {
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub total_supply: u128,
    pub liquidity_config: LiquidityConfig,
    pub distribution_orders: Span<DistributionOrder>,
}
```

---

## DepositLockComponent

Holds a single ERC20 received by plain transfer and releases each arrival to a beneficiary after a fixed term. Each deposit keeps its own term from its own arrival.

### IDepositLock<TState> (Permissionless)

| Function | Description |
|----------|-------------|
| `lock()` | Crank: stamp everything arrived since the last call (`balance − locked_total`) with a fresh term. Permissionless — it can only move funds from unrecorded to locked |
| `release(limit)` | Send matured deposits to the beneficiary, oldest first, at most `limit` day-buckets. Permissionless |
| `pending()` | Arrived but not yet stamped by `lock` — cannot be released |
| `releasable()` | Matured and awaiting `release` |
| `locked_total()` | Recorded and unreleased, matured or not |
| `unlock_day_at(index)` / `queue_range()` | Inspect the day queue |
| `token()` / `beneficiary()` / `lock_duration()` | Config views |

### IDepositLockAdmin<TState> (Owner-gated by the embedder)

| Function | Description |
|----------|-------------|
| `set_beneficiary(beneficiary)` | Change where matured deposits go. Cannot shorten a lock. Internal in the component (`InternalTrait::set_beneficiary`, no access check); the embedding contract exposes it behind its own owner gate |

### Design

- **Day bucketing**: unlock times round UP to a day boundary and same-day deposits merge, so outstanding records are bounded by `lock_duration` in days (≤366 for a year) regardless of deposit count — dust cannot inflate `release` cost. Rounding up means a deposit is locked for *at least* the full term.
- **`initializer(token, beneficiary, lock_duration)`**: token and term are fixed (no setters); all non-zero.
- **No emergency withdrawal** by design. Composition: embed `DepositLockImpl` (permissionless) + `OwnableComponent`, forward `set_beneficiary` through `assert_only_owner` — see the `DepositLock` preset.

---

## SplitterComponent

Divides whatever it receives across a weighted list of destinations. `distribute(token)` reads the contract's own balance and pays each leg its basis-point share, with the FINAL leg taking the remainder — so parts sum to exactly the whole, no dust stranded. Permissionless, any ERC20, no per-token setup.

### ISplitter<TState> (Permissionless)

| Function | Description |
|----------|-------------|
| `distribute(token)` | Split the whole balance of `token` across the legs |
| `distribute_many(tokens)` | `distribute` over several tokens; empty balances skipped (keeper-friendly batch) |
| `split()` | The configured `Span<SplitLeg>` |

### Design

- **`initializer(legs)`**: validates legs are non-empty, ≤ `MAX_LEGS` (8), non-zero destination/bps, no duplicate destination, summing to exactly `BPS_DENOMINATOR` (10000). No setter — the split is immutable, and there is **no owner** (change a ratio by re-pointing the revenue source at a new splitter).
- **Conservation**: one balance read drives every leg; the last leg gets `total − paid`, so integer division never strands dust.
- **No emergency withdrawal** — `distribute` is the only exit and is permissionless.
- **Standard-ERC20 assumption**: a balance ≥ `2^256/10000` overflows the `total*bps` multiply; a non-standard `transfer` reverts `distribute` for that token.

`SplitLeg { destination, bps }` lives in `interfaces/tokenomics/splitter`.

---

## StreamTokenFactory

Deploys autonomous stream tokens with TWAMM integration.

### IStreamTokenFactory<TState>

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

---

## Usage

```cairo
// Buyback
use game_components_tokenomics::buyback::BuybackComponent;
component!(path: BuybackComponent, storage: buyback, event: BuybackEvent);

// Stream
use game_components_tokenomics::stream::StreamComponent;
component!(path: StreamComponent, storage: stream, event: StreamEvent);
```
