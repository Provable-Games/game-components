## Package: utils

Pure utility functions for encoding and JSON generation. All functions are stateless with no storage or syscalls - ideal for unit testing.

## Modules

| Module | Purpose |
|--------|---------|
| `encoding` | Base64 encoding, byte counting utilities |
| `json` | JSON generation for settings, objectives, context metadata |

## encoding.cairo

```cairo
use game_components_utils::encoding::bytes_base64_encode;

// Base64 encode any ByteArray
let encoded = bytes_base64_encode("Hello World");
// Result: "SGVsbG8gV29ybGQ="

// Byte counting for integer types
use game_components_utils::encoding::U256BytesUsedTraitImpl;
let bytes_needed = U256BytesUsedTraitImpl::bytes_used(some_value.into());
```

**BytesUsedTrait** implementations: `u8`, `usize`, `u64`, `u128`, `u256`

## json.cairo

Generates JSON strings for game metadata components.

```cairo
use game_components_utils::json::{
    create_settings_json,
    create_objectives_json,
    create_context_json,
    create_json_array,
};

// Settings JSON
let settings = array![
    GameSetting { name: "Difficulty", value: "Hard" },
    GameSetting { name: "Lives", value: "3" },
].span();
let json = create_settings_json("Mode Name", "Mode Description", settings);
// {"Name":"Mode Name","Description":"Mode Description","Settings":{"Difficulty":"Hard","Lives":"3"}}

// Objectives JSON
let objectives = array![
    GameObjective { name: "Score 100", value: "100 points" },
].span();
let json = create_objectives_json(objectives);

// Context JSON (with optional context_id)
let contexts = array![
    GameContext { name: "Tournament", value: "Weekly #5" },
].span();
let json = create_context_json("Budokan", "Tournament system", Option::Some(42), contexts);

// Simple JSON array
let values = array!["value1", "value2"].span();
let json = create_json_array(values);  // ["value1","value2"]
```

## Dependencies

- `graffiti` - JSON building
- `alexandria_encoding` - Base64 encoding
- `game_components_metagame` - GameContext structs
- `game_components_minigame` - GameSetting, GameObjective structs

## Testing

All functions are pure - test directly without contract deployment:

```cairo
#[test]
fn test_json_generation() {
    let json = create_settings_json("Test", "Desc", settings);
    assert!(json.len() > 0, "Should generate JSON");
}
```
