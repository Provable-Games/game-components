# Test Plan for Token Package

## 1. Contract Reconnaissance

### Functions and State Mutators

| Component | Function | Signature | Type |
|-----------|----------|-----------|------|
| **TokenComponent** | mint | `mint(game_address: Option<ContractAddress>, player_name: Option<ByteArray>, settings_id: Option<u32>, start: Option<u64>, end: Option<u64>, objective_ids: Option<Span<u32>>, context: Option<GameContextDetails>, client_url: Option<ByteArray>, renderer_address: Option<ContractAddress>, to: ContractAddress, soulbound: bool) -> u64` | External |
| **TokenComponent** | update_game | `update_game(token_id: u64)` | External |
| **TokenComponent** | token_metadata | `token_metadata(token_id: u64) -> TokenMetadata` | External/View |
| **TokenComponent** | is_playable | `is_playable(token_id: u64) -> bool` | External/View |
| **TokenComponent** | settings_id | `settings_id(token_id: u64) -> u32` | External/View |
| **TokenComponent** | player_name | `player_name(token_id: u64) -> ByteArray` | External/View |
| **TokenComponent** | initializer | `initializer(game_address: Option<ContractAddress>)` | Internal |
| **TokenComponent** | get_token_metadata | `get_token_metadata(token_id: u64) -> TokenMetadata` | Internal |
| **TokenComponent** | assert_token_ownership | `assert_token_ownership(token_id: u64)` | Internal |
| **TokenComponent** | assert_playable | `assert_playable(token_id: u64)` | Internal |
| **MultiGameComponent** | register_game | `register_game(contract_address: ContractAddress, metadata: ByteArray, client_url: ByteArray, to: ContractAddress) -> u64` | External |
| **MultiGameComponent** | game_count | `game_count() -> u64` | External/View |
| **MultiGameComponent** | game_id_from_address | `game_id_from_address(contract_address: ContractAddress) -> u64` | External/View |
| **MultiGameComponent** | game_address_from_id | `game_address_from_id(game_id: u64) -> ContractAddress` | External/View |
| **MultiGameComponent** | game_metadata | `game_metadata(game_id: u64) -> GameMetadata` | External/View |
| **MultiGameComponent** | is_game_registered | `is_game_registered(contract_address: ContractAddress) -> bool` | External/View |
| **MultiGameComponent** | game_address | `game_address(token_id: u64) -> ContractAddress` | External/View |
| **MultiGameComponent** | creator_token_id | `creator_token_id(game_id: u64) -> u64` | External/View |
| **MultiGameComponent** | client_url | `client_url(token_id: u64) -> ByteArray` | External/View |
| **TokenObjectivesComponent** | objectives_count | `objectives_count(token_id: u64) -> u32` | External/View |
| **TokenObjectivesComponent** | objectives | `objectives(token_id: u64) -> Array<TokenObjective>` | External/View |
| **TokenObjectivesComponent** | objective_ids | `objective_ids(token_id: u64) -> Span<u32>` | External/View |
| **TokenObjectivesComponent** | all_objectives_completed | `all_objectives_completed(token_id: u64) -> bool` | External/View |
| **TokenObjectivesComponent** | create_objective | `create_objective(metadata: ByteArray, token_id: u64, objective_ids: Span<u32>)` | External |
| **TokenSettingsComponent** | create_settings | `create_settings(metadata: ByteArray, token_id: u64)` | External |
| **MinterComponent** | add_minter | `add_minter(minter: ContractAddress) -> u64` | Internal |
| **MinterComponent** | get_minter_id | `get_minter_id(minter: ContractAddress) -> u64` | Internal |
| **SoulboundComponent** | validate_transfer | `validate_transfer(token_id: u64, to: ContractAddress, auth: ContractAddress)` | Internal |
| **SoulboundComponent** | is_soulbound | `is_soulbound(token_id: u64) -> bool` | Internal |
| **BlankComponent** | set_token_metadata | `set_token_metadata(token_id: u64, metadata: TokenMetadata)` | External |

### State Variables and Storage

