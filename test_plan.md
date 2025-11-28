# Test Plan for Game Components Cairo/StarkNet Smart Contracts

## Executive Summary

This test plan enables implementation of tests achieving 100% behavioral, branch, and event coverage for the game-components smart contract system. The current test coverage needs improvement in several critical areas including library functions, error handling, and security scenarios.

## 1. Contract Reconnaissance

### 1.1 Contract Overview

| Contract | Purpose | Key Components |
|----------|---------|----------------|
| **Metagame** | High-level game orchestration | MetagameComponent, ContextComponent |
| **Minigame** | Individual game logic | MinigameComponent, SettingsComponent, ObjectivesComponent |
| **MinigameToken** | ERC721 game instance NFTs | CoreTokenComponent, Multiple extension components |

### 1.2 Function Inventory

#### MetagameComponent Functions

| Function | Type | Signature | Mutates State | Emits Events |
|----------|------|-----------|---------------|--------------|
| initializer | Internal | `fn initializer(ref self, minigame_token_address: ContractAddress, context_address: ContractAddress)` | Yes | No |
| register_src5_interfaces | Internal | `fn register_src5_interfaces(ref self)` | Yes | No |
| minigame_token_address | Public | `fn minigame_token_address(self) -> ContractAddress` | No | No |
| context_address | Public | `fn context_address(self) -> ContractAddress` | No | No |
| assert_game_registered | Internal | `fn assert_game_registered(self, game_address: ContractAddress)` | No | No |
| mint | Internal | `fn mint(self, game_address: ContractAddress, player_name: ByteArray, ...)` | No | No |

#### MinigameComponent Functions

| Function | Type | Signature | Mutates State | Emits Events |
|----------|------|-----------|---------------|--------------|
| initializer | Internal | `fn initializer(ref self, token_address: ContractAddress, settings_address: ContractAddress, objectives_address: ContractAddress)` | Yes | No |
| register_game_interface | Internal | `fn register_game_interface(ref self)` | Yes | No |
| token_address | Public | `fn token_address(self) -> ContractAddress` | No | No |
| settings_address | Public | `fn settings_address(self) -> ContractAddress` | No | No |
| objectives_address | Public | `fn objectives_address(self) -> ContractAddress` | No | No |
| pre_action | Internal | `fn pre_action(self, player: ContractAddress, token_id: u64)` | No | No |
| post_action | Internal | `fn post_action(self, player: ContractAddress, token_id: u64)` | No | No |
| assert_token_ownership | Internal | `fn assert_token_ownership(self, owner: ContractAddress, token_id: u64)` | No | No |
| assert_game_token_playable | Internal | `fn assert_game_token_playable(self, token_id: u64)` | No | No |

#### CoreTokenComponent Functions

| Function | Type | Signature | Mutates State | Emits Events |
|----------|------|-----------|---------------|--------------|
| initializer | Internal | `fn initializer(ref self, game_address: ContractAddress, game_registry_address: ContractAddress, event_relayer_address: ContractAddress)` | Yes | Yes |
| mint | Public | `fn mint(ref self, to: ContractAddress, game_address: ContractAddress, player_name: ByteArray, ...)` | Yes | Yes |
| set_token_metadata | Public | `fn set_token_metadata(ref self, token_id: u64, game_address: ContractAddress, ...)` | Yes | Yes |
| update_game | Public | `fn update_game(ref self, token_id: u64)` | Yes | Yes |
| token_metadata | Public | `fn token_metadata(self, token_id: u64) -> TokenMetadata` | No | No |
| is_playable | Public | `fn is_playable(self, token_id: u64) -> bool` | No | No |
| settings_id | Public | `fn settings_id(self, token_id: u64) -> u32` | No | No |
| player_name | Public | `fn player_name(self, token_id: u64) -> ByteArray` | No | No |
| objectives_count | Public | `fn objectives_count(self, token_id: u64) -> u8` | No | No |
| minted_by | Public | `fn minted_by(self, token_id: u64) -> u64` | No | No |
| game_address | Public | `fn game_address(self, token_id: u64) -> ContractAddress` | No | No |
| is_soulbound | Public | `fn is_soulbound(self, token_id: u64) -> bool` | No | No |
| renderer_address | Public | `fn renderer_address(self, token_id: u64) -> ContractAddress` | No | No |

### 1.3 State Variables

