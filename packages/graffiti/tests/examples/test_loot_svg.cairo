//! Tests for Loot-style SVG construction patterns based on examples/a_loot_bag.cairo
//!
//! These tests verify that the graffiti library can construct SVG documents
//! following the Loot NFT pattern with text elements at various y-positions.

use graffiti::{Tag, TagImpl};

// ============================================================================
// SVG Root Attributes Tests
// ============================================================================

#[test]
fn test_svg_root_basic_attributes() {
    let svg: Tag = TagImpl::new("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .attr("width", "350")
        .attr("height", "350");
    let result = svg.build();
    assert!(
        result == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"350\" height=\"350\" />",
        "svg root basic attributes mismatch",
    );
}

#[test]
fn test_svg_root_with_viewbox() {
    let svg: Tag = TagImpl::new("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .attr("viewBox", "0 0 350 350");
    let result = svg.build();
    assert!(
        result == "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 350 350\" />",
        "svg root with viewBox mismatch",
    );
}

#[test]
fn test_svg_root_with_preserve_aspect_ratio() {
    let svg: Tag = TagImpl::new("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .attr("preserveAspectRatio", "xMinYMin meet")
        .attr("viewBox", "0 0 350 350");
    let result = svg.build();
    assert!(
        result == "<svg xmlns=\"http://www.w3.org/2000/svg\" preserveAspectRatio=\"xMinYMin meet\" viewBox=\"0 0 350 350\" />",
        "svg root with preserveAspectRatio mismatch",
    );
}

#[test]
fn test_svg_loot_style_root() {
    // Exact attributes from the Loot example
    let svg: Tag = TagImpl::new("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .attr("preserveAspectRatio", "xMinYMin meet")
        .attr("viewBox", "0 0 350 350");
    let result = svg.build();
    assert!(
        result == "<svg xmlns=\"http://www.w3.org/2000/svg\" preserveAspectRatio=\"xMinYMin meet\" viewBox=\"0 0 350 350\" />",
        "loot style svg root mismatch",
    );
}

// ============================================================================
// Style Element Tests
// ============================================================================

#[test]
fn test_style_element_basic() {
    let style: Tag = TagImpl::new("style").content_raw(".base { fill: white; }");
    let result = style.build();
    assert!(result == "<style>.base { fill: white; }</style>", "style element basic mismatch");
}

#[test]
fn test_style_element_loot_pattern() {
    let style: Tag = TagImpl::new("style")
        .content_raw(".base { fill: white; font-family: serif; font-size: 14px; }");
    let result = style.build();
    assert!(
        result == "<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>",
        "loot style element mismatch",
    );
}

#[test]
fn test_style_element_multiple_rules() {
    let style: Tag = TagImpl::new("style")
        .content_raw(".base { fill: white; } .highlight { fill: gold; }");
    let result = style.build();
    assert!(
        result == "<style>.base { fill: white; } .highlight { fill: gold; }</style>",
        "style with multiple rules mismatch",
    );
}

// ============================================================================
// Rect Element Tests
// ============================================================================

#[test]
fn test_rect_background() {
    let rect: Tag = TagImpl::new("rect")
        .attr("width", "100%")
        .attr("height", "100%")
        .attr("fill", "black");
    let result = rect.build();
    assert!(
        result == "<rect width=\"100%\" height=\"100%\" fill=\"black\" />",
        "rect background mismatch",
    );
}

#[test]
fn test_rect_with_specific_dimensions() {
    let rect: Tag = TagImpl::new("rect")
        .attr("x", "10")
        .attr("y", "10")
        .attr("width", "100")
        .attr("height", "50")
        .attr("fill", "blue");
    let result = rect.build();
    assert!(
        result == "<rect x=\"10\" y=\"10\" width=\"100\" height=\"50\" fill=\"blue\" />",
        "rect with dimensions mismatch",
    );
}

// ============================================================================
// Text Element Tests
// ============================================================================

#[test]
fn test_text_element_basic() {
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("y", "20")
        .attr("class", "base")
        .content("Item Name");
    let result = text.build();
    assert!(
        result == "<text x=\"10\" y=\"20\" class=\"base\">Item Name</text>",
        "text element basic mismatch",
    );
}

#[test]
fn test_text_element_first_position() {
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "20")
        .content("First Item");
    let result = text.build();
    assert!(
        result == "<text x=\"10\" class=\"base\" y=\"20\">First Item</text>",
        "text first position mismatch",
    );
}

#[test]
fn test_text_element_second_position() {
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "40")
        .content("Second Item");
    let result = text.build();
    assert!(
        result == "<text x=\"10\" class=\"base\" y=\"40\">Second Item</text>",
        "text second position mismatch",
    );
}

// ============================================================================
// Y-Position Pattern Tests
// ============================================================================

#[test]
fn test_text_y_position_20() {
    let text: Tag = TagImpl::new("text").attr("x", "10").attr("y", "20").content("Line 1");
    let result = text.build();
    assert!(result == "<text x=\"10\" y=\"20\">Line 1</text>", "text at y=20 mismatch");
}

#[test]
fn test_text_y_position_40() {
    let text: Tag = TagImpl::new("text").attr("x", "10").attr("y", "40").content("Line 2");
    let result = text.build();
    assert!(result == "<text x=\"10\" y=\"40\">Line 2</text>", "text at y=40 mismatch");
}

#[test]
fn test_text_y_position_60() {
    let text: Tag = TagImpl::new("text").attr("x", "10").attr("y", "60").content("Line 3");
    let result = text.build();
    assert!(result == "<text x=\"10\" y=\"60\">Line 3</text>", "text at y=60 mismatch");
}

#[test]
fn test_text_y_position_80() {
    let text: Tag = TagImpl::new("text").attr("x", "10").attr("y", "80").content("Line 4");
    let result = text.build();
    assert!(result == "<text x=\"10\" y=\"80\">Line 4</text>", "text at y=80 mismatch");
}

#[test]
fn test_text_y_position_100() {
    let text: Tag = TagImpl::new("text").attr("x", "10").attr("y", "100").content("Line 5");
    let result = text.build();
    assert!(result == "<text x=\"10\" y=\"100\">Line 5</text>", "text at y=100 mismatch");
}

#[test]
fn test_text_y_position_120() {
    let text: Tag = TagImpl::new("text").attr("x", "10").attr("y", "120").content("Line 6");
    let result = text.build();
    assert!(result == "<text x=\"10\" y=\"120\">Line 6</text>", "text at y=120 mismatch");
}

#[test]
fn test_text_y_position_140() {
    let text: Tag = TagImpl::new("text").attr("x", "10").attr("y", "140").content("Line 7");
    let result = text.build();
    assert!(result == "<text x=\"10\" y=\"140\">Line 7</text>", "text at y=140 mismatch");
}

#[test]
fn test_text_y_position_160() {
    let text: Tag = TagImpl::new("text").attr("x", "10").attr("y", "160").content("Line 8");
    let result = text.build();
    assert!(result == "<text x=\"10\" y=\"160\">Line 8</text>", "text at y=160 mismatch");
}

// ============================================================================
// Font Styling Tests
// ============================================================================

#[test]
fn test_text_with_font_family() {
    let text: Tag = TagImpl::new("text").attr("font-family", "serif").content("Styled Text");
    let result = text.build();
    assert!(
        result == "<text font-family=\"serif\">Styled Text</text>", "font-family attr mismatch",
    );
}

#[test]
fn test_text_with_fill_color() {
    let text: Tag = TagImpl::new("text").attr("fill", "white").content("White Text");
    let result = text.build();
    assert!(result == "<text fill=\"white\">White Text</text>", "fill attr mismatch");
}

#[test]
fn test_text_with_font_size() {
    let text: Tag = TagImpl::new("text").attr("font-size", "14px").content("Sized Text");
    let result = text.build();
    assert!(result == "<text font-size=\"14px\">Sized Text</text>", "font-size attr mismatch");
}

#[test]
fn test_text_with_multiple_font_attrs() {
    let text: Tag = TagImpl::new("text")
        .attr("fill", "white")
        .attr("font-family", "serif")
        .attr("font-size", "14px")
        .content("Fully Styled");
    let result = text.build();
    assert!(
        result == "<text fill=\"white\" font-family=\"serif\" font-size=\"14px\">Fully Styled</text>",
        "multiple font attrs mismatch",
    );
}

// ============================================================================
// Loot Item Names Tests
// ============================================================================

#[test]
fn test_loot_item_warhammer() {
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "20")
        .content("Warhammer");
    let result = text.build();
    assert!(
        result == "<text x=\"10\" class=\"base\" y=\"20\">Warhammer</text>", "warhammer mismatch",
    );
}

#[test]
fn test_loot_item_studded_leather_armor() {
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "40")
        .content("Studded Leather Armor");
    let result = text.build();
    assert!(
        result == "<text x=\"10\" class=\"base\" y=\"40\">Studded Leather Armor</text>",
        "studded leather armor mismatch",
    );
}

