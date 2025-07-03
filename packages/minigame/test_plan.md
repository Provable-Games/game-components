# Test Plan for Minigame Package

## 1. Contract Reconnaissance

### Function Inventory

| Component | Function | Signature | Type | State Mutation | Events |
|-----------|----------|-----------|------|----------------|--------|
| MinigameComponent | token_address | `(self: @TState) -> ContractAddress` | External | No | No |
| MinigameComponent | settings_address | `(self: @TState) -> ContractAddress` | External | No | No |
| MinigameComponent | objectives_address | `(self: @TState) -> ContractAddress` | External | No | No |
| MinigameComponent | initializer | `(ref self: TState, token_address: ContractAddress, settings_address: ContractAddress, objectives_address: ContractAddress, name: ByteArray, symbol: ByteArray, base_uri: ByteArray, game_data: ByteArray)` | Internal | Yes | No |
| MinigameComponent | register_game_interface | `(ref self: TState)` | Internal | Yes | No |
| MinigameComponent | pre_action | `(self: @TState, token_id: u64)` | Internal | No | No |
| MinigameComponent | post_action | `(ref self: TState, token_id: u64)` | Internal | Yes | No |
| MinigameComponent | get_player_name | `(self: @TState, token_id: u64) -> ByteArray` | Internal | No | No |
| MinigameComponent | assert_token_ownership | `(self: @TState, token_id: u64)` | Internal | No | No |
| MinigameComponent | assert_game_token_playable | `(self: @TState, token_id: u64)` | Internal | No | No |
| ObjectivesComponent | objective_exists | `(self: @TState, objective_id: u32) -> bool` | External | No | No |
| ObjectivesComponent | completed_objective | `(self: @TState, token_id: u64, objective_id: u32) -> bool` | External | No | No |
| ObjectivesComponent | objectives | `(self: @TState, token_id: u64) -> Span<GameObjective>` | External | No | No |
| ObjectivesComponent | objectives_svg | `(self: @TState, token_id: u64) -> ByteArray` | External | No | No |
| ObjectivesComponent | initializer | `(ref self: TState)` | Internal | Yes | No |
| ObjectivesComponent | get_objective_ids | `(self: @TState, token_id: u64, token_address: ContractAddress) -> (Span<u32>, Span<u32>)` | Internal | No | No |
| ObjectivesComponent | create_objective | `(self: @TState, objective_id: u32, name: ByteArray, value: ByteArray, token_address: ContractAddress) -> GameObjective` | Internal | No | No |
| SettingsComponent | settings_exist | `(self: @TState, settings_id: u32) -> bool` | External | No | No |
| SettingsComponent | settings | `(self: @TState, settings_id: u32) -> GameSettingDetails` | External | No | No |
| SettingsComponent | settings_svg | `(self: @TState, settings_id: u32) -> ByteArray` | External | No | No |
| SettingsComponent | initializer | `(ref self: TState)` | Internal | Yes | No |
| SettingsComponent | get_settings_id | `(self: @TState, token_id: u64, token_address: ContractAddress) -> u32` | Internal | No | No |
| SettingsComponent | create_settings | `(self: @TState, settings_id: u32, name: ByteArray, description: ByteArray, settings: Span<GameSetting>, token_address: ContractAddress) -> GameSettingDetails` | Internal | No | No |

### State Variables & Constants

| Component | Variable/Constant | Type | Description |
|-----------|------------------|------|-------------|
| MinigameComponent | token_address | ContractAddress | Token contract address |
| MinigameComponent | settings_address | ContractAddress | Settings extension address |
| MinigameComponent | objectives_address | ContractAddress | Objectives extension address |
| Interface | IMINIGAME_ID | felt252 | SRC5 interface ID for IMinigame |
| Interface | IMINIGAME_OBJECTIVES_ID | felt252 | SRC5 interface ID for objectives |
| Interface | IMINIGAME_SETTINGS_ID | felt252 | SRC5 interface ID for settings |

### Data Structures

