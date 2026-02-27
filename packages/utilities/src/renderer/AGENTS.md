## Module: renderer

SVG/HTML rendering and font embedding for token metadata and token_uri. All functions are stateless with no storage or syscalls.

## Submodules

| Submodule | Purpose |
|-----------|---------|
| `svg` | SVG card rendering and JSON metadata generation |
| `font` | VT323 pixel font embedded as WOFF2 base64 |

## svg.cairo

Generates data URIs for token metadata and SVG images.

```cairo
use game_components_utilities::renderer::svg::{create_default_svg, create_custom_metadata};

// Default SVG with animated game card design
let svg_uri = create_default_svg(
    game_metadata, token_metadata, score, player_name,
    settings_details, objective_details, context_details,
);
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
    objective_name,      // ByteArray
);
// Result: "data:application/json;base64,..."
```

**SVG Features:**
- 470x600 pixel animated game card with cyberpunk/dark-tech aesthetic
- 590x680 viewport with extra padding for dramatic 3D tilt effect
- Pinstripe pattern background with animated gradient border and shimmer
- Header with EGS logo placeholder, game name, developer, genre, game ID badge
- Reduced-height game image area (110px)
- Status badge pills: ACTIVE/FINISHED (green/red), SOULBOUND (accent/grey), OBJ DONE/PENDING
- Two-column panels with accent left-border strips (player, score, settings, objective)
- Timeline progress bar with start/end datetimes and animated marker
- Context section with name and up to 3 key:value pairs
- SVG icon symbols (star, user, check, x-mark, lock, clock)
- 3D card edges (16px outer, 8px inner) for depth effect
- Datetime format: "YYYY-MM-DD HH:MM"
- Game color accent used for border, separators, badges, and highlights

**Metadata JSON includes:**
- Standard NFT fields: name, description, image
- Game traits: game_id, developer, minted_by, score
- Lifecycle traits: minted_time, start_time, end_time, expired
- Optional traits: settings, context, objectives (added only if present)

## font.cairo

Embeds the VT323 pixel font as a WOFF2 base64-encoded `@font-face` declaration.

```cairo
use game_components_utilities::renderer::font::vt323_font_face;

let font_face_css = vt323_font_face();
```

## Dependencies

- `graffiti` - JSON building
- `alexandria_encoding` - Base64 encoding
- `game_components_embeddable_game_standard` - Game structs (GameMetadata, TokenMetadata, etc.)

## Testing

All functions are pure - test directly without contract deployment:

```cairo
#[test]
fn test_svg_generation() {
    let svg = create_default_svg(...);
    assert!(svg.len() > 0, "Should generate SVG");
}
```
