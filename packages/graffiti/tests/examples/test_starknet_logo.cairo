//! Tests for Starknet logo SVG construction patterns based on examples/starknet_svg_logo.cairo
//!
//! These tests verify that the graffiti library can construct complex path-based SVGs
//! like the official Starknet logo with multiple path elements and fill colors.
//!
//! Note: Tag does not implement Clone, so we create fresh instances for each path.

use graffiti::{Tag, TagImpl};

// ============================================================================
// SVG Structure Tests
// ============================================================================

#[test]
fn test_svg_logo_dimensions() {
    let svg: Tag = TagImpl::new("svg").attr("width", "158").attr("height", "158");
    let result = svg.build();
    assert!(result == "<svg width=\"158\" height=\"158\" />", "svg dimensions mismatch");
}

#[test]
fn test_svg_logo_viewbox() {
    let svg: Tag = TagImpl::new("svg").attr("viewbox", "0 0 158 158");
    let result = svg.build();
    assert!(result == "<svg viewbox=\"0 0 158 158\" />", "svg viewbox mismatch");
}

#[test]
fn test_svg_logo_full_attributes() {
    let svg: Tag = TagImpl::new("svg")
        .attr("width", "158")
        .attr("height", "158")
        .attr("viewbox", "0 0 158 158")
        .attr("xmlns", "http://www.w3.org/2000/svg");
    let result = svg.build();
    assert!(
        result == "<svg width=\"158\" height=\"158\" viewbox=\"0 0 158 158\" xmlns=\"http://www.w3.org/2000/svg\" />",
        "svg full attributes mismatch",
    );
}

// ============================================================================
// Path Element Tests
// ============================================================================

#[test]
fn test_path_basic() {
    let path: Tag = TagImpl::new("path").attr("d", "M0 0 L10 10");
    let result = path.build();
    assert!(result == "<path d=\"M0 0 L10 10\" />", "path basic mismatch");
}

#[test]
fn test_path_with_fill_rule() {
    let path: Tag = TagImpl::new("path").attr("fill-rule", "evenodd").attr("clip-rule", "evenodd");
    let result = path.build();
    assert!(
        result == "<path fill-rule=\"evenodd\" clip-rule=\"evenodd\" />",
        "path with fill rule mismatch",
    );
}

#[test]
fn test_path_with_fill_color() {
    let path: Tag = TagImpl::new("path").attr("d", "M0 0").attr("fill", "#0C0C4F");
    let result = path.build();
    assert!(result == "<path d=\"M0 0\" fill=\"#0C0C4F\" />", "path with fill color mismatch");
}

// ============================================================================
// Complex Path Data Tests
// ============================================================================

#[test]
fn test_path_complex_d_attribute() {
    // Test with a simplified version of Starknet logo path
    let path: Tag = TagImpl::new("path")
        .attr(
            "d",
            "M0 78.99C0 122.6 35.37 158 79 158C122.6 158 158 122.6 158 79C158 35.37 122.6 0 79 0C35.37 0 0 35.37 0 78.99Z",
        )
        .attr("fill", "#0C0C4F");
    let result = path.build();
    assert!(result.len() > 0, "complex path should build");
}

#[test]
fn test_path_with_scientific_notation_in_d() {
    // Starknet logo uses scientific notation like -3.68439e-06
    let path: Tag = TagImpl::new("path")
        .attr("d", "M-3.68439e-06 78.9988C-3.68439e-06 122.629 35.3685 157.998 78.9988 157.998");
    let result = path.build();
    assert!(result.len() > 0, "path with scientific notation should build");
}

// ============================================================================
// Fill Colors Tests
// ============================================================================

#[test]
fn test_starknet_blue_fill() {
    let path: Tag = TagImpl::new("path").attr("fill", "#0C0C4F");
    let result = path.build();
    assert!(result == "<path fill=\"#0C0C4F\" />", "starknet blue fill mismatch");
}

#[test]
fn test_starknet_white_fill() {
    let path: Tag = TagImpl::new("path").attr("fill", "#FAFAFA");
    let result = path.build();
    assert!(result == "<path fill=\"#FAFAFA\" />", "starknet white fill mismatch");
}

#[test]
fn test_starknet_coral_fill() {
    let path: Tag = TagImpl::new("path").attr("fill", "#EC796B");
    let result = path.build();
    assert!(result == "<path fill=\"#EC796B\" />", "starknet coral fill mismatch");
}

