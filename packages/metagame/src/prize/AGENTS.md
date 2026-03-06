## Prize Package

The `game_components_prize` package provides a reusable Starknet component for managing prizes (ERC20 and ERC721) in any context-based system.

### Features

- Prize storage and retrieval with efficient StorePacking
- ERC20 and ERC721 prize deposit processing
- Prize claim tracking using Poseidon hash-based keys
- Hash caching optimization for repeated claim operations
- Custom distribution shares with packed storage (up to 15 u16 shares per felt252 slot)
- Prize refund support for sponsors

### Architecture

- **PrizeComponent** (`prize.cairo`): Starknet component with storage, external interface, and internal helpers
- **Models** (`models.cairo`): StorePacking implementations (StoredPrize, PackedERC20Data, CustomShares)
- **Libs** (`libs/share_math.cairo`): Pure math functions for 16-bit share packing/unpacking

### Storage Optimization

- ERC20 data packed into single felt252 (amount + payout_type + param + count = 184 bits)
- Custom distribution shares packed 15 per felt252 slot (16 bits each = 240 bits)
- Prize claim lookups use Poseidon hash of PrizeType for O(1) storage access
