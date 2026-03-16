## Repository & Git

**Repository:** https://github.com/Provable-Games/graffiti
**Remote:** `provable-games`
**Main branch:** `main`

Always push to `provable-games` remote, never `origin`. Example:
```bash
git push provable-games main
git push provable-games feature/my-branch
```

## Project Overview

Graffiti is a Cairo library for building XML-based markup documents (SVG, HTML, RSS, JSON) on Starknet. It provides a fluent builder API for constructing tags with attributes, content, and nested children for on-chain metadata generation.

## Build & Test Commands

```bash
scarb build          # Build the library
snforge test         # Run all tests
snforge test <name>  # Run specific test by name
scarb fmt            # Check formatting
scarb fmt -w         # Fix formatting
```

## Architecture

The library has two main builders:

### Tag Builder (`src/elements.cairo`)

Fluent API for XML/HTML/SVG construction:

```cairo
use graffiti::{Tag, TagImpl};
TagImpl::new("div").attr("class", "foo").content("text").insert(child).build()
```

### JSON Builder (`src/json.cairo`)

Fluent API for JSON construction with nested object and array support:

```cairo
use graffiti::json::{JsonImpl, Builder};
JsonImpl::new().add("key", "value").add_array("arr", array!["a", "b"].span()).build()
```

## Key Files

- `src/lib.cairo` - Public exports and `ToBytes` trait
- `src/elements.cairo` - `Tag`, `Attribute`, `TagBuilder` trait and `TagImpl`
- `src/json.cairo` - `JsonBuilder`, `Builder` trait and `JsonImpl`
- `src/utils.cairo` - Constants and helper functions
- `examples/` - Usage examples (HTML, SVG, Loot-style)

## Tag Rendering Rules

- Empty tags render self-closing: `<tag />`
- Attributes only: `<tag attr="value" />`
- With content: `<tag>content</tag>`
- With children: `<tag><child /></tag>`
