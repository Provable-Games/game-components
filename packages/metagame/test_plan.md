# Test Plan for Metagame Package

## 1. Contract Reconnaissance

### Function Inventory

| Contract/Component | Function | Type | Signature |
|-------------------|----------|------|-----------|
| **MetagameComponent** | | | |
| | minigame_token_address | External/View | `fn minigame_token_address(self: @ComponentState<TContractState>) -> ContractAddress` |
| | context_address | External/View | `fn context_address(self: @ComponentState<TContractState>) -> ContractAddress` |
| | initializer | Internal | `fn initializer(ref self: ComponentState<TContractState>, context_address: Option<ContractAddress>, minigame_token_address: ContractAddress)` |
| | register_src5_interfaces | Internal | `fn register_src5_interfaces(ref self: ComponentState<TContractState>)` |
| | assert_game_registered | Internal | `fn assert_game_registered(ref self: ComponentState<TContractState>, game_address: ContractAddress)` |
| | mint | Internal | `fn mint(ref self: ComponentState<TContractState>, game_address: Option<ContractAddress>, player_name: Option<ByteArray>, settings_id: Option<u32>, start: Option<u64>, end: Option<u64>, objective_ids: Option<Span<u32>>, context: Option<GameContextDetails>, client_url: Option<ByteArray>, renderer_address: Option<ContractAddress>, to: ContractAddress, soulbound: bool) -> u64` |
| **ContextComponent** | | | |
| | initializer | Internal | `fn initializer(ref self: ComponentState<TContractState>)` |
| | register_context_interface | Internal | `fn register_context_interface(ref self: ComponentState<TContractState>)` |
| **libs** | | | |
| | assert_game_registered | Library | `fn assert_game_registered(minigame_token_address: ContractAddress, game_address: ContractAddress)` |
| | mint | Library | `fn mint(minigame_token_address: ContractAddress, game_address: Option<ContractAddress>, player_name: Option<ByteArray>, settings_id: Option<u32>, start: Option<u64>, end: Option<u64>, objective_ids: Option<Span<u32>>, context: Option<GameContextDetails>, client_url: Option<ByteArray>, renderer_address: Option<ContractAddress>, to: ContractAddress, soulbound: bool) -> u64` |

### State Variables
- **MetagameComponent**: `minigame_token_address: ContractAddress`, `context_address: ContractAddress`
- **ContextComponent**: None (empty storage)

### Constants
- `IMETAGAME_ID: felt252 = 0x0260d5160a283a03815f6c3799926c7bdbec5f22e759f992fb8faf172243ab20`
- `IMETAGAME_CONTEXT_ID: felt252 = 0x0c2e78065b81a310a1cb470d14a7b88875542ad05286b3263cf3c254082386e`

### Events
- None found in the codebase

## 2. Behaviour & Invariant Mapping

### MetagameComponent Functions

#### minigame_token_address()
- **Purpose**: Returns the stored minigame token contract address
- **Inputs**: None
- **Outputs**: ContractAddress
- **State Changes**: None (read-only)
- **Invariants**: Value never changes after initialization

#### context_address()
- **Purpose**: Returns the stored context contract address
- **Inputs**: None
- **Outputs**: ContractAddress (can be zero)
- **State Changes**: None (read-only)
- **Invariants**: Value never changes after initialization

#### initializer()
- **Purpose**: Initializes the component with token and optional context addresses
- **Inputs**: 
  - `context_address: Option<ContractAddress>` - Optional context contract
  - `minigame_token_address: ContractAddress` - Required token contract
- **State Changes**: 
  - Writes minigame_token_address
  - Writes context_address (if Some)
  - Registers SRC5 interface
- **Invariants**: Can only be called once

#### mint()
- **Purpose**: Validates context requirements and delegates minting to token contract
- **Inputs**: 11 parameters including game config, metadata, and minting options
- **Outputs**: u64 (token ID)
- **State Changes**: None directly (delegates to token contract)
- **Revert Conditions**:
  - If context provided but context_address doesn't support IMetagameContext
  - If context provided, no context_address, and caller doesn't support IMetagameContext
- **Invariants**: Context validation logic is consistent

#### assert_game_registered()
- **Purpose**: Verifies game is registered in token contract
- **Inputs**: `game_address: ContractAddress`
- **State Changes**: None
- **Revert Conditions**: Game not registered
- **Invariants**: Delegation to libs function

### ContextComponent Functions

#### initializer()
- **Purpose**: Registers the context interface
- **Inputs**: None
- **State Changes**: Registers SRC5 interface
- **Invariants**: Can only be called once

