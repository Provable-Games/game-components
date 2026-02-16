## Leaderboard Package

Tournament leaderboard with multi-tournament support, score submission, and ranking.

### Interface ID

`ILEADERBOARD_ID = 0x03c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499705`

### Core Files

| File | Purpose |
|------|---------|
| `leaderboard_component.cairo` | Main StarkNet component |
| `leaderboard_store.cairo` | Storage operations & helpers |
| `leaderboard.cairo` | Pure leaderboard logic |
| `models.cairo` | Data models |
| `interface.cairo` | Re-exports from interfaces package |

### ILeaderboard Interface (Public)

| Method | Signature | Description |
|--------|-----------|-------------|
| submit_score | `(tournament_id, token_id, score, position) -> LeaderboardResult` | Add score to leaderboard |
| get_entries | `(tournament_id) -> Array<LeaderboardEntry>` | Get all entries with scores |
| get_top_entries | `(tournament_id, count) -> Array<LeaderboardEntry>` | Get top N entries |
| get_position | `(tournament_id, token_id) -> Option<u8>` | Get token's position (1-based) |
| qualifies | `(tournament_id, score) -> bool` | Check if score qualifies |
| is_full | `(tournament_id) -> bool` | Check if leaderboard is full |
| get_leaderboard_length | `(tournament_id) -> u32` | Entry count |
| get_tournament_config | `(tournament_id) -> LeaderboardStoreConfig` | Get tournament settings |

### ILeaderboardAdmin Interface (Admin)

| Method | Signature | Description |
|--------|-----------|-------------|
| configure_tournament | `(tournament_id, max_entries, ascending, game_address)` | Set tournament config |
| clear_leaderboard | `(tournament_id)` | Remove all entries |
| owner | `() -> ContractAddress` | Get admin address |
| transfer_ownership | `(new_owner)` | Transfer admin rights |

### IGameDetails Interface (Game Contracts)

Game contracts must implement this for score retrieval:
```cairo
trait IGameDetails<TState> {
    fn score(self: @TState, token_id: u64) -> u32;
}
```

### Data Structures

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

### Component Storage

```cairo
struct Storage {
    owner: ContractAddress,
    entries_count: Map<u64, u32>,           // tournament_id -> count
    entries: Map<(u64, u32), u64>,          // (tournament_id, position) -> token_id
    max_entries: Map<u64, u32>,             // tournament_id -> max
    ascending: Map<u64, bool>,              // tournament_id -> sort order
    game_address: Map<u64, ContractAddress> // tournament_id -> game
}
```

### Events

| Event | Fields | Description |
|-------|--------|-------------|
| TournamentConfigured | tournament_id, max_entries, ascending, game_address | Config changed |
| ScoreSubmitted | tournament_id, token_id, score, position | New score added |
| LeaderboardCleared | tournament_id | Leaderboard reset |
| LeaderboardOwnershipTransferred | previous_owner, new_owner | Admin changed |

### Helper Functions (LeaderboardStoreHelpersTrait)

| Method | Description |
|--------|-------------|
| get_top_winners | Get top N token IDs |
| is_leaderboard_full | Check capacity |
| get_minimum_qualifying_score | Lowest score to qualify |
| get_leaderboard_range | Paginated entries |
| find_score_position | Where score would rank |

### Usage Pattern

```cairo
// Embed component
component!(path: LeaderboardComponent, storage: leaderboard, event: LeaderboardEvent);

// Initialize
leaderboard.initializer(owner_address);

// Configure tournament
leaderboard.configure_tournament(tournament_id, 100, false, game_address);

// Submit score
let result = leaderboard.submit_score(tournament_id, token_id, score, position);
```