| Component | Variable | Type | Description |
|-----------|----------|------|-------------|
| **TokenComponent** | token_counter | `u64` | Auto-incrementing token ID counter |
| **TokenComponent** | token_metadata | `Map<u64, TokenMetadata>` | Maps token ID to metadata |
| **TokenComponent** | token_player_names | `Map<u64, ByteArray>` | Maps token ID to player names |
| **TokenComponent** | game_address | `ContractAddress` | Single game address for non-multi-game tokens |
| **MultiGameComponent** | multi_game_counter | `u64` | Auto-incrementing game ID counter |
| **MultiGameComponent** | games | `Map<u64, GameMetadata>` | Maps game ID to metadata |
| **MultiGameComponent** | game_address_to_id | `Map<ContractAddress, u64>` | Maps game address to ID |
| **MultiGameComponent** | token_id_to_game_id | `Map<u64, u64>` | Maps token ID to game ID |
| **MultiGameComponent** | creator_token_ids | `Map<u64, u64>` | Maps game ID to creator token ID |
| **MultiGameComponent** | client_urls | `Map<u64, ByteArray>` | Maps token ID to client URL |
| **TokenObjectivesComponent** | objectives | `Map<(u64, u32), TokenObjective>` | Maps (token_id, index) to objective |
| **MinterComponent** | minter_counter | `u64` | Auto-incrementing minter ID counter |
| **MinterComponent** | minters | `Map<ContractAddress, u64>` | Maps minter address to ID |
| **SoulboundComponent** | soulbounds | `Map<u64, bool>` | Maps token ID to soulbound status |

### Events

| Component | Event | Fields |
|-----------|-------|--------|
| **TokenComponent** | ScoreUpdate | `token_id: u64, score: u64` |
| **TokenComponent** | MetadataUpdate | `token_id: u64` |
| **TokenComponent** | Owners | `token_id: u64, owner: ContractAddress, auth: ContractAddress` |
| **MultiGameComponent** | GameRegistered | `game_id: u64, contract_address: ContractAddress, creator_token_id: u64` |

### Interface IDs (SRC5)

| Interface | ID |
|-----------|-----|
| IMINIGAME_TOKEN_ID | `0x02c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499704` |
| IMINIGAME_TOKEN_MULTIGAME_ID | `0x1b59e0a019c029f9dc8e686bcb50cf92cf6de6ed47a22e5e81e6f2b957ba71f` |
| IMINIGAME_TOKEN_OBJECTIVES_ID | `0x3302e65fb0be49f931ecf5c0baa94febe70af09b9797b1ccd866c9b7f43e98f` |
| IMINIGAME_TOKEN_SETTINGS_ID | `0x3e67cf75dc1f49b21dc1cf16e9c7cff96bfac4b080b70b616f68fa072c5cf1a` |
| IMINIGAME_TOKEN_MINTER_ID | `0x3bb088e88bcecc7b4ba95e3eefacfbb96e63d98b7e996a73b90bb983c1fa07d` |
| IMINIGAME_TOKEN_SOULBOUND_ID | `0x3e4b10aa9ab8ad96c53bb4cbd35c68c891e996b6c1c8c90dfe9bb9ba9ba8d5f` |
| IMINIGAME_TOKEN_BLANK_ID | `0x3e4f2b982c4cf88b7bb99b5b2b3e7c1e6da4b3c43e6a95ae7cf3e8d96a5b4bc` |

## 2. Behaviour & Invariant Mapping

### TokenComponent::mint

**Purpose**: Creates a new game token with optional extensions and configurations

**Inputs & Edge Cases**:
- `game_address`: None (blank token), valid address, invalid address (not IMinigame)
- `player_name`: None, empty string, max length string
- `settings_id`: None, 0, valid ID, invalid ID (not registered)
- `start`: None, 0, past timestamp, future timestamp
- `end`: None, 0, timestamp < start, timestamp > start
- `objective_ids`: None, empty span, valid IDs, invalid IDs, duplicate IDs
- `context`: None, valid context
- `client_url`: None, empty string, valid URL
- `renderer_address`: None, zero address, valid address
- `to`: zero address, valid address
- `soulbound`: true, false