- **GameDetail**: `{ name: ByteArray, value: ByteArray }`
- **GameObjective**: `{ name: ByteArray, value: ByteArray }`
- **GameSettingDetails**: `{ name: ByteArray, description: ByteArray, settings: Span<GameSetting> }`
- **GameSetting**: `{ name: ByteArray, value: ByteArray }`

## 2. Behavior & Invariant Mapping

### MinigameComponent

#### initializer
- **Purpose**: Initialize minigame component with token and extension addresses
- **Inputs**: 
  - token_address: Valid contract address (non-zero)
  - settings_address: Valid contract address (non-zero)
  - objectives_address: Valid contract address (non-zero)
  - name, symbol, base_uri, game_data: ByteArray values for game registration
- **State Changes**: Sets storage addresses, registers SRC5 interface, registers game with token
- **Invariants**: 
  - All addresses must be non-zero
  - Component can only be initialized once
  - Must successfully register with token contract

#### pre_action
- **Purpose**: Validate token is playable before game action
- **Inputs**: token_id (0 to MAX_U64)
- **Validation**: Token must exist, be owned by caller, and be in playable state
- **Failure Conditions**: Non-existent token, wrong owner, game over state

#### post_action
- **Purpose**: Update game state after action
- **Inputs**: token_id (0 to MAX_U64)
- **State Changes**: Updates token game state via token contract
- **Invariants**: Must be called after successful pre_action

### ObjectivesComponent

#### objective_exists
- **Purpose**: Check if objective ID exists
- **Inputs**: objective_id (0 to MAX_U32)
- **Returns**: true if exists via token contract query

#### completed_objective
- **Purpose**: Check if player completed specific objective
- **Inputs**: token_id (0 to MAX_U64), objective_id (0 to MAX_U32)
- **Returns**: true if objective completed for token

#### objectives
- **Purpose**: Get all objectives for a token
- **Inputs**: token_id (0 to MAX_U64)
- **Returns**: Span of GameObjective structs

### SettingsComponent

#### settings_exist
- **Purpose**: Check if settings ID exists
- **Inputs**: settings_id (0 to MAX_U32)
- **Returns**: true if exists via token contract query

#### settings
- **Purpose**: Get settings details
- **Inputs**: settings_id (0 to MAX_U32)
- **Returns**: GameSettingDetails struct
- **Failure**: Panics if settings don't exist

## 3. Unit Test Design

### MinigameComponent Tests

| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| MC-U1 | Initialize with valid addresses | Component initialized, SRC5 registered |
| MC-U2 | Initialize with zero token address | Should panic |
| MC-U3 | Initialize with zero settings address | Should panic |
| MC-U4 | Initialize with zero objectives address | Should panic |
| MC-U5 | Double initialization attempt | Should fail/panic |
| MC-U6 | Get token_address after init | Returns correct address |
| MC-U7 | Get settings_address after init | Returns correct address |
| MC-U8 | Get objectives_address after init | Returns correct address |
| MC-U9 | pre_action with valid owned token | Passes validation |
| MC-U10 | pre_action with non-existent token | Should panic |
| MC-U11 | pre_action with token not owned | Should panic |
| MC-U12 | pre_action with game_over token | Should panic |
| MC-U13 | post_action with valid token | Updates game state |
| MC-U14 | assert_token_ownership with owned token | Passes |
| MC-U15 | assert_token_ownership with wrong owner | Panics |
| MC-U16 | assert_game_token_playable when playable | Passes |
| MC-U17 | assert_game_token_playable when game over | Panics |
| MC-U18 | get_player_name with valid token | Returns name |
| MC-U19 | register_game_interface | SRC5 interface registered |

### ObjectivesComponent Tests

| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| OC-U1 | Initialize objectives component | SRC5 interface registered |
| OC-U2 | objective_exists with valid ID | Returns true |
| OC-U3 | objective_exists with invalid ID | Returns false |
| OC-U4 | completed_objective when completed | Returns true |
| OC-U5 | completed_objective when not completed | Returns false |
| OC-U6 | objectives with token having objectives | Returns correct span |
| OC-U7 | objectives with token having no objectives | Returns empty span |
| OC-U8 | objectives_svg with valid token | Returns SVG string |
| OC-U9 | get_objective_ids with multi-game token | Returns correct IDs |
| OC-U10 | create_objective with valid data | Returns GameObjective |

### SettingsComponent Tests

| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| SC-U1 | Initialize settings component | SRC5 interface registered |
| SC-U2 | settings_exist with valid ID | Returns true |
| SC-U3 | settings_exist with invalid ID | Returns false |
| SC-U4 | settings with existing ID | Returns GameSettingDetails |
| SC-U5 | settings with non-existent ID | Panics |
| SC-U6 | settings_svg with valid ID | Returns SVG string |
| SC-U7 | get_settings_id for token | Returns correct ID |
| SC-U8 | create_settings with valid data | Returns GameSettingDetails |

## 4. Fuzz & Property-Based Tests

### Fuzzing Strategies

#### Token ID Fuzzing
- **Domain**: [0, 2^64-1]
- **Properties**:
  - P1: pre_action should only pass for existing, owned, playable tokens
  - P2: Token operations should handle boundary values (0, MAX_U64)
  - P3: Concurrent operations on same token should maintain consistency

#### Objective/Settings ID Fuzzing
- **Domain**: [0, 2^32-1]
- **Properties**:
  - P4: objective_exists(id) == true ⟺ objectives can be retrieved
  - P5: settings_exist(id) == true ⟺ settings can be retrieved
  - P6: Non-existent IDs should consistently return false/panic

#### ByteArray Fuzzing
- **Domain**: Random byte sequences, empty arrays, max-length arrays
- **Properties**:
  - P7: All ByteArray inputs should be handled without overflow
  - P8: Empty strings should be valid for names/values
  - P9: Special characters in ByteArrays should not break encoding

### Invariant Tests

| Test ID | Invariant | Test Strategy |
|---------|-----------|---------------|
| INV-1 | Token ownership never changes during game actions | Fuzz pre/post action sequences |
| INV-2 | Game over state is permanent | Attempt state changes after game_over |
| INV-3 | Component addresses are immutable after init | Attempt to reinitialize |
| INV-4 | SRC5 interfaces remain registered | Query after various operations |
| INV-5 | Objective completion is monotonic | Fuzz objective state transitions |

## 5. Integration & Scenario Tests

### Multi-Step Scenarios

| Test ID | Scenario | Steps |
|---------|----------|-------|
| INT-1 | Complete game flow | 1. Deploy contracts<br>2. Initialize minigame<br>3. Register player<br>4. Perform actions<br>5. Complete objectives<br>6. Game over |
| INT-2 | Multi-game integration | 1. Deploy with multi-game token<br>2. Register multiple games<br>3. Switch between games<br>4. Verify isolation |
| INT-3 | Extension coordination | 1. Initialize all extensions<br>2. Create settings<br>3. Create objectives<br>4. Verify cross-extension queries |
| INT-4 | Ownership transfer | 1. Mint token to player A<br>2. Transfer to player B<br>3. Verify player B can play<br>4. Verify player A cannot |
| INT-5 | Concurrent players | 1. Multiple players mint tokens<br>2. Simultaneous game actions<br>3. Verify state isolation |

### Adversarial Scenarios

| Test ID | Attack Vector | Expected Defense |
|---------|---------------|------------------|
| ADV-1 | Replay attacks | Each action validated fresh |
| ADV-2 | Unauthorized access | Ownership checks prevent access |
| ADV-3 | State manipulation | Immutable addresses prevent hijacking |
| ADV-4 | Resource exhaustion | Bounded data structures |
| ADV-5 | Reentrancy | State checks prevent reentrancy |

## 6. Coverage Matrix

