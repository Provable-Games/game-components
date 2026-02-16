# Test Common Package

## Purpose

Shared mocks and example contracts for testing. Provides reusable test infrastructure across packages.

---

## WARNING: Do Not Modify Existing Mocks

**Create NEW mocks instead of modifying existing ones.**

Existing mocks may be dependencies for multiple test suites. Before modifying any mock:

```bash
grep -r "mock_name" packages/*/src/tests/
```

---

## Mock Contracts

Located in `src/mocks/`:

| Mock | Purpose |
|------|---------|
| `mock_game.cairo` | Game contract implementing `IMinigame` |
| `mock_game_details.cairo` | Game details provider |
| `mock_leaderboard_contract.cairo` | Leaderboard for testing submissions |
| `mock_objectives_contract.cairo` | `IMinigameObjectives` implementation |
| `mock_settings_contract.cairo` | `IMinigameSettings` implementation |
| `mock_registry_contract.cairo` | Registry for game registration tests |
| `metagame_starknet_mock.cairo` | Metagame component mock |
| `minigame_starknet_mock.cairo` | Minigame component mock |

---

## Example Contracts

Located in `src/examples/`:

| Example | Purpose |
|---------|---------|
| `minimal_optimized_example.cairo` | Minimal token (~50% size reduction) |
| `single_game_token_contract.cairo` | Token supporting single game only |
| `minigame_registry_contract.cairo` | Registry with token support |
| `full_token_contract.cairo` | All features enabled reference |

---

## Usage

Import mocks in test files:

```cairo
use game_components_test_common::mocks::mock_game::MockGame;
use game_components_test_common::mocks::mock_settings_contract::MockSettings;
use game_components_test_common::examples::minimal_optimized_example::MinimalToken;
```

Deploy in tests:

```cairo
fn deploy_mock_game() -> IMinigameDispatcher {
    let contract = declare("MockGame").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    IMinigameDispatcher { contract_address: address }
}
```

---

## Creating New Mocks

When existing mocks do not fit your needs:

1. Create new file in `src/mocks/` with descriptive name
2. Add to `src/mocks.cairo` module list
3. Document the mock's purpose and behavior
4. Do not modify existing mocks

```cairo
// src/mocks/mock_custom_game.cairo
#[starknet::contract]
pub mod MockCustomGame {
    // Your custom mock implementation
}
```

```cairo
// src/mocks.cairo - add entry
pub mod mock_custom_game;
```