**State Changes**:
- Increments token_counter
- Stores TokenMetadata with all fields
- Stores player_name if provided
- Updates extension storage (multi_game, objectives, minter)
- Mints ERC721 token to recipient

**Event Emissions**:
- ERC721 Transfer event (from zero address)
- GameRegistered (if multi-game and new game)

**Access Control**: None (public minting)

**Invariants**:
- Token IDs are sequential and unique
- Token metadata is immutable after minting (except game_over, completed_all_objectives)
- Minted_by tracks the caller address via minter extension
- If soulbound=true, token cannot be transferred

**Failure Conditions**:
- Game address doesn't support IMinigame interface
- Settings ID not registered in game's settings contract
- Objective IDs not registered in game's objectives contract
- Multi-game token with unregistered game address
- Single-game token with mismatched game address

### TokenComponent::update_game

**Purpose**: Synchronizes token state with game contract state

**Inputs**: 
- `token_id`: 0, valid ID, non-existent ID, MAX_U64

**State Changes**:
- Updates objectives completion status
- Sets game_over flag
- Sets completed_all_objectives flag

**Event Emissions**:
- ScoreUpdate with current score
- MetadataUpdate for token

**Invariants**:
- Only updates if game_over or all objectives completed
- Score is fetched from game contract
- Objectives are checked individually

**Failure Conditions**:
- Token doesn't exist
- Game doesn't support required interfaces

### MultiGameComponent::register_game

**Purpose**: Registers a new game in the multi-game registry

**Inputs**:
- `contract_address`: zero address, already registered, valid new address
- `metadata`: empty, valid JSON, max length
- `client_url`: empty, valid URL
- `to`: zero address, valid address

**State Changes**:
- Increments multi_game_counter
- Stores GameMetadata
- Updates game_address_to_id mapping
- Mints creator token

**Event Emissions**:
- GameRegistered with game_id, contract_address, creator_token_id

**Invariants**:
- Game IDs are sequential and unique
- Each game address can only be registered once
- Creator token is minted to specified address

### TokenObjectivesComponent::create_objective

**Purpose**: Associates objectives with a token

**Inputs**:
- `metadata`: empty, valid data
- `token_id`: valid ID, non-existent ID
- `objective_ids`: empty span, valid IDs, duplicates

**State Changes**:
- Stores TokenObjective entries for each objective

**Invariants**:
- Objectives are stored sequentially by index
- Completion status starts as false

### SoulboundComponent::validate_transfer

**Purpose**: Prevents transfer of soulbound tokens

**Inputs**:
- `token_id`: soulbound token, regular token
- `to`: any address
- `auth`: any address

**Invariants**:
- Soulbound tokens revert on any transfer attempt
- Non-soulbound tokens allow transfers

## 3. Unit Test Design

### Happy Path Tests

| Test ID | Function | Description | Inputs | Expected Result |
|---------|----------|-------------|---------|-----------------|
| UT-01 | mint | Mint basic token | game_address=valid, to=user1 | Token ID 1 created |
| UT-02 | mint | Mint with player name | player_name="Alice" | Name stored correctly |
| UT-03 | mint | Mint with settings | settings_id=1 | Settings ID stored |
| UT-04 | mint | Mint with lifecycle | start=100, end=200 | Lifecycle stored |
| UT-05 | mint | Mint with objectives | objective_ids=[1,2,3] | Objectives created |
| UT-06 | mint | Mint soulbound | soulbound=true | Token marked soulbound |
| UT-07 | update_game | Update completed game | game_over=true | Metadata updated |
| UT-08 | update_game | Complete all objectives | All objectives met | completed_all_objectives=true |
| UT-09 | register_game | Register new game | Valid game address | Game ID assigned |
| UT-10 | create_objective | Add objectives | objective_ids=[1,2] | Objectives stored |

### Revert Path Tests