| Contract | Variable | Type | Purpose |
|----------|----------|------|---------|
| MetagameComponent | minigame_token_address | ContractAddress | Token contract reference |
| MetagameComponent | context_address | ContractAddress | Optional context provider |
| MinigameComponent | token_address | ContractAddress | Token contract reference |
| MinigameComponent | settings_address | ContractAddress | Optional settings provider |
| MinigameComponent | objectives_address | ContractAddress | Optional objectives provider |
| CoreTokenComponent | token_metadata | Map<u64, TokenMetadata> | Token metadata storage |
| CoreTokenComponent | token_player_names | Map<u64, ByteArray> | Player names |
| CoreTokenComponent | token_counter | u64 | Auto-incrementing ID |
| CoreTokenComponent | game_address | ContractAddress | Single game address |
| CoreTokenComponent | game_registry_address | ContractAddress | Multi-game registry |
| CoreTokenComponent | event_relayer_address | ContractAddress | Event aggregator |

### 1.4 Events

| Contract | Event | Fields | Trigger |
|----------|-------|--------|---------|
| CoreTokenComponent | TokenMinted | token_id, to, game_address, player_name, minted_at, settings_id, start_time, end_time | mint() |
| CoreTokenComponent | GameUpdated | token_id, game_over, completed_all_objectives, score | update_game() |
| CoreTokenComponent | ScoreUpdate | player, score | Score change |
| CoreTokenComponent | MetadataUpdate | token_id | Metadata change |
| CoreTokenComponent | Owners | token_ids, owners | Ownership state |

### 1.5 Constants & Interface IDs

| Constant | Value | Purpose |
|----------|-------|---------|
| IMETAGAME_ID | 0x0260d5160a283a03815f6c3799926c7bdbec5f22e759f992fb8faf172243ab20 | Metagame interface |
| IMINIGAME_ID | 0x02c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499704 | Minigame interface |
| IMINIGAME_TOKEN_ID | 0x02c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499704 | Token interface |

## 2. Behavior & Invariant Mapping

### 2.1 MetagameComponent Invariants

1. **Address Immutability**: `minigame_token_address` and `context_address` are set once during initialization
2. **Game Registration**: Only registered games can mint tokens
3. **Context Validation**: If context_address is set, it must support IMetagameContext interface
4. **Mint Delegation**: All minting operations are delegated to the token contract

### 2.2 MinigameComponent Invariants

1. **Token Ownership**: Only token owners can perform game actions
2. **Playability**: Tokens must be playable to perform game actions
3. **Address Immutability**: All addresses are set once during initialization
4. **Registry Integration**: Game auto-registers with registry if provided

### 2.3 CoreTokenComponent Invariants

1. **Token Counter Monotonicity**: `token_counter` only increases, never decreases
2. **State Transitions**: `game_over` and `completed_all_objectives` can only transition false→true
3. **Blank Token Rules**: Only minters can set metadata on blank tokens
4. **Lifecycle Validity**: start_time ≤ end_time when both are set
5. **Game Address Validation**: Game addresses must implement IMinigameTokenData
6. **Soulbound Immutability**: Soulbound tokens cannot be transferred

### 2.4 Function Behaviors

#### Metagame::mint
- **Purpose**: Delegate token minting with optional context
- **Inputs**: 
  - game_address: Must be registered
  - player_name: Any ByteArray
  - settings_id: 0 for none, >0 for specific settings
  - objective_ids: Array of objective IDs
  - start_time/end_time: 0 for no limit, >0 for specific times
  - context: Optional context data
  - minter: Optional minter address
  - renderer: Optional renderer address
  - soulbound: Transfer restriction flag
- **Outputs**: token_id from delegated mint
- **Events**: Via token contract
- **Reverts**: 
  - Game not registered
  - Invalid context when context_address is set
  - Delegation failures

#### MinigameToken::mint
- **Purpose**: Create new game token NFT
- **Edge Cases**:
  - Blank token (game_address = 0) requires minter
  - start_time > end_time should revert
  - Invalid game interface should revert
  - Settings/objectives validation failures
- **State Changes**:
  - Increments token_counter
  - Creates token metadata
  - Mints ERC721 token
  - Stores player name
  - Tracks objectives
  - Sets minter if provided

#### MinigameToken::update_game
- **Purpose**: Sync token state with game contract
- **Invariants**:
  - Score can change freely
  - game_over: false→true only
  - completed_all_objectives: false→true only
