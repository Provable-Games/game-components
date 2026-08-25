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
| `get_game_fee_terms(game_address)` / `pay_game_fee(...)` | Resolve a game's rate, license and recipient in ONE call, and pay them |

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

There is one token generation. `assert_game_registered` is an address
equality, and every mint path applies the same check before trusting a game's
`token_address()` — a contract that merely implements it must not have a
metagame mint on a token it does not own or pay its fee recipient.

## Initialization Requirements

None — the component has no `initializer`. A metagame that provides context
calls `ContextComponent::initializer()` on itself.

## Retired

`MetagameCallbackComponent` was removed with the registry-backed generation.
Callbacks fired from `update_game()`, which the token no longer has: there is
no mutable token state to sync, so nothing calls back. To build against that
generation, pin `v2.0.0` or earlier.

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
