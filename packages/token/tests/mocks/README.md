# Mock Contracts for Token Testing

This directory contains mock implementations for testing the token package with game integration.

## Available Mocks

### 1. MockMinigameContract (`game_mock.cairo`)

Mocks the minigame contract interfaces required by the token package:
- `IMinigame` - Core game interface (token_address, settings_address, objectives_address)
- `IMinigameTokenData` - Token-specific game data (score, game_over)
- `IMinigameDetails` - Game details and descriptions
- `IMinigameDetailsSVG` - SVG rendering for game details
- `IMinigameTokenUri` - Token URI generation

### 2. MockSettingsContract (`settings_mock.cairo`)

Mocks the game settings extension:
- `IMinigameSettings` - Settings existence and retrieval
- `IMinigameSettingsSVG` - SVG rendering for settings

### 3. MockObjectivesContract (`objectives_mock.cairo`)

Mocks the game objectives extension:
- `IMinigameObjectives` - Objective existence, completion status, and retrieval
- `IMinigameObjectivesSVG` - SVG rendering for objectives

## Usage

### Basic Setup

```cairo
use token::tests::mocks::{
    setup_mock_minigame, setup_mock_settings, setup_mock_objectives
};

// Setup with defaults
let (mock_game, token_addr, settings_addr, objectives_addr) = setup_mock_minigame();
let mock_settings = setup_mock_settings();
let mock_objectives = setup_mock_objectives();
```

### Mocking Specific Behavior

```cairo
// Mock game state
mock_game.mock_score(token_id: 1, score: 100);
mock_game.mock_game_over(token_id: 1, game_over: true);

// Mock settings
mock_settings.mock_settings_exist(settings_id: 1, exists: true);
mock_settings.mock_settings(settings_id: 1, settings: custom_settings);

// Mock objectives
mock_objectives.mock_objective_exists(objective_id: 1, exists: true);
mock_objectives.mock_completed_objective(token_id: 1, objective_id: 1, completed: true);
```

### Helper Functions

The mocks include helper functions for common scenarios:

```cairo
// Mock multiple objectives at once
let objective_ids = array![1, 2, 3].span();
mock_objectives.mock_objectives_exist(objective_ids, exists: true);

// Mock multiple completion statuses
let completions = array![true, false, true].span();
mock_objectives.mock_objective_completions(token_id: 1, objective_ids, completions);

// Create default settings
let settings = create_default_settings(settings_id: 1);

// Create default objectives
let objectives = create_default_objectives(objective_ids);
```

### Cleaning Up Mocks

```cairo
// Stop specific mock
mock_game.stop_mock("score");

// Stop all mocks for a contract
mock_game.stop_all_mocks();
```

## Integration with Token Tests

When testing token minting:
1. Setup mocks with the desired game configuration
2. Pass the mock addresses to the token mint function
3. Verify the token correctly queries the mocked interfaces

When testing token updates:
1. Mock the current game state (score, completion, objectives)
2. Call token.update_game()
3. Verify the token metadata is updated correctly

## Example Test Flow

```cairo
#[test]
fn test_token_with_game_integration() {
    // 1. Setup mocks
    let (mock_game, _, _, _) = setup_mock_minigame();
    let mock_objectives = setup_mock_objectives();
    
    // 2. Configure initial state
    mock_game.mock_score(1, 0);
    mock_game.mock_game_over(1, false);
    mock_objectives.mock_objectives_exist(array![1, 2, 3].span(), true);
    
    // 3. Mint token with game
    let token_id = token.mint(
        game_address: Option::Some(mock_game.contract_address),
        objective_ids: Option::Some(array![1, 2, 3].span()),
        // ... other parameters
    );
    
    // 4. Simulate game progress
    mock_game.mock_score(token_id, 500);
    mock_objectives.mock_completed_objective(token_id, 1, true);
    
    // 5. Update token
    token.update_game(token_id);
    
    // 6. Verify token state
    let metadata = token.token_metadata(token_id);
    assert!(metadata.score == 500);
    // ... other assertions
}
```