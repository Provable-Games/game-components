# Entry Fee

Entry fee management component for context-based systems (tournaments, quests, events, etc.).

## Features

- Entry fee configuration per context (token address, amount, distribution shares)
- ERC20 deposit processing with automatic transfers
- Game creator share and refund share tracking
- Additional shares with packed storage (up to 16 shares per felt252 slot)
- Claim tracking for game creator, refund, and additional share recipients
- StorePacking for efficient on-chain storage

## Architecture

| Module | Purpose |
|--------|---------|
| `entry_fee.cairo` | Starknet component with storage, external interface, and internal helpers |
| `models.cairo` | StorePacking implementations (EntryFeeData, PackedAdditionalShares) |
| `libs/share_math.cairo` | Pure math functions for bit packing/unpacking shares |

## Storage Optimization

Additional shares are packed 16 per felt252 slot (15 bits each = 240 bits), reducing storage operations from N writes to `ceil(N/16)` writes. Recipients are stored separately since `ContractAddress` requires 251 bits.

## Interface

### IEntryFee (Public)

| Method | Description |
|--------|-------------|
| `get_entry_fee(context_id)` | Get fee config for a context |
| `get_entry_fee_amount(context_id)` | Get fee amount only |
| `get_entry_fee_token(context_id)` | Get fee token address |

### InternalTrait

| Method | Description |
|--------|-------------|
| `set_entry_fee(context_id, token, amount, creator_share, refund_share)` | Configure fee |
| `add_additional_share(context_id, recipient, share_bps)` | Add an additional share recipient |
| `process_entry_fee(context_id, payer)` | Collect fee from payer via ERC20 transfer |
| `claim_creator_share(context_id, recipient)` | Claim game creator's accumulated share |
| `claim_refund_share(context_id, recipient)` | Claim refund share |
| `claim_additional_share(context_id, index, recipient)` | Claim additional share by index |

## Usage

```cairo
use game_components_entry_fee::entry_fee::EntryFeeComponent;

#[starknet::contract]
mod MyTournament {
    component!(path: EntryFeeComponent, storage: entry_fee, event: EntryFeeEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        entry_fee: EntryFeeComponent::Storage,
    }
}
```

```cairo
// Configure entry fee: 100 tokens, 10% to creator, 5% refundable
self.entry_fee.set_entry_fee(context_id, erc20_address, 100, 1000, 500);

// Add additional share: 5% to treasury
self.entry_fee.add_additional_share(context_id, treasury_address, 500);

// Collect fee from player
self.entry_fee.process_entry_fee(context_id, player_address);

// Distribute shares
self.entry_fee.claim_creator_share(context_id, creator_address);
```

## Dependencies

- `game_components_interfaces` - EntryFee types
- `openzeppelin_interfaces` - ERC20 interface for token transfers