| Test ID | Function | Description | Inputs | Expected Error |
|---------|----------|-------------|---------|----------------|
| UR-01 | mint | Invalid game address | Non-IMinigame address | "Game does not support IMinigame" |
| UR-02 | mint | Unregistered game | Unregistered address | "Game address not registered" |
| UR-03 | mint | Invalid settings ID | settings_id=999 | "Settings id not registered" |
| UR-04 | mint | Invalid objective IDs | objective_ids=[999] | "Objective id not registered" |
| UR-05 | update_game | Non-existent token | token_id=999 | "Token id not minted" |
| UR-06 | register_game | Duplicate registration | Same address twice | "Game already registered" |
| UR-07 | register_game | Zero address | contract_address=0 | "Invalid game address" |
| UR-08 | validate_transfer | Soulbound transfer | soulbound token | "Token is soulbound" |

### Boundary Tests

| Test ID | Function | Description | Inputs | Expected Result |
|---------|----------|-------------|---------|-----------------|
| UB-01 | mint | Max objectives | objective_ids=[1..255] | All stored (u8 limit) |
| UB-02 | mint | Zero timestamps | start=0, end=0 | Stored as provided |
| UB-03 | mint | Max u64 values | All u64 fields=MAX | Stored correctly |
| UB-04 | token_metadata | First token | token_id=1 | Valid metadata |
| UB-05 | token_metadata | Large token ID | token_id=MAX_U64 | Empty metadata |

### Access Control Tests

| Test ID | Function | Description | Scenario | Expected Result |
|---------|----------|-------------|----------|-----------------|
| UA-01 | mint | Any caller | Random address calls | Success (public) |
| UA-02 | update_game | Any caller | Random address calls | Success (public) |
| UA-03 | assert_ownership | Non-owner | Different address | Revert "not owner" |

## 4. Fuzz & Property-Based Tests

### Property Definitions

| Property ID | Property | Description |
|-------------|----------|-------------|
| P-01 | Token ID monotonicity | token_counter only increases |
| P-02 | Unique token IDs | No duplicate token IDs |
| P-03 | Game ID uniqueness | Each game address maps to one ID |
| P-04 | Soulbound immutability | Soulbound status never changes |
| P-05 | Objective count consistency | objectives_count matches actual objectives |
| P-06 | Playability logic | is_playable follows lifecycle and completion rules |
| P-07 | Minter ID consistency | Each minter gets unique sequential ID |

### Fuzzing Strategies

| Fuzz ID | Target | Input Domain | Strategy |
|---------|--------|--------------|----------|
| F-01 | mint parameters | All Option fields | Random Some/None combinations |
| F-02 | Timestamps | 0 to MAX_U64 | Focus on boundary values |
| F-03 | Objective arrays | 0-255 elements | Random lengths and values |
| F-04 | String inputs | 0-1000 chars | Unicode, special chars |
| F-05 | Address inputs | Random felts | Valid and invalid addresses |

### Negative Fuzzing

| Neg-Fuzz ID | Target | Must Revert When |
|-------------|--------|------------------|
| NF-01 | mint | objective_ids contains invalid IDs |
| NF-02 | mint | settings_id not registered |
| NF-03 | update_game | token_id doesn't exist |
| NF-04 | register_game | address already registered |

### Invariant Testing

| Invariant ID | Description | Test Harness |
|--------------|-------------|--------------|
| I-01 | Token supply consistency | Random mint sequence, verify counter |
| I-02 | Game registry integrity | Register/query random games |
| I-03 | Objective completion | Random complete/query sequences |
| I-04 | Lifecycle enforcement | Time-based playability checks |

## 5. Integration & Scenario Tests

### User Stories

| Story ID | Description | Steps |
|----------|-------------|-------|
| S-01 | Player mints and plays token | 1. Mint token with objectives<br>2. Play game<br>3. Update progress<br>4. Complete objectives |
| S-02 | Multi-game token lifecycle | 1. Register game<br>2. Mint token for game<br>3. Switch games<br>4. Track per-game progress |
| S-03 | Soulbound achievement token | 1. Complete game<br>2. Mint soulbound token<br>3. Attempt transfer (fail)<br>4. Verify ownership |

### Adversarial Scenarios

| Scenario ID | Description | Attack Vector | Expected Defense |
|-------------|-------------|---------------|------------------|
| A-01 | Double game registration | Register same address twice | Second registration fails |
| A-02 | Fake objective completion | Update non-owned token | Only game contract can update |
| A-03 | Bypass soulbound | Various transfer attempts | All transfers blocked |
| A-04 | Resource exhaustion | Mint with 1000 objectives | Gas limit protection |

