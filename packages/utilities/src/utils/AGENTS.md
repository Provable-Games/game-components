## Package: utils

Pure utility functions for encoding, JSON generation, and token metadata rendering. All functions are stateless with no storage or syscalls - ideal for unit testing.

## Modules

| Module | Purpose |
|--------|---------|
| `encoding` | Base64 encoding, byte counting utilities |
| `json` | JSON generation for settings, objectives, context metadata |
| `renderer` | SVG/HTML rendering for token metadata and token_uri |

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

## renderer.cairo

Generates data URIs for token metadata and SVG images.

```cairo
use game_components_utils::renderer::{create_default_svg, create_custom_metadata};

// Default SVG with game logo and basic info
let svg_uri = create_default_svg(token_id, game_metadata, score, player_name);
// Result: "data:image/svg+xml;base64,..."

// Full custom metadata with all extensions
let metadata_uri = create_custom_metadata(
    token_id,
    token_name,
    token_description,
    game_metadata,
    game_details_image,
    game_details,        // Span<GameDetail>
    settings_details,    // GameSettingDetails
    context_details,     // GameContextDetails
    token_metadata,      // TokenMetadata
    score,
    minted_by,
    player_name,
    objective_ids,       // Span<u32>
);
// Result: "data:application/json;base64,..."
```

**SVG Features:**
- 470x600 pixel canvas with rounded corners
- Circular logo with clip-path
- Game name, developer, player name, score display
- Configurable color from GameMetadata

**Metadata JSON includes:**
- Standard NFT fields: name, description, image
- Game traits: game_id, developer, minted_by, score
- Lifecycle traits: minted_time, start_time, end_time, expired
- Optional traits: settings, context, objectives (added only if present)

## Dependencies

- `graffiti` - JSON building
- `alexandria_encoding` - Base64 encoding
- `game_components_metagame` - GameContext structs
- `game_components_minigame` - GameSetting, GameObjective structs
- `game_components_registry` - GameMetadata struct
- `game_components_token` - TokenMetadata struct

## Testing

All functions are pure - test directly without contract deployment:

```cairo
#[test]
fn test_json_generation() {
    let json = create_settings_json("Test", "Desc", settings);
    assert!(json.len() > 0, "Should generate JSON");
}
```