### Library Functions

#### libs::assert_game_registered()
- **Purpose**: Checks game registration via token contract
- **Inputs**: `minigame_token_address`, `game_address`
- **Revert Conditions**: "Game is not registered"

#### libs::mint()
- **Purpose**: Direct delegation to token contract's mint function
- **Inputs**: Same 11 parameters as MetagameComponent::mint
- **Outputs**: u64 (token ID)

## 3. Unit-Test Design

### Test Cases

#### T001: MetagameComponent Initialization Tests
- T001.1: Initialize with both token and context addresses
- T001.2: Initialize with token address only (context = None)
- T001.3: Verify SRC5 interface registration (IMETAGAME_ID)
- T001.4: Verify storage writes are correct

#### T002: MetagameComponent View Function Tests
- T002.1: minigame_token_address returns correct value after init
- T002.2: context_address returns correct value when set
- T002.3: context_address returns zero when None passed

#### T003: MetagameComponent Game Registration Tests
- T003.1: assert_game_registered succeeds for registered game
- T003.2: assert_game_registered reverts for unregistered game
- T003.3: assert_game_registered with zero addresses

#### T004: MetagameComponent Mint Tests - No Context
- T004.1: Mint with all parameters as None except required (to)
- T004.2: Mint with all parameters provided
- T004.3: Mint with soulbound = true
- T004.4: Mint with soulbound = false

#### T005: MetagameComponent Mint Tests - With Context
- T005.1: Mint with context when context_address supports IMetagameContext
- T005.2: Mint with context when caller supports IMetagameContext (no context_address)
- T005.3: Revert when context provided but no support from either
- T005.4: Revert when context_address is non-zero but doesn't support interface

#### T006: ContextComponent Tests
- T006.1: Initialize and verify interface registration
- T006.2: Verify IMETAGAME_CONTEXT_ID is registered

#### T007: Library Function Tests
- T007.1: libs::assert_game_registered success case
- T007.2: libs::assert_game_registered failure case
- T007.3: libs::mint delegation verification

## 4. Fuzz & Property-Based Tests

### Properties and Invariants

#### P001: State Immutability Properties
- P001.1: minigame_token_address never changes after initialization
- P001.2: context_address never changes after initialization
- P001.3: SRC5 interfaces remain registered

#### P002: Context Validation Properties
- P002.1: If context provided, validation always occurs
- P002.2: Validation logic is deterministic for same inputs
- P002.3: Zero addresses handled consistently

### Fuzzing Strategies

#### F001: Address Fuzzing
- Domain: Random 252-bit felts as ContractAddresses
- Special values: 0, 1, MAX_FELT252
- Corpus: Known contract addresses from deployment

#### F002: Mint Parameter Fuzzing
- `game_address`: Random addresses, Some/None variations
- `player_name`: Random ByteArrays (0-1000 chars)
- `settings_id`: Full u32 range
- `start/end`: Full u64 range, ensure start <= end
- `objective_ids`: Random Span<u32> (0-100 elements)
- `context`: Random GameContextDetails with nested arrays
- `client_url`: Random URLs and invalid strings
- `renderer_address`: Random addresses
- `to`: Never zero (required parameter)
- `soulbound`: Random bool

#### F003: Negative Fuzzing
- Invalid interface IDs for SRC5 checks
- Addresses that report false for interface support
- Overlapping/invalid time ranges (end < start)
- Extremely large arrays for objectives
- Malformed GameContextDetails

### Invariant Testing Harnesses

#### I001: Sequential Operations Harness
```
1. Initialize component
2. Perform N random operations (reads, mints)
3. Verify: addresses unchanged, interfaces still supported
```

#### I002: Context Validation Harness
```
1. Setup various context configurations
2. Attempt mints with random parameters
3. Verify: validation behavior is consistent
```

## 5. Integration & Scenario Tests

### IS001: Complete Game Setup Flow
1. Deploy mock token contract with game registration
2. Deploy mock context contract with IMetagameContext
3. Initialize MetagameComponent with both addresses
4. Verify SRC5 interface support
5. Register a game in token contract
6. Mint token with full context
7. Verify token minted with correct parameters

### IS002: Context Support Variations
1. **Scenario A**: Context address supports interface
   - Initialize with context address
   - Mint with context → Success
2. **Scenario B**: Caller supports interface
   - Initialize without context address
   - Ensure caller implements IMetagameContext
   - Mint with context → Success
3. **Scenario C**: No context support
   - Initialize without context support
   - Mint with context → Revert

