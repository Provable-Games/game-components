# Test Plan for Metagame Package

## 1. Contract Reconnaissance

### Contract Overview
The metagame package provides a high-level game management component for Starknet-based games, acting as an orchestration layer between game contracts and the token system.

### Function Inventory

| Function | Type | Signature | Mutates State | Emits Events |
|----------|------|-----------|---------------|--------------|
| `initializer` | Internal | `fn initializer(ref self: ComponentState<TContractState>, minigame_token_address: ContractAddress, context_address: ContractAddress)` | Yes | No |
| `register_src5_interfaces` | Internal | `fn register_src5_interfaces(ref self: ComponentState<TContractState>)` | Yes | No |
| `assert_game_registered` | Internal | `fn assert_game_registered(self: @ComponentState<TContractState>, world: IWorldDispatcher, namespace_hash: felt252, game_address: ContractAddress)` | No | No |
| `mint` | Internal | `fn mint(ref self: ComponentState<TContractState>, world: IWorldDispatcher, namespace_hash: felt252, game_address: ContractAddress, player_name: ByteArray, settings_id: u32, time_start: u64, time_end: u64, objectives: Array<u64>, context: Option<GameContextDetails>, client_url: ByteArray, renderer_address: ContractAddress, to: ContractAddress, soulbound: bool) -> u64` | Yes | No* |
| `minigame_token_address` | External | `fn minigame_token_address(self: @ComponentState<TContractState>) -> ContractAddress` | No | No |
| `context_address` | External | `fn context_address(self: @ComponentState<TContractState>) -> ContractAddress` | No | No |

*Events are emitted by the token contract during minting

### State Variables
- `minigame_token_address: ContractAddress` - Address of the minigame token contract
- `context_address: ContractAddress` - Optional address of external context contract

### Constants
- `IMETAGAME_ID: felt252 = 0x0260d5160a283a03815f6c3799926c7bdbec5f22e759f992fb8faf172243ab20`
- `IMETAGAME_CONTEXT_ID: felt252 = 0x0c2e78065b81a310a1cb470d14a7b88875542ad05286b3263cf3c254082386e`

### Data Structures
```cairo
struct GameContextDetails {
    name: ByteArray,
    description: ByteArray,
    id: u32,
    data: Array<GameContext>
}

struct GameContext {
    key: ByteArray,
    value: ByteArray
}
```

## 2. Behaviour & Invariant Mapping

### initializer
- **Purpose**: Initialize the metagame component with token and optional context addresses
- **Inputs**: 
  - `minigame_token_address`: Must be non-zero contract address
  - `context_address`: Can be zero (no external context) or valid contract address
- **State Changes**: Sets storage variables for both addresses
- **Invariants**: 
  - Token address must never be zero
  - Addresses are immutable after initialization
- **Failure Conditions**: None (but should fail if token address is zero)

### register_src5_interfaces
- **Purpose**: Register SRC5 interface support for the metagame component
- **State Changes**: Registers IMETAGAME_ID interface
- **Invariants**: Must be called during initialization
- **Access Control**: Internal only

### assert_game_registered
- **Purpose**: Verify that a game is registered in the token contract
- **Inputs**:
  - `world`: Dojo world dispatcher
  - `namespace_hash`: Namespace for game registration
  - `game_address`: Address to validate
- **Failure Conditions**: Reverts with "Game is not registered" if game not found

### mint
- **Purpose**: Mint a new token with comprehensive game metadata
- **Inputs**:
  - `game_address`: Must be registered
  - `player_name`: Player identifier
  - `settings_id`: Game settings reference
  - `time_start/time_end`: Timestamps for game duration
  - `objectives`: Array of objective IDs achieved
  - `context`: Optional context data
  - `client_url`: URL for game client
  - `renderer_address`: Address for rendering logic
  - `to`: Recipient address
  - `soulbound`: Whether token is transferable
- **State Changes**: Creates new token in token contract
- **Returns**: Token ID of minted token
- **Failure Conditions**:
  - Game not registered
  - Context provided but no context support
  - External context doesn't support interface
- **Invariants**:
  - Token ID must be unique and incremental
  - Game must be registered before minting

### minigame_token_address
- **Purpose**: Query the token contract address
- **Returns**: Stored token address
- **Invariants**: Never returns zero after initialization

