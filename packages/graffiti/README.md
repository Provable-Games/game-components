# Graffiti

A Cairo library for building XML-based markup documents (SVG, HTML, RSS, etc.) on Starknet.

## Overview

Graffiti provides a fluent builder API for constructing XML/HTML tags with attributes, content, and nested children. It's designed for on-chain generation of metadata, SVGs, and other markup documents.

## Installation

Add to your `Scarb.toml`:

```toml
[dependencies]
graffiti = { git = "https://github.com/Provable-Games/graffiti.git" }
```

### Requirements

- Scarb 2.15.1+
- Cairo 2.15.0+
- Starknet Foundry 0.55.0+ (for testing)

## Usage

### Building HTML/XML Tags

```cairo
use graffiti::{Tag, TagImpl};

fn build_html() -> ByteArray {
    let html: Tag = TagImpl::new("html").attr("lang", "en");

    let head: Tag = TagImpl::new("head");
    let title: Tag = TagImpl::new("title").content("My Page");
    let meta: Tag = TagImpl::new("meta").attr("charset", "utf-8");

    let body: Tag = TagImpl::new("body");
    let h1: Tag = TagImpl::new("h1").attr("class", "title").content("Hello, Starknet!");
    let p: Tag = TagImpl::new("p").content("Built with Graffiti");

    html
        .insert(head.insert(meta).insert(title))
        .insert(body.insert(h1).insert(p))
        .build()
}
// Output: <html lang="en"><head><meta charset="utf-8" /><title>My Page</title></head><body><h1 class="title">Hello, Starknet!</h1><p>Built with Graffiti</p></body></html>
```

### Building SVGs

```cairo
use graffiti::{Tag, TagImpl};

fn build_svg() -> ByteArray {
    let svg: Tag = TagImpl::new("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .attr("viewBox", "0 0 100 100");

    let rect: Tag = TagImpl::new("rect")
        .attr("width", "100%")
        .attr("height", "100%")
        .attr("fill", "black");

    let text: Tag = TagImpl::new("text")
        .attr("x", "50")
        .attr("y", "50")
        .attr("fill", "white")
        .content("Hello");

    svg.insert(rect).insert(text).build()
}
```

### Building JSON

```cairo
use graffiti::json::{JsonImpl, Builder};

fn build_metadata() -> ByteArray {
    JsonImpl::new()
        .add("name", "My NFT")
        .add("description", "An on-chain NFT")
        .add("image", "data:image/svg+xml;base64,...")
        .build()
}
// Output: {"name":"My NFT","description":"An on-chain NFT","image":"data:image/svg+xml;base64,..."}
```

### Nested JSON with Arrays

```cairo
use graffiti::json::{JsonImpl, Builder};

fn build_nft_metadata() -> ByteArray {
    let attributes = JsonImpl::new()
        .add("trait_type", "Background")
        .add("value", "Blue")
        .build();

    JsonImpl::new()
        .add("name", "Cool NFT #1")
        .add("description", "A very cool NFT")
        .add_array("attributes", array![attributes].span())
        .build()
}
```

## API Reference

### Tag Builder

| Method | Description |
|--------|-------------|
| `TagImpl::new(name)` | Create a new tag with the given name |
| `.attr(name, value)` | Add an attribute to the tag |
| `.content(text)` | Set the text content of the tag |
| `.insert(child)` | Insert a child tag |
| `.build()` | Serialize the tag to a `ByteArray` |

### JSON Builder

| Method | Description |
|--------|-------------|
| `JsonImpl::new()` | Create a new JSON builder |
| `.add(key, value)` | Add a key-value pair |
| `.add_array(key, values)` | Add an array of values |
| `.build()` | Serialize to a JSON `ByteArray` |

## Tag Rendering Rules

- **Empty tags**: `<tag />` (self-closing)
- **With attributes only**: `<tag attr="value" />`
- **With content**: `<tag>content</tag>`
- **With children**: `<tag><child /></tag>`
- **With attributes and content**: `<tag attr="value">content</tag>`

## Examples

See the `examples/` directory for more complete examples:

- `minimal_html.cairo` - Basic HTML document structure
- `starknet_svg_logo.cairo` - Complex SVG with multiple paths
- `a_loot_bag.cairo` - SVG with repeated elements (Loot-style)

## Development

```bash
# Build
scarb build

# Run tests
snforge test

# Format code
scarb fmt
```

## License

See [LICENSE](LICENSE) file.