### IS003: Multi-Game Registration Flow
1. Deploy token contract
2. Register 3 different games
3. Initialize MetagameComponent
4. Verify each game via assert_game_registered
5. Mint tokens for each game
6. Verify correct game isolation

### IS004: Error Propagation Tests
1. Unregistered game mint attempt → Revert
2. Invalid context configuration → Revert
3. Token contract reverting → Propagated revert

### IS005: Upgrade/Migration Scenario
1. Deploy V1 with basic setup
2. Mint several tokens
3. Verify state consistency
4. Test with different context configurations

## 6. Coverage Matrix

| Function | Unit-Happy | Unit-Revert | Fuzz | Property | Integration | Gas/Event |
|----------|------------|-------------|------|----------|-------------|-----------|
| **MetagameComponent** | | | | | | |
| minigame_token_address() | T002.1 | - | F001 | P001.1 | IS001 | - |
| context_address() | T002.2,T002.3 | - | F001 | P001.2 | IS001 | - |
| initializer() | T001.1,T001.2 | - | F001 | P001.3 | IS001 | - |
| register_src5_interfaces() | T001.3 | - | - | P001.3 | IS001 | - |
| assert_game_registered() | T003.1 | T003.2 | F001 | - | IS003 | - |
| mint() | T004.1-4,T005.1-2 | T005.3-4 | F002 | P002.1-3 | IS001-4 | - |
| **ContextComponent** | | | | | | |
| initializer() | T006.1 | - | - | P001.3 | IS002 | - |
| register_context_interface() | T006.2 | - | - | P001.3 | IS002 | - |
| **libs** | | | | | | |
| assert_game_registered() | T007.1 | T007.2 | F001 | - | IS003 | - |
| mint() | T007.3 | - | F002 | - | IS001 | - |

## 7. Tooling & Environment

### Frameworks
- **Scarb**: v2.10.1 - Cairo package manager and compiler
- **Starknet Foundry (snforge)**: v0.45.0 - Testing framework
- **Dojo (sozo)**: v1.5.1 - Optional for game-specific tests

### Required Mocks
```
mocks/
├── mock_minigame_token.cairo
│   ├── IMinigameTokenDispatcher
│   └── IMinigameTokenMultiGameDispatcher
├── mock_context.cairo
│   └── IMetagameContext implementation
└── mock_src5.cairo
    └── ISRC5Dispatcher implementation
```

### Coverage Measurement
```bash
# Run all tests with coverage
snforge test --coverage

# Generate coverage report
snforge coverage-report

# Required thresholds
# - Line coverage: 100%
# - Branch coverage: 100%
# - Function coverage: 100%
```

### Test Organization
```
tests/
├── unit/
│   ├── test_metagame_component.cairo
│   ├── test_context_component.cairo
│   └── test_libs.cairo
├── integration/
│   ├── test_game_setup.cairo
│   ├── test_context_scenarios.cairo
│   └── test_multi_game.cairo
├── fuzz/
│   ├── fuzz_addresses.cairo
│   ├── fuzz_mint_parameters.cairo
│   └── fuzz_invariants.cairo
└── mocks/
    └── [mock files]
```

### Naming Conventions
- Unit tests: `test_[component]_[function]_[scenario]`
- Integration tests: `test_integration_[scenario]`
- Fuzz tests: `fuzz_[component]_[property]`
- Property tests: `test_property_[invariant]`

### Environment Setup
```toml
# Scarb.toml test dependencies
[dev-dependencies]
snforge_std = "0.45.0"
game_components_token = { path = "../token" }

[[target.starknet-contract]]
sierra = true
casm = true

[profile.dev.cairo]
unstable-add-statements-code-locations = true
unstable-add-statements-functions-debug-info = true
```

## 8. Self-Audit

### Branch Coverage Verification
- ✓ MetagameComponent::initializer Option branching (Some/None)
- ✓ MetagameComponent::mint context Option branching
- ✓ MetagameComponent::mint context_address.is_zero() branch
- ✓ All Option parameter variations in mint

### Assertion Coverage Verification
- ✓ "Game is not registered" - libs::assert_game_registered
- ✓ "Metagame: Context contract does not support IMetagameContext"
- ✓ "Metagame: Caller does not support IMetagameContext"

### Event Coverage Verification
- No events found in contracts - N/A

### Discrepancies
- None

All functions, branches, and assertions have corresponding test cases. The test plan provides comprehensive coverage for achieving 100% behavioral, branch, and assertion coverage.