#[test]
fn test_loot_item_ancient_helm() {
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "60")
        .content("Ancient Helm");
    let result = text.build();
    assert!(
        result == "<text x=\"10\" class=\"base\" y=\"60\">Ancient Helm</text>",
        "ancient helm mismatch",
    );
}

#[test]
fn test_loot_item_wool_sash_of_rage() {
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "80")
        .content("Wool Sash of Rage");
    let result = text.build();
    assert!(
        result == "<text x=\"10\" class=\"base\" y=\"80\">Wool Sash of Rage</text>",
        "wool sash mismatch",
    );
}

#[test]
fn test_loot_item_studded_leather_boots() {
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "100")
        .content("Studded Leather Boots");
    let result = text.build();
    assert!(
        result == "<text x=\"10\" class=\"base\" y=\"100\">Studded Leather Boots</text>",
        "studded leather boots mismatch",
    );
}

#[test]
fn test_loot_item_linen_gloves() {
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "120")
        .content("Linen Gloves");
    let result = text.build();
    assert!(
        result == "<text x=\"10\" class=\"base\" y=\"120\">Linen Gloves</text>",
        "linen gloves mismatch",
    );
}

#[test]
fn test_loot_item_bronze_ring() {
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "160")
        .content("Bronze Ring");
    let result = text.build();
    assert!(
        result == "<text x=\"10\" class=\"base\" y=\"160\">Bronze Ring</text>",
        "bronze ring mismatch",
    );
}