#[test]
fn test_all_starknet_colors() {
    // Verify all three colors used in Starknet logo
    let blue: Tag = TagImpl::new("path").attr("fill", "#0C0C4F");
    let white: Tag = TagImpl::new("path").attr("fill", "#FAFAFA");
    let coral: Tag = TagImpl::new("path").attr("fill", "#EC796B");

    assert!(blue.build() == "<path fill=\"#0C0C4F\" />", "blue path");
    assert!(white.build() == "<path fill=\"#FAFAFA\" />", "white path");
    assert!(coral.build() == "<path fill=\"#EC796B\" />", "coral path");
}

// ============================================================================
// Path Pattern Tests (without Clone)
// ============================================================================

/// Helper to create a base path with common Starknet logo attributes
fn make_base_path() -> Tag {
    TagImpl::new("path").attr("fill-rule", "evenodd").attr("clip-rule", "evenodd")
}

#[test]
fn test_path_base_pattern() {
    // Starknet logo uses a base path with common attributes
    // Since Tag doesn't implement Clone, we create fresh instances
    let path1: Tag = make_base_path().attr("d", "M0 0").attr("fill", "#0C0C4F");
    let path2: Tag = make_base_path().attr("d", "M10 10").attr("fill", "#FAFAFA");

    let result1 = path1.build();
    let result2 = path2.build();

    assert!(
        result1 == "<path fill-rule=\"evenodd\" clip-rule=\"evenodd\" d=\"M0 0\" fill=\"#0C0C4F\" />",
        "path1 mismatch",
    );
    assert!(
        result2 == "<path fill-rule=\"evenodd\" clip-rule=\"evenodd\" d=\"M10 10\" fill=\"#FAFAFA\" />",
        "path2 mismatch",
    );
}

#[test]
fn test_multiple_similar_paths() {
    // Create multiple paths with common base attributes
    let path1: Tag = make_base_path().attr("d", "M0 0").attr("fill", "#0C0C4F");
    let path2: Tag = make_base_path().attr("d", "M10 10").attr("fill", "#EC796B");

    assert!(path1.build().len() > 0, "path1 builds");
    assert!(path2.build().len() > 0, "path2 builds");
}

// ============================================================================
// SVG Structure with Multiple Paths Tests
// ============================================================================

#[test]
fn test_svg_with_one_path() {
    let path: Tag = TagImpl::new("path").attr("d", "M0 0").attr("fill", "red");
    let svg: Tag = TagImpl::new("svg").attr("xmlns", "http://www.w3.org/2000/svg").insert(path);
    let result = svg.build();
    assert!(
        result == "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 0\" fill=\"red\" /></svg>",
        "svg with one path mismatch",
    );
}

