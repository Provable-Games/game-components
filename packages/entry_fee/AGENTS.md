## Entry Fee Package

The `game_components_entry_fee` package provides a reusable Starknet component for managing entry fees in any context-based system (tournaments, quests, etc.).

### Features

- Entry fee configuration per context (token address, amount, shares)
- Game creator share and refund share (packed in EntryFeeData)
- Additional shares with packed storage (up to 16 shares per felt252 slot)
- Entry fee deposit processing via ERC20 transfers
- Claim tracking for game creator, refund, and additional shares

### Architecture

- **EntryFeeComponent** (`entry_fee.cairo`): Starknet component with storage, external interface, and internal helpers
- **Models** (`models.cairo`): StorePacking implementations for efficient storage (EntryFeeData, PackedAdditionalShares)
- **Libs** (`libs/share_math.cairo`): Pure math functions for bit packing/unpacking shares

### Storage Optimization

Additional shares are packed 16 per felt252 slot (15 bits each = 240 bits), reducing storage operations from N writes to ceil(N/16) writes. Recipients are stored separately since ContractAddress requires 251 bits.