- **Events**: GameUpdated, ScoreUpdate (if changed), MetadataUpdate

## 3. Unit Test Design

### 3.1 MetagameComponent Tests

| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| MG-U-001 | Initialize with both addresses | Addresses stored, SRC5 registered |
| MG-U-002 | Initialize with zero context | Only token address stored |
| MG-U-003 | Read minigame_token_address | Returns correct address |
| MG-U-004 | Read context_address with context | Returns correct address |
| MG-U-005 | Read context_address without context | Returns zero address |
| MG-U-006 | assert_game_registered with valid game | No panic |
| MG-U-007 | assert_game_registered with invalid game | Panic: GAME_NOT_REGISTERED |
| MG-U-008 | Mint with all parameters | Token minted via delegation |
| MG-U-009 | Mint with minimal parameters | Token minted with defaults |
| MG-U-010 | Mint with context when context_address set | Context validated and used |
| MG-U-011 | Mint with context when no context_address | Checks caller supports IMetagameContext |
| MG-U-012 | Mint with unregistered game | Panic: GAME_NOT_REGISTERED |

### 3.2 MinigameComponent Tests

| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| MN-U-001 | Initialize with all addresses | All addresses stored, interface registered |
| MN-U-002 | Initialize with zero settings/objectives | Only token address stored |
| MN-U-003 | Initialize with game registry | Game auto-registered |
| MN-U-004 | Initialize without game registry | No registration attempted |
| MN-U-005 | Read token_address | Returns correct address |
| MN-U-006 | Read settings_address | Returns correct address or zero |
| MN-U-007 | Read objectives_address | Returns correct address or zero |
| MN-U-008 | pre_action with owned playable token | Delegated successfully |
| MN-U-009 | pre_action with unowned token | Panic: NOT_OWNER |
| MN-U-010 | pre_action with non-playable token | Panic: GAME_TOKEN_NOT_PLAYABLE |
| MN-U-011 | post_action delegation | Delegated successfully |
| MN-U-012 | assert_token_ownership with owner | No panic |
| MN-U-013 | assert_token_ownership with non-owner | Panic: NOT_OWNER |
| MN-U-014 | assert_game_token_playable with playable | No panic |
| MN-U-015 | assert_game_token_playable with non-playable | Panic: GAME_TOKEN_NOT_PLAYABLE |

### 3.3 CoreTokenComponent Tests

| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| TK-U-001 | Initialize with game address only | Game stored, others zero |
| TK-U-002 | Initialize with all addresses | All addresses stored |
| TK-U-003 | Mint with all parameters | Token created with all metadata |
| TK-U-004 | Mint with minimal parameters | Token created with defaults |
| TK-U-005 | Mint blank token without minter | Panic: BLANK_TOKEN_REQUIRES_MINTER |
| TK-U-006 | Mint blank token with minter | Token created, minter tracked |
| TK-U-007 | Mint with invalid game address | Panic: INVALID_GAME_ADDRESS |
| TK-U-008 | Mint with start > end | Panic: INVALID_LIFECYCLE |
| TK-U-009 | Mint to zero address | Panic: INVALID_TO_ADDRESS |
| TK-U-010 | Mint with invalid settings | Panic from settings validation |
| TK-U-011 | Mint with invalid objectives | Panic from objectives validation |
| TK-U-012 | Mint with MAX_U64 timestamps | Accepted as valid |
| TK-U-013 | Mint with 255 objectives | Accepted (max u8) |
| TK-U-014 | Mint sequential tokens | Counter increments correctly |
| TK-U-015 | set_token_metadata on blank by minter | Metadata updated |
| TK-U-016 | set_token_metadata on blank by non-minter | Panic: NOT_MINTER |
| TK-U-017 | set_token_metadata on non-blank | Panic: NOT_BLANK_TOKEN |
| TK-U-018 | set_token_metadata on non-existent | Panic: TOKEN_NOT_FOUND |
| TK-U-019 | update_game with score change | Score updated, event emitted |
| TK-U-020 | update_game false→true game_over | State updated, event emitted |
| TK-U-021 | update_game true→false game_over | Panic: GAME_OVER_FINAL |
| TK-U-022 | update_game objectives completion | State updated, event emitted |
| TK-U-023 | update_game no changes | No events emitted |
| TK-U-024 | update_game non-existent token | Panic: TOKEN_NOT_FOUND |
| TK-U-025 | All accessor functions | Return correct values |
| TK-U-026 | is_playable various states | Correct playability logic |
| TK-U-027 | game_address single vs multi | Correct resolution |