| Function | Unit-Happy | Unit-Revert | Fuzz | Property | Integration | Events |
|----------|------------|-------------|------|----------|-------------|--------|
| initializer | MC-U1 | MC-U2,3,4,5 | P7 | INV-3 | INT-1 | N/A |
| token_address | MC-U6 | N/A | P2 | INV-3 | INT-1,2,3 | N/A |
| settings_address | MC-U7 | N/A | P2 | INV-3 | INT-1,3 | N/A |
| objectives_address | MC-U8 | N/A | P2 | INV-3 | INT-1,3 | N/A |
| pre_action | MC-U9 | MC-U10,11,12 | P1,2 | INV-1,2 | INT-1,4,5 | N/A |
| post_action | MC-U13 | N/A | P1,2 | INV-1,2 | INT-1,5 | N/A |
| assert_token_ownership | MC-U14 | MC-U15 | P1 | INV-1 | INT-4 | N/A |
| assert_game_token_playable | MC-U16 | MC-U17 | P1 | INV-2 | INT-1 | N/A |
| get_player_name | MC-U18 | N/A | P7 | N/A | INT-1 | N/A |
| register_game_interface | MC-U19 | N/A | N/A | INV-4 | INT-1 | N/A |
| objective_exists | OC-U2,3 | N/A | P4,6 | INV-4 | INT-1,3 | N/A |
| completed_objective | OC-U4,5 | N/A | P4 | INV-5 | INT-1 | N/A |
| objectives | OC-U6,7 | N/A | P4 | INV-5 | INT-1,3 | N/A |
| objectives_svg | OC-U8 | N/A | P7,8 | N/A | INT-3 | N/A |
| settings_exist | SC-U2,3 | N/A | P5,6 | INV-4 | INT-1,3 | N/A |
| settings | SC-U4 | SC-U5 | P5 | N/A | INT-1,3 | N/A |
| settings_svg | SC-U6 | N/A | P7,8 | N/A | INT-3 | N/A |

## 7. Tooling & Environment

### Test Framework
- **Primary**: scarb test (Starknet Foundry)
- **Build**: scarb build
- **Coverage**: snforge test with coverage flags

### Required Mocks
- Mock token contract implementing IMinigameToken interface
- Mock token with multi-game support (IMinigameTokenMultiGame)
- Mock dispatchers for cross-contract calls
- Mock game context for metagame integration

### Test Structure
```
packages/minigame/tests/
├── unit/
│   ├── test_minigame_component.cairo
│   ├── test_objectives_component.cairo
│   └── test_settings_component.cairo
├── integration/
│   ├── test_game_flow.cairo
│   ├── test_multi_game.cairo
│   └── test_extensions.cairo
├── fuzz/
│   ├── test_token_operations.cairo
│   └── test_data_structures.cairo
└── mocks/
    ├── mock_token.cairo
    └── mock_extensions.cairo
```

### Naming Conventions
- Unit tests: `test_{component}_{function}_{scenario}`
- Integration tests: `test_scenario_{name}`
- Fuzz tests: `fuzz_{property}_{target}`
- Property tests: `property_{invariant_name}`

### Coverage Requirements
- Line coverage: 100%
- Branch coverage: 100%
- Function coverage: 100%
- Event coverage: N/A (no events in minigame)

### Commands
```bash
# Run all tests
scarb test

# Run specific test file
scarb test test_minigame_component

# Run with coverage
snforge test --coverage

# Run only unit tests
scarb test unit::

# Run only integration tests
scarb test integration::
```

## 8. Self-Audit Checklist

✓ All external functions have unit tests (happy and revert paths)  
✓ All internal state-mutating functions have tests  
✓ All validation/assertion functions have boundary tests  
✓ All data structures have fuzz tests  
✓ Multi-game scenarios covered  
✓ Extension integration tested  
✓ Access control thoroughly tested  
✓ State transitions and invariants verified  
✓ No untested branches identified  
✓ Coverage matrix shows no gaps  

**Discrepancies**: None identified. All contract functionality mapped to test cases.