### context_address
- **Purpose**: Query the context contract address
- **Returns**: Stored context address (can be zero)

## 3. Unit Test Design

### Initialization Tests
| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| INIT-01 | Initialize with valid token address only | Component initialized, context = 0 |
| INIT-02 | Initialize with token and context addresses | Both addresses stored correctly |
| INIT-03 | Initialize with zero token address | Should fail |
| INIT-04 | Query addresses after init | Return correct values |
| INIT-05 | Verify SRC5 registration | IMETAGAME_ID supported |

### Game Registration Tests
| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| REG-01 | Check registered game | No revert |
| REG-02 | Check unregistered game | Revert "Game is not registered" |
| REG-03 | Check zero address game | Revert |
| REG-04 | Check with invalid world | Revert |

### Minting Tests
| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| MINT-01 | Basic mint without context | Token created, ID returned |
| MINT-02 | Mint with empty objectives array | Success |
| MINT-03 | Mint with multiple objectives | All objectives stored |
| MINT-04 | Mint to zero address | Should fail in token contract |
| MINT-05 | Mint from unregistered game | Revert "Game is not registered" |
| MINT-06 | Mint soulbound token | Token non-transferable |
| MINT-07 | Mint transferable token | Token transferable |

### Context Tests
| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| CTX-01 | Mint with context, no support | Revert "Caller does not support IMetagameContext" |
| CTX-02 | Mint with embedded context | Context stored internally |
| CTX-03 | Mint with external context | Context validated and stored |
| CTX-04 | External context no interface | Revert "Context contract does not support IMetagameContext" |
| CTX-05 | Complex context data | All key-value pairs stored |

## 4. Fuzz & Property-Based Tests

### Fuzz Test Specifications

#### FZ-01: Token ID Monotonicity
- **Property**: Token IDs always increase
- **Input Domain**: Random valid game addresses, random metadata
- **Invariant**: `token_id_n+1 > token_id_n`

#### FZ-02: Game Registration Consistency
- **Property**: Only registered games can mint
- **Input Domain**: Random addresses (0x0 to MAX)
- **Expected**: Unregistered always revert

#### FZ-03: Context Data Integrity
- **Property**: Context data preserved exactly as provided
- **Input Domain**: 
  - String lengths: 0-1000 chars
  - Array sizes: 0-100 elements
  - Unicode and special characters
- **Invariant**: Retrieved context == provided context

#### FZ-04: Timestamp Validation
- **Property**: time_end >= time_start (if enforced)
- **Input Domain**: u64 full range
- **Note**: Currently no validation, but test for future

#### FZ-05: Objective Array Handling
- **Property**: All objectives stored correctly
- **Input Domain**: 
  - Array size: 0-1000
  - Values: full u64 range
  - Duplicates allowed

### Negative Fuzz Tests

#### NFZ-01: Invalid Addresses
- **Target**: All address parameters
- **Domain**: Invalid patterns, high bits set
- **Expected**: Appropriate reverts

#### NFZ-02: Overflow Scenarios
- **Target**: Numeric parameters
- **Test**: Max values, arithmetic overflow attempts
- **Expected**: Safe handling or revert

## 5. Integration & Scenario Tests

### Happy Path Scenarios

#### INT-01: Complete Game Flow
1. Deploy token contract
2. Deploy metagame with token address
3. Register game in token
4. Player completes game
5. Mint token with achievements
6. Verify token metadata
7. Query token from contracts

#### INT-02: Multi-Game Tournament
1. Deploy shared infrastructure
2. Register multiple games
3. Different games mint tokens
4. Verify isolation between games
5. Check token uniqueness

### Adversarial Scenarios

#### ADV-01: Malicious Game Attack
1. Deploy malicious game contract
2. Attempt mint without registration
3. Try to spoof registration
4. Attempt reentrancy during mint
5. All attempts must fail

#### ADV-02: Context Manipulation
1. Provide malicious context contract
2. Context contract changes data after validation
3. Verify metagame handles safely
4. No state corruption

### Edge Cases

#### EDGE-01: Maximum Data Sizes
1. Max length player name (1000+ chars)
2. Max objectives array (1000 items)
3. Max context data (100 key-value pairs)
4. Verify gas limits and functionality