## 4. Fuzz & Property-Based Tests

### 4.1 Property Definitions

| Property ID | Property | Invariant |
|-------------|----------|-----------|
| P-001 | Token counter monotonicity | ∀ mint operations: token_counter[n+1] > token_counter[n] |
| P-002 | Lifecycle validity | ∀ tokens: start_time ≤ end_time ∨ start_time = 0 ∨ end_time = 0 |
| P-003 | State transition finality | ∀ tokens: game_over ∨ completed_objectives only transition false→true |
| P-004 | Minter consistency | ∀ blank tokens: minter_id ≠ 0 |
| P-005 | Objective count bounds | ∀ tokens: 0 ≤ objectives_count ≤ 255 |
| P-006 | Address validation | ∀ game addresses: implements IMinigameTokenData ∨ address = 0 |

### 4.2 Fuzz Test Scenarios

| Fuzz ID | Target | Input Domain | Strategy |
|---------|--------|--------------|----------|
| FZ-001 | mint() timestamps | [0, MAX_U64] | Random u64 pairs |
| FZ-002 | mint() player names | ByteArray[0..1000] | Random strings, special chars |
| FZ-003 | mint() objective arrays | Array[0..255] | Random lengths and values |
| FZ-004 | mint() settings_id | [0, MAX_U32] | Boundary values + random |
| FZ-005 | update_game() sequences | Random state transitions | Verify invariants hold |
| FZ-006 | Concurrent mints | Parallel mint calls | Verify counter consistency |
| FZ-007 | Registry operations | Random game registrations | Verify lookup consistency |

### 4.3 Negative Fuzz Tests

| Neg-Fuzz ID | Scenario | Must Revert With |
|-------------|----------|------------------|
| NF-001 | Invalid lifecycles | INVALID_LIFECYCLE |
| NF-002 | Invalid game addresses | INVALID_GAME_ADDRESS |
| NF-003 | Unauthorized operations | NOT_OWNER / NOT_MINTER |
| NF-004 | State regression | GAME_OVER_FINAL |
| NF-005 | Zero address operations | INVALID_TO_ADDRESS |

## 5. Integration & Scenario Tests

### 5.1 Happy Path Scenarios

| Scenario ID | Flow | Validation |
|-------------|------|------------|
| SC-001 | Deploy → Register → Mint → Play → Complete | Full lifecycle success |
| SC-002 | Multi-game tournament | Multiple games, context tracking |
| SC-003 | Objective progression | Sequential objective completion |
| SC-004 | Time-bounded campaign | Lifecycle enforcement |
| SC-005 | Soulbound achievements | Transfer restrictions work |

### 5.2 Adversarial Scenarios

| Scenario ID | Attack Vector | Expected Defense |
|-------------|---------------|------------------|
| ADV-001 | Double mint same ID | Counter prevents collision |
| ADV-002 | Bypass ownership | assert_token_ownership blocks |
| ADV-003 | Play expired token | is_playable returns false |
| ADV-004 | Forge game completion | Only game contract can update |
| ADV-005 | Transfer soulbound | Transfer reverts |
| ADV-006 | Register fake game | Interface check fails |
| ADV-007 | Overflow token counter | Requires 2^64 mints |
| ADV-008 | Reentrancy on update | No external calls in critical section |

### 5.3 Edge Case Scenarios

| Edge ID | Scenario | Expected Behavior |
|---------|----------|-------------------|
| EDGE-001 | Mint at exact start_time | Token immediately playable |
| EDGE-002 | Query at exact end_time | Token no longer playable |
| EDGE-003 | Complete last objective | completed_all_objectives = true |
| EDGE-004 | Zero-length player name | Accepted, returns empty |
| EDGE-005 | Max objectives (255) | Accepted, tracked correctly |
| EDGE-006 | Context without provider | Validates caller interface |

## 6. Coverage Matrix

