## Package: testing

Shared test constants and address helpers for consistent testing across all game component packages.

## Address Constants

```cairo
use game_components_testing::constants::{
    ALICE, BOB, CHARLIE,           // Named test users
    OWNER, NEW_OWNER,              // Ownership testing
    USER1, USER2,                  // Generic users
    CREATOR,                       // Game/token creator
    RENDERER_ADDRESS,              // Mock renderer
    ZERO_ADDRESS,                  // Zero address constant
};

// All return ContractAddress
let owner = OWNER();
let alice = ALICE();
```

| Function | Returns | Use Case |
|----------|---------|----------|
| `ALICE()` | ContractAddress | Named test user A |
| `BOB()` | ContractAddress | Named test user B |
| `CHARLIE()` | ContractAddress | Named test user C |
| `OWNER()` | ContractAddress | Contract owner/admin |
| `NEW_OWNER()` | ContractAddress | Ownership transfer target |
| `USER1()` | ContractAddress | Generic test user 1 |
| `USER2()` | ContractAddress | Generic test user 2 |
| `CREATOR()` | ContractAddress | Game/token creator |
| `RENDERER_ADDRESS()` | ContractAddress | Mock renderer contract |
| `ZERO_ADDRESS()` | ContractAddress | Zero address (0x0) |

## Edge Case Values

```cairo
use game_components_testing::constants::{
    MAX_U64,                    // 18446744073709551615
    MAX_U32,                    // 4294967295
    MAX_LIFECYCLE_TIMESTAMP,   // 34359738367 (2^35 - 1)
};
```

| Constant | Value | Use Case |
|----------|-------|----------|
| `MAX_U64` | 2^64 - 1 | Max token_id, max u64 values |
| `MAX_U32` | 2^32 - 1 | Max score, max settings_id |
| `MAX_LIFECYCLE_TIMESTAMP` | 2^35 - 1 | Max value for TokenMetadata lifecycle packing |

## Time Constants

```cairo
use game_components_testing::constants::{
    PAST_TIME,        // 100
    CURRENT_TIME,     // 1000
    FUTURE_TIME,      // 2000
    FAR_FUTURE_TIME,  // 3000
};
```

Use with `start_cheat_block_timestamp` for lifecycle testing:

```cairo
use snforge_std::{start_cheat_block_timestamp, stop_cheat_block_timestamp};

// Test token expired
start_cheat_block_timestamp(contract_address, FUTURE_TIME);
assert!(!token.is_playable(token_id), "Should be expired");
stop_cheat_block_timestamp(contract_address);
```

## Usage Pattern

```cairo
use game_components_testing::constants::{OWNER, USER1, CURRENT_TIME, MAX_U32};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};

#[test]
fn test_owner_only_function() {
    let contract = deploy_contract();

    // Test as owner - should succeed
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.admin_function();
    stop_cheat_caller_address(contract.contract_address);

    // Test as non-owner - should fail
    start_cheat_caller_address(contract.contract_address, USER1());
    // contract.admin_function(); // Would panic
}

#[test]
fn test_edge_case_score() {
    let contract = deploy_contract();
    contract.set_score(token_id, MAX_U32);
    assert!(contract.score(token_id) == MAX_U32, "Should handle max score");
}
```

## Dependencies

- `starknet` - ContractAddress type only

## Notes

- Addresses use short-string conversion: `'ALICE'.try_into().unwrap()`
- All address functions are deterministic - same value every call
- Use these constants instead of magic numbers for readable tests
