# Metagame Component

High-level game management component for token delegation and minting coordination. Serves as the entry point for multi-game ecosystems with optional tournament/event context.

## Storage

```cairo
#[storage]
pub struct Storage {}  // Self-bound: no addresses to hold
```

The component is **self-binding**, like `MinigameTokenComponent`: the embedding
contract IS the metagame. It stores no addresses.

- **No default token** — every game brings its own, resolved from
  `game_address` on each mint.
- **No context address** — a metagame that provides context embeds
  `ContextComponent` itself, which registers `IMETAGAME_CONTEXT_ID` on this
  same contract. Nothing ever resolved a provider through a stored address:
  the legacy token takes context as a mint parameter.

## Interfaces

### IMetagame — REMOVED

With no addresses to expose, the trait had no methods left, so `IMetagame` and
`IMETAGAME_ID` are gone (an SRC5 id cannot be derived from an empty selector
set, and nothing probed the old
`0x7997c74299c045696726f0f7f0165f85817acbb0964e23ff77e11e34eff6f2`).

Discover a metagame through the surfaces that still carry meaning:
`IMETAGAME_CONTEXT_ID` for a context provider, `IMETAGAME_CALLBACK_ID` for a
legacy callback receiver. The component now exposes internals only.

### InternalTrait (Component internals)

| Method | Description |
|--------|-------------|
| `mint(game_address, player_name, settings_id, ...)` | Mint a single token |
| `mint_batch(mints: Array<MintMetagameParams>)` | Many tokens, **one call per token**; each entry may name a different game |
| `mint_batch_recipients(game_address, ..., recipients, ..., metadata: u128)` | Many tokens for **ONE** game in a **single dispatch**, via the token's own batch entrypoint |
| `assert_game_registered(game_address)` | Validate game registration |
| `get_game_fee_info(game_address)` / `get_game_fee_recipient(...)` / `pay_game_fee(...)` | Resolve a game's fee terms and recipient, and pay them |

**Choosing between the batch calls:** if the batch shares a game — a tournament
entry, say — use `mint_batch_recipients`. `mint_batch` costs one cross-contract
dispatch per token and re-serialises `context` (which contains an `Array`) each
time; `mint_batch_recipients` hoists the batch-invariant work and runs a single
global salt counter. Reach for `mint_batch` only when entries genuinely name
different games.

Every mint path takes `metadata: u128`, reaching the standard token's 65-bit
field. The legacy token's field is `u16`, so a legacy mint asserts the value
fits (`Metagame: metadata exceeds u16`) rather than truncating it silently —
identically on the single and batch paths, so the two never disagree about what
a legacy token accepts.

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

    impl MetagameInternalImpl = MetagameComponent::InternalImpl<ContractState>;
}
```

There is no `#[abi(embed_v0)]` line and no `initializer` call: the component
exposes no ABI (see "IMetagame — REMOVED") and holds no state. A metagame that
also provides context additionally embeds `ContextComponent` and calls
`self.context.initializer()`.

## Relationships

```
Metagame (self-bound: this contract)
  |-- embeds ContextComponent ---> IMETAGAME_CONTEXT_ID on this address (OPTIONAL)
  `-- per-mint: game_address ----> IMinigame.token_address() --> the game's token
```

Both token generations are served, branched on SRC5: a token supporting
`IMINIGAME_TOKEN_ID` is a self-bound standard token, otherwise it is treated as
a legacy registry-backed token. This applies to `assert_game_registered`,
`mint`/`mint_batch` and `get_game_fee_info`/`pay_game_fee`.

## Initialization Requirements

None — the component has no `initializer`. A metagame that provides context
calls `ContextComponent::initializer()` on itself; a legacy callback receiver
calls `MetagameCallbackComponent::initializer(token_address)`.

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
    pub skills_address: Option<ContractAddress>,
    pub to: ContractAddress,
    pub soulbound: bool,
    pub paymaster: bool,
    pub salt: u16,
    pub metadata: u128,
}
```

`renderer_address` and `skills_address` exist for legacy tokens only; a
standard-token mint rejects them loudly rather than dropping them silently.