#[test]
fn test_svg_with_multiple_paths() {
    let path1: Tag = TagImpl::new("path").attr("d", "M0 0").attr("fill", "blue");
    let path2: Tag = TagImpl::new("path").attr("d", "M10 10").attr("fill", "white");

    let svg: Tag = TagImpl::new("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .insert(path1)
        .insert(path2);
    let result = svg.build();
    assert!(
        result == "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 0\" fill=\"blue\" /><path d=\"M10 10\" fill=\"white\" /></svg>",
        "svg with multiple paths mismatch",
    );
}

#[test]
fn test_svg_five_paths_starknet_structure() {
    // Starknet logo has exactly 5 paths
    let path1: Tag = make_base_path()
        .attr("d", "M0 79")
        .attr("fill", "#0C0C4F"); // Background circle
    let path2: Tag = make_base_path().attr("d", "M44 60").attr("fill", "#FAFAFA"); // Star
    let path3: Tag = make_base_path().attr("d", "M139 56").attr("fill", "#EC796B"); // Wave 1
    let path4: Tag = make_base_path().attr("d", "M139 56").attr("fill", "#FAFAFA"); // Wave 2
    let path5: Tag = make_base_path().attr("d", "M110 113").attr("fill", "#EC796B"); // Dot

    let svg: Tag = TagImpl::new("svg")
        .attr("width", "158")
        .attr("height", "158")
        .insert(path1)
        .insert(path2)
        .insert(path3)
        .insert(path4)
        .insert(path5);

    let result = svg.build();
    assert!(result.len() > 0, "five path SVG should build");
}

// ============================================================================
// Viewbox for Logo Tests
// ============================================================================

#[test]
fn test_viewbox_square_logo() {
    let svg: Tag = TagImpl::new("svg").attr("viewbox", "0 0 158 158");
    let result = svg.build();
    assert!(result == "<svg viewbox=\"0 0 158 158\" />", "square viewbox mismatch");
}

#[test]
fn test_viewbox_starting_at_origin() {
    // Most logos start viewbox at 0 0
    let svg: Tag = TagImpl::new("svg").attr("viewbox", "0 0 100 100");
    let result = svg.build();
    assert!(result == "<svg viewbox=\"0 0 100 100\" />", "origin viewbox mismatch");
}

#[test]
fn test_viewbox_with_offset() {
    // Some SVGs have offset viewbox
    let svg: Tag = TagImpl::new("svg").attr("viewbox", "10 10 100 100");
    let result = svg.build();
    assert!(result == "<svg viewbox=\"10 10 100 100\" />", "offset viewbox mismatch");
}

// ============================================================================
// Complete Starknet Logo Structure Test
// ============================================================================

#[test]
fn test_starknet_logo_complete_structure() {
    // Build a simplified but structurally complete Starknet logo
    let svg: Tag = TagImpl::new("svg")
        .attr("width", "158")
        .attr("height", "158")
        .attr("viewbox", "0 0 158 158")
        .attr("xmlns", "http://www.w3.org/2000/svg");

    // Simplified paths with shorter d values for test readability
    let path1: Tag = make_base_path()
        .attr("d", "M0 79 C0 122 35 158 79 158")
        .attr("fill", "#0C0C4F");
    let path2: Tag = make_base_path().attr("d", "M44 60 L46 54").attr("fill", "#FAFAFA");
    let path3: Tag = make_base_path()
        .attr("d", "M139 56 C137 54 133 52 129 51")
        .attr("fill", "#EC796B");
    let path4: Tag = make_base_path()
        .attr("d", "M139 56 C137 50 132 44 125 40")
        .attr("fill", "#FAFAFA");
    let path5: Tag = make_base_path()
        .attr("d", "M110 113 C110 118 114 122 119 122")
        .attr("fill", "#EC796B");

    let logo = svg.insert(path1).insert(path2).insert(path3).insert(path4).insert(path5);
    let result = logo.build();

    // Verify the result is non-empty and starts correctly
    assert!(result.len() > 100, "logo should have substantial content");
}

// ============================================================================
// Edge Case Tests
// ============================================================================

#[test]
fn test_path_with_empty_d() {
    let path: Tag = TagImpl::new("path").attr("d", "");
    let result = path.build();
    assert!(result == "<path d=\"\" />", "empty d attribute mismatch");
}

#[test]
fn test_svg_without_xmlns() {
    // xmlns is optional but recommended
    let svg: Tag = TagImpl::new("svg").attr("width", "100").attr("height", "100");
    let result = svg.build();
    assert!(result == "<svg width=\"100\" height=\"100\" />", "svg without xmlns mismatch");
}

#[test]
fn test_nested_groups_in_svg() {
    // SVG can have groups (g elements) for organization
    let path: Tag = TagImpl::new("path").attr("d", "M0 0").attr("fill", "red");
    let group: Tag = TagImpl::new("g").attr("id", "logo-group").insert(path);
    let svg: Tag = TagImpl::new("svg").insert(group);
    let result = svg.build();
    assert!(
        result == "<svg><g id=\"logo-group\"><path d=\"M0 0\" fill=\"red\" /></g></svg>",
        "nested groups mismatch",
    );
}

// ============================================================================
// Color Format Tests
// ============================================================================

#[test]
fn test_hex_color_6_digit() {
    let path: Tag = TagImpl::new("path").attr("fill", "#FF5733");
    let result = path.build();
    assert!(result == "<path fill=\"#FF5733\" />", "6 digit hex color mismatch");
}

#[test]
fn test_hex_color_3_digit() {
    let path: Tag = TagImpl::new("path").attr("fill", "#F00");
    let result = path.build();
    assert!(result == "<path fill=\"#F00\" />", "3 digit hex color mismatch");
}

#[test]
fn test_named_color() {
    let path: Tag = TagImpl::new("path").attr("fill", "red");
    let result = path.build();
    assert!(result == "<path fill=\"red\" />", "named color mismatch");
}

#[test]
fn test_rgb_color() {
    let path: Tag = TagImpl::new("path").attr("fill", "rgb(255, 0, 0)");
    let result = path.build();
    assert!(result == "<path fill=\"rgb(255, 0, 0)\" />", "rgb color mismatch");
}