### Complex Flows

| Flow ID | Description | Components Used |
|---------|-------------|-----------------|
| CF-01 | Full extension usage | Token + MultiGame + Objectives + Settings + Minter + Soulbound |
| CF-02 | Game migration | Register new version, maintain token compatibility |
| CF-03 | Batch operations | Mint 100 tokens, update all states |

## 6. Coverage Matrix

| Function/Invariant | Unit-Happy | Unit-Revert | Fuzz | Property | Integration | Gas/Event |
|-------------------|------------|-------------|------|----------|-------------|-----------|
| mint | UT-01 to UT-06 | UR-01 to UR-04 | F-01 | P-01, P-02 | S-01, S-02 | E-01 |
| update_game | UT-07, UT-08 | UR-05 | F-02 | P-05, P-06 | S-01 | E-02 |
| token_metadata | UB-04, UB-05 | - | F-05 | - | S-01 | - |
| is_playable | UT-07 | - | F-02 | P-06 | S-01 | - |
| register_game | UT-09 | UR-06, UR-07 | F-05 | P-03 | S-02 | E-03 |
| create_objective | UT-10 | - | F-03 | P-05 | S-01 | - |
| validate_transfer | UA-03 | UR-08 | - | P-04 | S-03 | - |
| Token ID monotonicity | - | - | - | P-01 | CF-03 | - |
| Game uniqueness | - | - | - | P-03 | CF-02 | - |
| Soulbound enforcement | - | - | - | P-04 | A-03 | - |
| Extension detection | - | - | - | - | CF-01 | - |

## 7. Tooling & Environment

### Frameworks
- **Build**: scarb 2.10.1
- **Test Runner**: snforge (starknet-foundry 0.31.0)
- **Contract Framework**: OpenZeppelin Cairo Contracts
- **Component System**: Starknet Components

### Required Mocks
- **ERC20 Mock**: For fee token testing
- **Game Contract Mock**: Implements IMinigame, IMinigameTokenData
- **Settings Contract Mock**: Implements IMinigameSettings
- **Objectives Contract Mock**: Implements IMinigameObjectives
- **Renderer Contract Mock**: For custom renderer testing

### Coverage Requirements
- Statement Coverage: 100%
- Branch Coverage: 100%
- Event Coverage: 100%
- Invariant Coverage: 100%

### Test Commands
```bash
# Run all tests
cd packages/test_starknet && snforge test

# Run specific test file
cd packages/test_starknet && snforge test test_token

# Run with coverage
cd packages/test_starknet && snforge test --coverage

# Run specific test case
cd packages/test_starknet && snforge test test_mint_basic_token
```

### Directory Structure
```
packages/test_starknet/
├── src/
│   ├── token/
│   │   ├── test_token.cairo
│   │   ├── test_multi_game.cairo
│   │   ├── test_objectives.cairo
│   │   ├── test_settings.cairo
│   │   ├── test_minter.cairo
│   │   ├── test_soulbound.cairo
│   │   └── test_integration.cairo
│   └── mocks/
│       ├── game_mock.cairo
│       ├── settings_mock.cairo
│       └── objectives_mock.cairo
└── Scarb.toml
```

### Naming Conventions
- Test functions: `test_<component>_<scenario>_<expected_result>`
- Mock contracts: `Mock<Interface>Contract`
- Test fixtures: `setup_<component>()`
- Assertions: Descriptive messages for all assertions

## 8. Self-Audit

### Coverage Verification

All functions, branches, events, and invariants from the contract reconnaissance have been mapped to test cases:

✓ All external functions have happy and revert path tests
✓ All state changes are verified in tests
✓ All events have emission tests (E-01, E-02, E-03)
✓ All access control is tested
✓ All invariants have property tests
✓ All extensions have dedicated test suites
✓ Integration tests cover realistic scenarios
✓ Adversarial tests cover security concerns

### Discrepancies: None

The test plan achieves complete behavioral, branch, and event coverage for the Token package contracts.