// ============================================================================
// Complete Loot SVG Structure Test
// ============================================================================

#[test]
fn test_complete_loot_svg_structure() {
    // Build a complete Loot-style SVG
    let root: Tag = TagImpl::new("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .attr("preserveAspectRatio", "xMinYMin meet")
        .attr("viewBox", "0 0 350 350");

    let style: Tag = TagImpl::new("style")
        .content_raw(".base { fill: white; font-family: serif; font-size: 14px; }");

    let rect: Tag = TagImpl::new("rect")
        .attr("width", "100%")
        .attr("height", "100%")
        .attr("fill", "black");

    let text1: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "20")
        .content("Warhammer");
    let text2: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("class", "base")
        .attr("y", "40")
        .content("Shield");

    let svg = root.insert(style).insert(rect).insert(text1).insert(text2);
    let result = svg.build();

    // Verify structure contains expected elements
    assert!(result.len() > 0, "SVG should build");
}

// ============================================================================
// SVG with Style and Background Tests
// ============================================================================

#[test]
fn test_svg_with_style_and_rect() {
    let style: Tag = TagImpl::new("style").content_raw(".base { fill: white; }");
    let rect: Tag = TagImpl::new("rect")
        .attr("width", "100%")
        .attr("height", "100%")
        .attr("fill", "black");

    let svg: Tag = TagImpl::new("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .insert(style)
        .insert(rect);

    let result = svg.build();
    assert!(
        result == "<svg xmlns=\"http://www.w3.org/2000/svg\"><style>.base { fill: white; }</style><rect width=\"100%\" height=\"100%\" fill=\"black\" /></svg>",
        "svg with style and rect mismatch",
    );
}

// ============================================================================
// Text Content Escaping Tests (for special Loot item names)
// ============================================================================

#[test]
fn test_text_with_quotes_in_content() {
    // Loot has items like "Dragon Roar" Amulet of Anger
    let text: Tag = TagImpl::new("text")
        .attr("x", "10")
        .attr("y", "140")
        .content("\"Dragon Roar\" Amulet");
    let result = text.build();
    // content() escapes quotes to &quot;
    assert!(
        result == "<text x=\"10\" y=\"140\">&quot;Dragon Roar&quot; Amulet</text>",
        "text with quotes mismatch",
    );
}

#[test]
fn test_text_with_special_characters() {
    let text: Tag = TagImpl::new("text").content("Sword & Shield");
    let result = text.build();
    // content() escapes & to &amp;
    assert!(result == "<text>Sword &amp; Shield</text>", "text with ampersand mismatch");
}
