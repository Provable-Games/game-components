# Registration

Player registration tracking component for any context-based system (tournaments, quests, events, etc.).

## Features

- Registration state management keyed by `(game_address, token_id)`
- Entry count tracking per context
- Score submission tracking (one-time submission enforcement)
- Registration banning for disqualification
- StorePacking for efficient storage (98 bits packed into u128)
- Validation helpers for score submission

## Interface

### IRegistration (Public)

| Method | Returns | Description |
|--------|---------|-------------|
| `get_registration(game_address, token_id)` | `Registration` | Full registration data |
| `is_registration_banned(game_address, token_id)` | `bool` | Check if banned |
| `get_context_id_for_token(game_address, token_id)` | `u64` | Context the token is registered for |
| `get_entry_count(context_id)` | `u32` | Number of entries in context |
| `registration_exists(game_address, token_id)` | `bool` | Check if registered (non-zero entry number) |

### InternalTrait

| Method | Description |
|--------|-------------|
| `set_registration(registration)` | Store a registration |
| `increment_entry_count(context_id)` | Increment and return new count |
| `mark_score_submitted(game_address, token_id)` | Mark score as submitted |
| `ban_registration(game_address, token_id)` | Ban a registration |
| `assert_valid_for_submission(registration, context_id)` | Validate for score submission |

## Data Structures

```cairo
struct Registration {
    game_address: ContractAddress,
    game_token_id: u64,
    context_id: u64,
    entry_number: u32,
    has_submitted: bool,
    is_banned: bool,
}

// Packed storage (98 bits -> u128)
struct RegistrationData {
    context_id: u64,       // 64 bits
    entry_number: u32,     // 32 bits
    has_submitted: bool,   // 1 bit
    is_banned: bool,       // 1 bit
}
```

## Usage

```cairo
use game_components_registration::registration::RegistrationComponent;

#[starknet::contract]
mod MyTournament {
    component!(path: RegistrationComponent, storage: registration, event: RegistrationEvent);

    #[abi(embed_v0)]
    impl RegistrationImpl = RegistrationComponent::RegistrationImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        registration: RegistrationComponent::Storage,
    }
}
```

```cairo
// Register a player
let entry_number = self.registration.increment_entry_count(context_id);
let reg = Registration {
    game_address, game_token_id: token_id,
    context_id, entry_number, has_submitted: false, is_banned: false,
};
self.registration.set_registration(@reg);

// Validate before score submission
let reg = self.registration.get_registration(game_address, token_id);
self.registration.assert_valid_for_submission(@reg, context_id);
self.registration.mark_score_submitted(game_address, token_id);
```

## Dependencies

- `game_components_interfaces` - `Registration` struct and `IRegistration` trait
