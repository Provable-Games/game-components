## Token Package - MinigameToken (ERC721)

ERC721 NFT representing playable game instances with compile-time feature optimization.

### Contract Size Optimization (<4MB limit)

Feature flags in `src/config.cairo` eliminate unused code at compile time:

| Flag                | Default | Description                          |
| ------------------- | ------- | ------------------------------------ |
| CORE_TOKEN_ENABLED  | true    | Base token functionality (always on) |
| ERC721_ENABLED      | true    | ERC721 standard implementation       |
| SRC5_ENABLED        | true    | Interface discovery                  |
| MINTER_ENABLED      | true    | Token minting authorization          |
| MULTI_GAME_ENABLED  | true    | Multiple games per token contract    |
| OBJECTIVES_ENABLED  | true    | Token objective tracking             |
| SETTINGS_ENABLED    | true    | Token settings management            |
| SOULBOUND_ENABLED   | true    | Non-transferable tokens              |
| CONTEXT_ENABLED     | true    | Game context attachment              |
| RENDERER_ENABLED    | true    | Custom token rendering               |
| LIFECYCLE_ENABLED   | true    | Start/end timestamp validation       |
| PLAYABILITY_ENABLED | true    | Playability checks                   |

### Core Interface (IMinigameToken)

**Interface ID:** `IMINIGAME_TOKEN_ID = 0xa08df7e54b63300eeacf85a0f3289c405351278620b5af7e5d868b91f4d43d`

| Method             | Signature                                  | Description                  |
| ------------------ | ------------------------------------------ | ---------------------------- |
| token_metadata     | `(token_id: u64) -> TokenMetadata`         | Get full token metadata      |
| is_playable        | `(token_id: u64) -> bool`                  | Check if token can be played |
| mint               | `(...params) -> u64`                       | Mint new token with config   |
| mint_batch         | `(mints: Array<MintParams>) -> Array<u64>` | Batch mint tokens            |
| update_game        | `(token_id: u64)`                          | Sync token state from game   |
| set_token_metadata | `(token_id, ...)`                          | Update token metadata        |

**Batch views:** `*_batch` variants for all view functions (token_metadata, is_playable, settings_id, etc.)

### Extension Interfaces

| Extension  | Interface ID | Key Methods                                                   |
| ---------- | ------------ | ------------------------------------------------------------- |
| Minter     | `0x0214...`  | get_minter_address(), get_minter_id(), minter_exists()        |
| Objectives | `0x08bb...`  | create_objective()                                            |
| Settings   | `0x02e0...`  | create_settings()                                             |
| Renderer   | `0x08f5...`  | get_renderer(), has_custom_renderer(), reset_token_renderer() |
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
struct MintParams { to: ContractAddress, soulbound: bool, ... }
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