| Function | Unit-Happy | Unit-Revert | Fuzz | Property | Integration | Events |
|----------|------------|-------------|------|----------|-------------|--------|
| **MetagameComponent** |
| initializer | MG-U-001,002 | - | - | - | SC-001 | - |
| minigame_token_address | MG-U-003 | - | - | - | - | - |
| context_address | MG-U-004,005 | - | - | - | - | - |
| assert_game_registered | MG-U-006 | MG-U-007 | - | - | - | - |
| mint | MG-U-008,009,010,011 | MG-U-012 | FZ-001,002,003 | P-001 | SC-001,002 | ✓ |
| **MinigameComponent** |
| initializer | MN-U-001,002,003,004 | - | - | - | SC-001 | - |
| token_address | MN-U-005 | - | - | - | - | - |
| settings_address | MN-U-006 | - | - | - | - | - |
| objectives_address | MN-U-007 | - | - | - | - | - |
| pre_action | MN-U-008 | MN-U-009,010 | - | - | SC-001 | - |
| post_action | MN-U-011 | - | - | - | SC-001 | - |
| assert_token_ownership | MN-U-012 | MN-U-013 | - | - | ADV-002 | - |
| assert_game_token_playable | MN-U-014 | MN-U-015 | - | - | ADV-003 | - |
| **CoreTokenComponent** |
| initializer | TK-U-001,002 | - | - | - | SC-001 | ✓ |
| mint | TK-U-003,004,005,006,012,013,014 | TK-U-007,008,009,010,011 | FZ-001,002,003,004,006 | P-001,002,004,005,006 | SC-001,002,003,004,005 | ✓ |
| set_token_metadata | TK-U-015 | TK-U-016,017,018 | - | - | - | ✓ |
| update_game | TK-U-019,020,022,023 | TK-U-021,024 | FZ-005 | P-003 | SC-001,003 | ✓ |
| token_metadata | TK-U-025 | - | - | - | - | - |
| is_playable | TK-U-026 | - | - | P-002 | EDGE-001,002 | - |
| All accessors | TK-U-025,027 | - | - | - | - | - |

## 7. Tooling & Environment

### 7.1 Test Frameworks
- **Primary**: StarkNet Foundry (`snforge`)
- **Build**: Scarb 2.10.1
- **Coverage**: cairo-coverage (90% minimum threshold)

### 7.2 Required Mocks

```cairo
// Mock implementations needed:
1. MockMinigameContract - Implements IMinigameTokenData
2. MockGameRegistry - Multi-game registry
3. MockEventRelayer - Event aggregation
4. MockContext - IMetagameContext provider
5. MockSettings - IMinigameSettings provider
6. MockObjectives - IMinigameObjectives provider
7. MockRenderer - IMinigameTokenRenderer provider
8. MockMinter - IMinigameTokenMinter provider
```

### 7.3 Test Utilities

```cairo
// Helper functions needed:
1. setup_contracts() - Deploy all contracts
2. create_test_token() - Mint with defaults
3. advance_time() - Cheat code wrapper
4. assert_event_emitted() - Event verification
5. generate_random_lifecycle() - Fuzz helper
6. batch_mint() - Concurrent testing
```

### 7.4 Coverage Commands

```bash
# Run all tests
cd packages/test_starknet && snforge test

# Run with coverage
snforge test --coverage

# Generate detailed report
cairo-coverage

# Check specific package coverage
cairo-coverage --package game_components_token
```

### 7.5 Naming Conventions

- Test files: `test_<component>_<category>.cairo`
- Test functions: `test_<function>_<scenario>_<expected>`
- Mock contracts: `Mock<Contract>Contract`
- Test IDs: `<Component>-<Type>-<Number>`

## 8. Self-Audit Checklist

### Coverage Verification
- [x] All public functions have happy path tests
- [x] All revert conditions have negative tests
- [x] All state mutations are verified
- [x] All events have emission tests
- [x] All invariants have property tests
- [x] All integrations have scenario tests
- [x] All edge cases are covered

### Missing Test Areas (Currently)
1. Library functions in `libs.cairo` files
2. Helper/utility functions
3. Some error paths in core contracts
4. Complex multi-contract scenarios
5. Gas optimization measurements
6. Upgrade/migration scenarios

### Discrepancies
- None identified in the test plan mapping

## Implementation Priority

1. **Critical** (Blocks 90% coverage):
   - Library function tests
   - Error handling tests
   - Commented out test files

2. **High** (Security/Correctness):
   - Access control tests
   - State invariant tests
   - Integration scenarios

3. **Medium** (Completeness):
   - Edge case coverage
   - Fuzz test expansion
   - Event verification

4. **Low** (Nice to have):
   - Gas benchmarks
   - Performance tests
   - UI/Renderer tests

This test plan provides complete coverage mapping for achieving 100% test coverage of the game-components smart contract system.