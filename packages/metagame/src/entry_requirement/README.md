# Entry Requirement

Entry gating component for controlling access to contexts (tournaments, quests, events, etc.).

## Features

- Three requirement types: Token, Allowlist, and Extension
- Token ownership requirement for NFT gating
- Allowlist-based access control
- External validator extension via `IEntryValidator` for custom logic
- Built-in `EntryValidatorComponent` for building custom validators
- SRC5 interface registration

## Requirement Types

| Type | Description |
|------|-------------|
| `Token` | Requires caller to own a specific NFT (ERC721 balance check) |
| `Allowlist` | Requires caller's address to be on an approved list |
| `Extension` | Delegates validation to an external `IEntryValidator` contract |

## Interface

### IEntryRequirement

| Method | Description |
|--------|-------------|
| `get_entry_requirement(context_id)` | Get the requirement config for a context |
| `meets_entry_requirement(context_id, player)` | Check if player meets the requirement |

### IEntryValidator (Extension Interface)

Custom validator contracts implement this:

```cairo
trait IEntryValidator<TState> {
    fn validate_entry(self: @TState, context_id: u64, player: ContractAddress) -> bool;
}
```

### InternalTrait

| Method | Description |
|--------|-------------|
| `set_entry_requirement(context_id, requirement)` | Configure requirement for a context |
| `assert_meets_entry_requirement(context_id, player)` | Assert or panic |
| `add_to_allowlist(context_id, addresses)` | Add addresses to allowlist |
| `remove_from_allowlist(context_id, addresses)` | Remove addresses from allowlist |

## Usage

```cairo
use game_components_entry_requirement::entry_requirement::EntryRequirementComponent;

#[starknet::contract]
mod MyTournament {
    component!(path: EntryRequirementComponent, storage: entry_req, event: EntryReqEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        entry_req: EntryRequirementComponent::Storage,
    }
}
```

```cairo
// Set up token gating
self.entry_req.set_entry_requirement(context_id, EntryRequirement::Token(nft_address));

// Set up allowlist
self.entry_req.set_entry_requirement(context_id, EntryRequirement::Allowlist);
self.entry_req.add_to_allowlist(context_id, array![addr1, addr2].span());

// Set up external validator
self.entry_req.set_entry_requirement(context_id, EntryRequirement::Extension(validator_address));

// Check access
let allowed = self.entry_req.meets_entry_requirement(context_id, player);
```

## Dependencies

- `game_components_interfaces` - EntryRequirement types and IEntryValidator interface
- `openzeppelin_interfaces` - ERC20/ERC721 interfaces
- `openzeppelin_introspection` - SRC5 interface registration
