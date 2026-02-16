# Leaderboard

Tournament scoring and ranking system with multi-tournament support, score submission, and leaderboard management.

## Features

- Multi-tournament support with separate leaderboards per `tournament_id`
- Score submission with automatic ranking and position validation
- Configurable leaderboard size and sort order (ascending/descending)
- Position queries, qualification checks, and pagination
- Administrative controls with ownership transfer
- Event emission for all major actions

**Interface ID**: `0x03c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499705`

## Interface

### ILeaderboard (Public)

| Method | Signature | Description |
|--------|-----------|-------------|
| `submit_score` | `(tournament_id, token_id, score, position) -> LeaderboardResult` | Add score to leaderboard |
| `get_entries` | `(tournament_id) -> Array<LeaderboardEntry>` | Get all entries with scores |
| `get_top_entries` | `(tournament_id, count) -> Array<LeaderboardEntry>` | Get top N entries |
| `get_position` | `(tournament_id, token_id) -> Option<u8>` | Get token's position (1-based) |
| `qualifies` | `(tournament_id, score) -> bool` | Check if score qualifies |
| `is_full` | `(tournament_id) -> bool` | Check if leaderboard is full |
| `get_leaderboard_length` | `(tournament_id) -> u32` | Entry count |
| `get_tournament_config` | `(tournament_id) -> LeaderboardStoreConfig` | Get tournament settings |

### ILeaderboardAdmin (Admin)

| Method | Signature | Description |
|--------|-----------|-------------|
| `configure_tournament` | `(tournament_id, max_entries, ascending, game_address)` | Set tournament config |
| `clear_leaderboard` | `(tournament_id)` | Remove all entries |
| `owner` | `() -> ContractAddress` | Get admin address |
| `transfer_ownership` | `(new_owner)` | Transfer admin rights |

### IGameDetails (Game Contracts)

Game contracts must implement this for score retrieval:

```cairo
trait IGameDetails<TState> {
    fn score(self: @TState, token_id: u64) -> u32;
}
```

## Data Structures

```cairo
struct LeaderboardConfig {
    max_entries: u32,      // Maximum leaderboard size
    ascending: bool,       // true = lower scores better
    allow_ties: bool       // Allow same scores
}

struct LeaderboardEntry {
    id: u64,               // Token ID
    score: u32             // Score value
}

struct LeaderboardStoreConfig {
    max_entries: u32,
    ascending: bool,
    game_address: ContractAddress  // For score retrieval
}

enum LeaderboardResult {
    Success,
    InvalidPosition,
    LeaderboardFull,
    ScoreTooLow,
    ScoreTooHigh,
    DuplicateEntry,
    InvalidConfig
}
```

## Events

| Event | Fields | Description |
|-------|--------|-------------|
| `TournamentConfigured` | `tournament_id, max_entries, ascending, game_address` | Config changed |
| `ScoreSubmitted` | `tournament_id, token_id, score, position` | New score added |
| `LeaderboardCleared` | `tournament_id` | Leaderboard reset |
| `LeaderboardOwnershipTransferred` | `previous_owner, new_owner` | Admin changed |

## Usage

```cairo
use game_components_leaderboard::leaderboard_component::LeaderboardComponent;

#[starknet::contract]
mod MyTournament {
    component!(path: LeaderboardComponent, storage: leaderboard, event: LeaderboardEvent);

    #[abi(embed_v0)]
    impl LeaderboardImpl = LeaderboardComponent::LeaderboardImpl<ContractState>;

    // Initialize
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.leaderboard.initializer(owner);
    }
}
```

```cairo
// Configure and use
leaderboard.configure_tournament(tournament_id, 100, false, game_address);
let result = leaderboard.submit_score(tournament_id, token_id, score, position);
let top_5 = leaderboard.get_top_entries(tournament_id, 5);
```

## Dependencies

- `game_components_interfaces` - Leaderboard structs and interface definitions