#### EDGE-02: Timing Edge Cases
1. time_start = 0
2. time_end = MAX_U64
3. time_start > time_end
4. Current time validations

## 6. Coverage Matrix

| Function/Invariant | Unit-Happy | Unit-Revert | Fuzz | Property | Integration | Event |
|-------------------|------------|-------------|------|----------|-------------|-------|
| initializer | INIT-01,02,04 | INIT-03 | - | - | INT-01 | - |
| register_src5_interfaces | INIT-05 | - | - | - | INT-01 | - |
| assert_game_registered | REG-01 | REG-02,03,04 | FZ-02 | - | INT-01,ADV-01 | - |
| mint | MINT-01,02,03,06,07 | MINT-04,05,CTX-01,04 | FZ-01,03,04,05 | - | INT-01,02,EDGE-01 | - |
| mint (context path) | CTX-02,03,05 | CTX-01,04 | FZ-03 | - | ADV-02 | - |
| minigame_token_address | INIT-04 | - | - | - | INT-01 | - |
| context_address | INIT-04 | - | - | - | INT-01 | - |
| Token ID monotonicity | - | - | FZ-01 | ✓ | INT-02 | - |
| Game isolation | - | - | FZ-02 | ✓ | INT-02,ADV-01 | - |
| Context integrity | - | - | FZ-03 | ✓ | ADV-02 | - |

## 7. Tooling & Environment

### Test Framework
- **Primary**: Starknet Foundry (`snforge`)
- **Build**: Scarb 2.10.1
- **Cairo**: 2.10.1

### Required Mocks
```cairo
// mock_token.cairo
#[starknet::contract]
mod MockMinigameToken {
    // Implement IMinigameToken interface
    // Track minted tokens
    // Implement game registration
}

// mock_context.cairo  
#[starknet::contract]
mod MockContext {
    // Implement IMetagameContext
    // Store/retrieve context data
}

// mock_world.cairo
#[starknet::contract]
mod MockWorld {
    // Implement IWorldDispatcher interface
    // Simulate Dojo world behavior
}
```

### Directory Structure
```
tests/
├── unit/
│   ├── test_initialization.cairo
│   ├── test_game_registration.cairo
│   ├── test_minting.cairo
│   └── test_context.cairo
├── integration/
│   ├── test_complete_flow.cairo
│   ├── test_multi_game.cairo
│   └── test_adversarial.cairo
├── fuzz/
│   ├── test_token_properties.cairo
│   ├── test_context_fuzz.cairo
│   └── test_input_validation.cairo
└── common/
    ├── mocks.cairo
    ├── helpers.cairo
    └── constants.cairo
```

### Test Naming Convention
- Unit tests: `test_<component>_<scenario>_<expected>`
- Integration: `test_integration_<flow>_<variant>`
- Fuzz: `test_fuzz_<property>_<domain>`
- Property: `test_property_<invariant>`

### Coverage Requirements
- Branch coverage: 100%
- Function coverage: 100%
- Line coverage: >95%
- Event coverage: 100% (via token contract)

### Coverage Commands
```bash
# Run all tests with coverage
cd packages/test_starknet && snforge test --coverage

# Generate coverage report
snforge coverage-report

# Run specific test category
snforge test test_unit::
snforge test test_integration::
snforge test test_fuzz::
```

## 8. Self-Audit Checklist

### Branch Coverage
- [x] Zero address validation paths
- [x] Game registration check branches
- [x] Context support detection
- [x] External vs embedded context paths
- [x] All parameter combinations in mint

### Event Coverage
- [x] Token minting events (via token contract)
- [x] No direct events in metagame component

### Require/Assert Coverage
- [x] "Game is not registered" assertion
- [x] "Caller does not support IMetagameContext"
- [x] "Context contract does not support IMetagameContext"
- [x] All validation paths tested

### Edge Cases
- [x] Empty arrays and strings
- [x] Maximum size inputs
- [x] Boundary timestamps
- [x] Address edge cases

### Security Scenarios
- [x] Unauthorized game access
- [x] Malicious context contracts
- [x] Reentrancy protection
- [x] Input validation

**Discrepancies Found**: None - all branches, assertions, and functionality mapped to test cases.