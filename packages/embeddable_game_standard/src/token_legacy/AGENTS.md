## Token Legacy Package - MinigameTokenLegacy (ERC721)

ERC721 NFT representing playable game instances — the ORIGINAL multi-game
minigame token, now the LEGACY module. Kept as-is (component names, storage,
selectors, interface-id values all frozen) for deployed denshokan. The
minigame token STANDARD is the `token` module (`MinigameTokenComponent`,
self-bound single-game token).

### Core Interface (IMinigameTokenLegacy)

**Interface ID:** `IMINIGAME_TOKEN_LEGACY_ID = 0x246f614bd76b91c378a91877851f2ccdb99278e9fb77c782a22355059ce9906`
(the value is frozen — deployed denshokan registers it on-chain from when
this trait was named `IMinigameToken`)

| Method                  | Signature                                                                                | Description                            |
| ----------------------- | ---------------------------------------------------------------------------------------- | -------------------------------------- |
| token_metadata          | `(token_id: felt252) -> TokenMetadata`                                                   | Get full token metadata                |
| is_playable             | `(token_id: felt252) -> bool`                                                            | Check if token can be played           |
| mint                    | `(...params) -> felt252`                                                                 | Mint a single token                    |
| mint_batch_recipients   | `(...shared params, recipients: Array<MintBatchRecipient>, ...) -> Array<felt252>`       | Batch mint, per-recipient counts       |
| update_game             | `(token_id: felt252)`                                                                    | Sync token state from game             |

**Batch views:** `*_batch` variants for all view functions (token_metadata, is_playable, settings_id, etc.)

### Extension Interfaces

| Extension  | Interface ID | Key Methods                                                   |
| ---------- | ------------ | ------------------------------------------------------------- |
| Minter     | `0x2198...`  | get_minter_address(), get_minter_id(), minter_exists()        |
| Objectives | `0x2c9b...`  | create_objective()                                            |
| Settings   | `0x229b...`  | create_settings()                                             |
| Renderer   | `0x2899...`  | get_renderer(), has_custom_renderer(), reset_token_renderer() |
| Context    | -            | Game context attachment via GameContextDetails                |

### Storage Optimization - StorePacking

TokenMetadata packed into single felt252 (219 bits):

```
| Bits 0-29   | game_id         | 30 bits |
| Bits 30-64  | minted_at       | 35 bits |
| Bits 65-96  | settings_id     | 32 bits |
| Bits 97-166 | lifecycle       | 70 bits |
| Bits 167-206| minted_by       | 40 bits |
| Bits 207-210| flags           | 4 bits  |
| Bits 211-240| objective_id    | 30 bits |
```

**Gas savings:** Reduces from ~6 storage slots to 1 slot per token.

### PackedTokenId (Immutable in token_id)

Token ID encodes immutable metadata (251 bits) eliminating storage reads:

- game_id, minted_by, settings_id, minted_at
- lifecycle delays, objective_id, soulbound, has_context
- tx_hash (collision protection), salt (multicall protection)

### Libs

| File                       | Purpose                                     |
| -------------------------- | ------------------------------------------- |
| `libs/lifecycle.cairo`     | Lifecycle validation (start/end timestamps) |
| `libs/token_state.cairo`   | Playability checks, state transitions       |
| `libs/address_utils.cairo` | Address manipulation utilities              |

### Key Structs

```cairo
struct TokenMetadata {
    game_id: u64, minted_at: u64, settings_id: u32,
    lifecycle: Lifecycle, minted_by: u64, soulbound: bool,
    game_over: bool, completed_objective: bool,
    has_context: bool, objective_id: u32
}

struct Lifecycle { start: u64, end: u64 }
struct MintBatchRecipient { to: ContractAddress, count: u16 }
```

### Extension Directory Structure

```
src/extensions/
  minter/       - Minting authorization
  objectives/   - Objective tracking
  settings/     - Game settings
  renderer/     - Custom rendering
  context/      - Game context
```

### Examples

See `src/tests/examples/` for deployment patterns:

- `minimal_optimized_example.cairo` - Minimal contract
- `full_token_contract.cairo` - All features enabled
- `single_game_token_contract.cairo` - Single game mode
