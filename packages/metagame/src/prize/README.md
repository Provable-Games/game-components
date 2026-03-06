# Prize

Prize management component for ERC20 and ERC721 rewards in any context-based system.

## Features

- ERC20 and ERC721 prize deposit and storage
- Efficient StorePacking for prize data
- Claim tracking using Poseidon hash-based keys for O(1) lookups
- Hash caching optimization for repeated claim operations
- Custom distribution shares with packed storage (up to 15 u16 shares per felt252 slot)
- Prize refund support for sponsors

## Architecture

| Module | Purpose |
|--------|---------|
| `prize.cairo` | Starknet component with storage, external interface, and internal helpers |
| `models.cairo` | StorePacking implementations (StoredPrize, PackedERC20Data, CustomShares) |
| `libs/share_math.cairo` | Pure math functions for 16-bit share packing/unpacking |

## Storage Optimization

- ERC20 data packed into single felt252 (amount + payout_type + param + count = 184 bits)
- Custom distribution shares packed 15 per felt252 slot (16 bits each = 240 bits)
- Prize claim lookups use Poseidon hash of PrizeType for O(1) storage access

## Interface

### IPrize (Public)

| Method | Description |
|--------|-------------|
| `get_prize(context_id, prize_index)` | Get prize details |
| `get_prize_count(context_id)` | Number of prizes for a context |
| `is_claimed(context_id, prize_index, position)` | Check if position has claimed |

### InternalTrait

| Method | Description |
|--------|-------------|
| `add_erc20_prize(context_id, token, amount, distribution, ...)` | Add ERC20 prize |
| `add_erc721_prize(context_id, token, token_id)` | Add ERC721 prize |
| `claim_prize(context_id, prize_index, position, recipient)` | Claim a prize |
| `refund_prize(context_id, prize_index, sponsor)` | Refund unclaimed prize to sponsor |

## Usage

```cairo
use game_components_prize::prize::PrizeComponent;

#[starknet::contract]
mod MyTournament {
    component!(path: PrizeComponent, storage: prize, event: PrizeEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        prize: PrizeComponent::Storage,
    }
}
```

```cairo
// Add ERC20 prize pool with linear distribution across top 3
self.prize.add_erc20_prize(
    context_id, erc20_address, 1000, Distribution::Linear(10), 3
);

// Add ERC721 prize (specific NFT)
self.prize.add_erc721_prize(context_id, nft_address, nft_token_id);

// Claim prizes (after tournament completion)
self.prize.claim_prize(context_id, prize_index, position, winner_address);
```

## Dependencies

- `game_components_interfaces` - Prize types and distribution enum
- `game_components_distribution` - Share calculation for ERC20 distribution
- `openzeppelin_interfaces` - ERC20/ERC721 interfaces for token transfers
