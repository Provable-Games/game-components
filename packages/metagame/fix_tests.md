# Fix Tests Guide for Metagame Test Suite

This document outlines the fixes needed to get all 49 failing tests working in the metagame test suite.

## Overview

All tests are currently failing due to issues with mock contracts and test setup. The tests compile successfully but fail at runtime due to mismatches between expected and actual behavior.

## Critical Issues to Fix

### 1. Constructor Parameter Order Mismatch

**Issue**: The `MockMetagameContract` constructor expects parameters in the wrong order compared to the `MetagameComponent` initializer.

**Current Mock Constructor**:
```cairo
fn constructor(
    ref self: ContractState,
    minigame_token_address: ContractAddress,
    context_address: Option<ContractAddress>,
    supports_context: bool,
) {
    self.metagame.initializer(context_address, minigame_token_address); // Correct order
}
```

**Actual MetagameComponent initializer signature**:
```cairo
fn initializer(
    ref self: ComponentState<TContractState>,
    context_address: Option<ContractAddress>,
    minigame_token_address: ContractAddress,
) {
    self.register_src5_interfaces();
    // ...
}
```

**Issue**: The mock constructor receives parameters in a different order than it passes to the initializer. The helper function `deploy_mock_metagame` is passing `minigame_token_address` first, but the initializer expects `context_address` first.

**Fix**: Update the constructor to match the parameter order expected by the component:
```cairo
fn constructor(
    ref self: ContractState,
    context_address: Option<ContractAddress>,
    minigame_token_address: ContractAddress,
    supports_context: bool,
) {
    self.metagame.initializer(context_address, minigame_token_address);
    // ...
}
```

OR update the deployment helper to pass parameters in the correct order.

### 2. Mock Context Implementation

**Issue**: The mock implementation returns hardcoded context data instead of storing/retrieving actual test data.

**Current Implementation**:
```cairo
fn context(self: @ContractState, token_id: u64) -> GameContextDetails {
    // Returns hardcoded data
    GameContextDetails {
        name: "Test Context",
        description: "Test Description",
        id: Option::Some(1),
        context: array![...].span(),
    }
}
```

**Fix**: Implement proper storage for context data or use snforge's mock capabilities:
- Use a more sophisticated storage approach
- Or implement proper mocking with `start_mock_call` for context data

### 3. Missing Mock Implementations

Several mock implementations need to be completed:

#### MockMinigameToken
- `is_game_registered`: Currently being mocked but needs proper implementation
- `mint`: Needs to return proper token IDs
- `game_metadata`: Required for some tests

#### MockContextContract
- Needs proper implementation of `supports_interface`
- Needs implementation of `has_context` and `context` methods

## Test-Specific Fixes

### Unit Tests

#### test_initialization.cairo
1. **test_initialize_with_zero_token_address**: 
   - Fix: Update the expected panic message to match actual error
   - Current: `'Calldata fail'`
   - Should match the actual deserialization error

2. **test_src5_interface_registration**:
   - Fix: Ensure SRC5 component is properly initialized in mock
   - Add missing interface registrations

#### test_game_registration.cairo
1. **All tests**: 
   - Fix: Implement proper `is_game_registered` mock responses
   - Ensure mock_once behavior works correctly

#### test_minting.cairo
1. **All mint tests**:
   - Fix: Implement proper token minting in mock
   - Return correct token IDs
   - Handle soulbound parameter correctly

#### test_context.cairo
1. **test_mint_with_context_no_support**:
   - Fix: Update expected panic message
   - Current: `'No IMetagameContext'`
   - Should match actual error from component

2. **test_external_context_no_interface**:
   - Fix: Update expected panic message
   - Current: `'Context no IMetagameContext'`

### Integration Tests

#### test_complete_flow.cairo
1. **All tests**:
   - Fix: Implement proper event emissions
   - Ensure mocks return consistent data

#### test_multi_game.cairo
1. **All tests**:
   - Fix: Implement proper multi-game token support
   - Ensure game isolation works correctly

#### test_adversarial.cairo
1. **All tests**:
   - Fix: Implement proper error handling
   - Add reentrancy protection checks

### Fuzz Tests

#### test_context_fuzz.cairo
1. **All fuzz tests**:
   - Fix: Handle edge cases for generated inputs
   - Ensure proper bounds checking

#### test_token_properties.cairo
1. **All fuzz tests**:
   - Fix: Implement proper invariant checks
   - Handle overflow scenarios correctly

## Implementation Strategy

1. **Start with Mock Fixes**:
   - Fix constructor parameter order (highest priority)
   - Implement proper mock storage
   - Add missing mock methods

2. **Update Expected Error Messages**:
   - Run each test individually to capture actual error messages
   - Update `#[should_panic(expected: ...)]` attributes

3. **Implement Proper Mocking**:
   - Use snforge's `start_mock_call` and `mock_call` for external calls
   - Implement stateful mocks where needed

4. **Add Event Verification**:
   - Use `spy_events` to verify event emissions
   - Add proper event assertions

## Testing Approach

1. Fix one test at a time, starting with the simplest:
   - `test_initialize_with_token_only`
   - `test_check_registered_game`
   - `test_basic_mint_without_context`

2. For each test:
   - Run with `SNFORGE_BACKTRACE=1` to see full error
   - Fix the immediate issue
   - Verify the fix doesn't break other tests

3. Group similar fixes:
   - All initialization tests
   - All minting tests
   - All context tests

## Example Fix Implementation

Here's an example of fixing the first test:

```cairo
// In mock_metagame_contract.cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    minigame_token_address: ContractAddress,
    context_address: Option<ContractAddress>,
    supports_context: bool,
) {
    // Fix: Correct parameter order
    self.metagame.initializer(minigame_token_address, context_address);
    
    if supports_context {
        self.src5.register_interface(IMETAGAME_CONTEXT_ID);
    }
}
```

## Priority Fixes

Based on the test failures, here's the recommended order of fixes:

1. **Fix Constructor Parameter Order** (affects ALL tests)
   - This is the root cause of the "Failed to deserialize param #3" error
   - Will immediately fix many initialization and basic tests

2. **Fix Mock Token Implementation**
   - Implement `is_game_registered` properly
   - Implement `mint` to return sequential token IDs
   - Affects all minting and game registration tests

3. **Fix Context Mock Implementation**
   - Store and retrieve actual context data
   - Implement proper `has_context` checks
   - Affects all context-related tests

4. **Update Expected Error Messages**
   - Match actual panic messages from the component
   - Affects all should_panic tests

## Verification

After implementing fixes:
1. Run `snforge test` to ensure all tests pass
2. Check test coverage with `snforge test --coverage`
3. Verify no new warnings introduced

## Quick Start

To immediately see progress, fix the constructor parameter order:

```bash
# Edit mock_metagame_contract.cairo
# Change constructor parameters from:
# (minigame_token_address, context_address, supports_context)
# To:
# (context_address, minigame_token_address, supports_context)

# Update deploy_mock_metagame helper to match

# Run a simple test to verify
snforge test test_initialize_with_token_only
```