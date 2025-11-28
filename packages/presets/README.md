# Game Components Presets

Ready-to-deploy contracts built with game components. These presets are simple and as generic as possible to cover the most common use cases.

For contract customization and combination of modules, you can build your own contracts using the individual game components.

## Available Presets

### LeaderboardPreset

A tournament leaderboard contract with score submission, ranking, and administrative controls.

**Features:**
- Score submission and automatic ranking
- Configurable leaderboard size and sorting (ascending/descending)
- Position queries and qualification checks
- Administrative controls (owner-only)
- Event emission for all major actions
- SRC5 interface support

**Constructor Parameters:**
- `owner`: Contract administrator address
- `tournament_id`: Unique tournament identifier
- `max_entries`: Maximum number of leaderboard entries
- `ascending`: Sort order (true for ascending, false for descending)
- `game_address`: Game contract address for score retrieval

**Usage Example:**

```cairo
// Deploy the leaderboard
let leaderboard = ILeaderboardDispatcher { 
    contract_address: deploy_leaderboard(
        owner: admin_address,
        tournament_id: 1,
        max_entries: 10,
        ascending: false, // Higher scores rank better
        game_address: game_contract_address
    )
};

// Submit a score
leaderboard.submit_score(token_id: 123, score: 1500, position: 1);

// Get top 5 entries
let top_entries = leaderboard.get_top_entries(5);

// Check if a score qualifies
let qualifies = leaderboard.qualifies(score: 1200);
```

## Related Components

### LeaderboardComponent (from @game-components/leaderboard)

A reusable component that provides leaderboard functionality. Can be embedded in custom contracts.

**Interfaces:**
- `ILeaderboard`: Core leaderboard operations  
- `ILeaderboardAdmin`: Administrative functions

**Storage:**
- Tournament configuration
- Leaderboard entries (token IDs in ranked order)
- Owner address

**Events:**
- `ScoreSubmitted`: When a new score is added
- `ConfigUpdated`: When configuration changes
- `LeaderboardCleared`: When leaderboard is reset
- `OwnershipTransferred`: When ownership changes

**Usage in Custom Contracts:**
```cairo
use game_components_leaderboard::leaderboard_component::leaderboard_component;

#[starknet::contract]
mod MyCustomContract {
    component!(path: leaderboard_component, storage: leaderboard, event: LeaderboardEvent);
    
    #[abi(embed_v0)]
    impl LeaderboardImpl = leaderboard_component::LeaderboardImpl<ContractState>;
}
```

## Installation

Add to your `Scarb.toml`:

```toml
[dependencies]
game_components_presets = { path = "path/to/game-components/packages/presets" }
```

## License

BUSL-1.1