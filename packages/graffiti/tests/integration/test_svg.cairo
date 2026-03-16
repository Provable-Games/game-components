//! Integration tests for SVG builder.
//!
//! Tests cover SVG root elements, shapes, text, grouping, gradients, filters,
//! styles, transforms, and complete SVG document construction.

use graffiti::elements::{TagBuilder, TagImpl};
use graffiti::svg::{
    SvgAttrs, circle, clip_path, defs, ellipse, fe_drop_shadow, fe_gaussian_blur, filter, g, image,
    line, linear_gradient, mask, path, polygon, polyline, radial_gradient, rect, stop, style,
    svg_root, svg_root_with_viewbox, symbol, text, tspan, use_ref,
};


//
// SVG Root Element Tests
//

#[test]
fn test_svg_root_basic() {
    let svg = svg_root(800, 600);
    let built = svg.build();
    assert!(
        built == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"800\" height=\"600\" />",
        "basic svg root",
    );
}

#[test]
fn test_svg_root_square() {
    let svg = svg_root(100, 100);
    let built = svg.build();
    assert!(
        built == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\" />",
        "square svg",
    );
}

#[test]
fn test_svg_root_large_dimensions() {
    let svg = svg_root(4096, 2160);
    let built = svg.build();
    assert!(
        built == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"4096\" height=\"2160\" />",
        "4k dimensions",
    );
}


//
// ViewBox Tests
//

#[test]
fn test_svg_viewbox_basic() {
    let svg = svg_root_with_viewbox(200, 200, "0 0 200 200");
    let built = svg.build();
    assert!(
        built == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"200\" height=\"200\" viewBox=\"0 0 200 200\" />",
        "svg with viewbox",
    );
}

#[test]
fn test_svg_viewbox_scaled() {
    // viewBox is smaller than actual dimensions - content will be scaled up
    let svg = svg_root_with_viewbox(400, 400, "0 0 100 100");
    let built = svg.build();
    assert!(
        built == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400\" height=\"400\" viewBox=\"0 0 100 100\" />",
        "scaled viewbox",
    );
}

#[test]
fn test_svg_viewbox_offset() {
    // viewBox with non-zero origin
    let svg = svg_root_with_viewbox(300, 300, "-50 -50 200 200");
    let built = svg.build();
    assert!(
        built == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"300\" height=\"300\" viewBox=\"-50 -50 200 200\" />",
        "viewbox with offset",
    );
}


//
// Rectangle Tests
//

#[test]
fn test_rect_basic() {
    let r = rect(0, 0, 100, 50);
    assert!(r.build() == "<rect x=\"0\" y=\"0\" width=\"100\" height=\"50\" />", "basic rect");
}

#[test]
fn test_rect_positioned() {
    let r = rect(25, 75, 150, 80);
    assert!(
        r.build() == "<rect x=\"25\" y=\"75\" width=\"150\" height=\"80\" />", "positioned rect",
    );
}

#[test]
fn test_rect_with_fill() {
    let r = rect(0, 0, 100, 100).fill("#ff0000");
    assert!(
        r.build() == "<rect x=\"0\" y=\"0\" width=\"100\" height=\"100\" fill=\"#ff0000\" />",
        "rect with fill",
    );
}

#[test]
fn test_rect_with_stroke() {
    let r = rect(10, 10, 80, 80).fill("none").stroke("#000000").stroke_width("2");
    assert!(
        r
            .build() == "<rect x=\"10\" y=\"10\" width=\"80\" height=\"80\" fill=\"none\" stroke=\"#000000\" stroke-width=\"2\" />",
        "rect with stroke",
    );
}

#[test]
fn test_rect_with_opacity() {
    let r = rect(0, 0, 50, 50).fill("blue").opacity("0.5");
    assert!(
        r
            .build() == "<rect x=\"0\" y=\"0\" width=\"50\" height=\"50\" fill=\"blue\" opacity=\"0.5\" />",
        "rect with opacity",
    );
}


//
// Circle Tests
//

#[test]
fn test_circle_basic() {
    let c = circle(50, 50, 25);
    assert!(c.build() == "<circle cx=\"50\" cy=\"50\" r=\"25\" />", "basic circle");
}

#[test]
fn test_circle_origin() {
    let c = circle(0, 0, 100);
    assert!(c.build() == "<circle cx=\"0\" cy=\"0\" r=\"100\" />", "circle at origin");
}

#[test]
fn test_circle_with_fill_and_stroke() {
    let c = circle(100, 100, 50).fill("#00ff00").stroke("#000").stroke_width("3");
    assert!(
        c
            .build() == "<circle cx=\"100\" cy=\"100\" r=\"50\" fill=\"#00ff00\" stroke=\"#000\" stroke-width=\"3\" />",
        "styled circle",
    );
}

#[test]
fn test_circle_no_fill() {
    let c = circle(75, 75, 30).fill("none").stroke("red").stroke_width("1");
    assert!(
        c
            .build() == "<circle cx=\"75\" cy=\"75\" r=\"30\" fill=\"none\" stroke=\"red\" stroke-width=\"1\" />",
        "circle outline only",
    );
}


//
// Ellipse Tests
//

#[test]
fn test_ellipse_basic() {
    let e = ellipse(100, 50, 80, 40);
    assert!(e.build() == "<ellipse cx=\"100\" cy=\"50\" rx=\"80\" ry=\"40\" />", "basic ellipse");
}

#[test]
fn test_ellipse_vertical() {
    let e = ellipse(50, 100, 20, 60);
    assert!(
        e.build() == "<ellipse cx=\"50\" cy=\"100\" rx=\"20\" ry=\"60\" />", "vertical ellipse",
    );
}

#[test]
fn test_ellipse_styled() {
    let e = ellipse(150, 150, 100, 50).fill("purple").stroke("white").stroke_width("2");
    assert!(
        e
            .build() == "<ellipse cx=\"150\" cy=\"150\" rx=\"100\" ry=\"50\" fill=\"purple\" stroke=\"white\" stroke-width=\"2\" />",
        "styled ellipse",
    );
}


//
// Line Tests
//

#[test]
fn test_line_diagonal() {
    let l = line(0, 0, 100, 100);
    assert!(l.build() == "<line x1=\"0\" y1=\"0\" x2=\"100\" y2=\"100\" />", "diagonal line");
}

#[test]
fn test_line_horizontal() {
    let l = line(10, 50, 90, 50);
    assert!(l.build() == "<line x1=\"10\" y1=\"50\" x2=\"90\" y2=\"50\" />", "horizontal line");
}

#[test]
fn test_line_vertical() {
    let l = line(50, 10, 50, 90);
    assert!(l.build() == "<line x1=\"50\" y1=\"10\" x2=\"50\" y2=\"90\" />", "vertical line");
}

#[test]
fn test_line_styled() {
    let l = line(0, 0, 200, 200).stroke("#333").stroke_width("4");
    assert!(
        l
            .build() == "<line x1=\"0\" y1=\"0\" x2=\"200\" y2=\"200\" stroke=\"#333\" stroke-width=\"4\" />",
        "styled line",
    );
}


//
// Path Tests
//

#[test]
fn test_path_simple_line() {
    let p = path("M10 10 L90 90");
    assert!(p.build() == "<path d=\"M10 10 L90 90\" />", "simple line path");
}

#[test]
fn test_path_closed_triangle() {
    let p = path("M50 0 L100 100 L0 100 Z");
    assert!(p.build() == "<path d=\"M50 0 L100 100 L0 100 Z\" />", "closed triangle path");
}

#[test]
fn test_path_curve() {
    let p = path("M10 80 Q95 10 180 80");
    assert!(p.build() == "<path d=\"M10 80 Q95 10 180 80\" />", "quadratic bezier path");
}

#[test]
fn test_path_cubic_bezier() {
    let p = path("M10 10 C20 20 40 20 50 10");
    assert!(p.build() == "<path d=\"M10 10 C20 20 40 20 50 10\" />", "cubic bezier path");
}

#[test]
fn test_path_arc() {
    let p = path("M10 10 A20 20 0 0 1 50 10");
    assert!(p.build() == "<path d=\"M10 10 A20 20 0 0 1 50 10\" />", "arc path");
}

#[test]
fn test_path_styled() {
    let p = path("M0 0 L100 100").fill("none").stroke("black").stroke_width("2");
    assert!(
        p
            .build() == "<path d=\"M0 0 L100 100\" fill=\"none\" stroke=\"black\" stroke-width=\"2\" />",
        "styled path",
    );
}


//
// Polygon Tests
//

#[test]
fn test_polygon_triangle() {
    let p = polygon("50,0 100,100 0,100");
    assert!(p.build() == "<polygon points=\"50,0 100,100 0,100\" />", "triangle polygon");
}

#[test]
fn test_polygon_square() {
    let p = polygon("0,0 100,0 100,100 0,100");
    assert!(p.build() == "<polygon points=\"0,0 100,0 100,100 0,100\" />", "square polygon");
}

#[test]
fn test_polygon_star() {
    let p = polygon("50,0 61,35 98,35 68,57 79,91 50,70 21,91 32,57 2,35 39,35");
    let built = p.build();
    assert!(
        built == "<polygon points=\"50,0 61,35 98,35 68,57 79,91 50,70 21,91 32,57 2,35 39,35\" />",
        "star polygon",
    );
}

#[test]
fn test_polygon_styled() {
    let p = polygon("50,0 100,100 0,100").fill("yellow").stroke("black").stroke_width("1");
    assert!(
        p
            .build() == "<polygon points=\"50,0 100,100 0,100\" fill=\"yellow\" stroke=\"black\" stroke-width=\"1\" />",
        "styled polygon",
    );
}


//
// Polyline Tests
//

#[test]
fn test_polyline_basic() {
    let p = polyline("0,0 50,50 100,0");
    assert!(p.build() == "<polyline points=\"0,0 50,50 100,0\" />", "basic polyline");
}

#[test]
fn test_polyline_zigzag() {
    let p = polyline("0,50 25,0 50,50 75,0 100,50");
    assert!(p.build() == "<polyline points=\"0,50 25,0 50,50 75,0 100,50\" />", "zigzag polyline");
}

#[test]
fn test_polyline_styled() {
    let p = polyline("10,10 40,40 70,10 100,40").fill("none").stroke("blue").stroke_width("3");
    assert!(
        p
            .build() == "<polyline points=\"10,10 40,40 70,10 100,40\" fill=\"none\" stroke=\"blue\" stroke-width=\"3\" />",
        "styled polyline",
    );
}


//
// Text Element Tests
//

#[test]
fn test_text_basic() {
    let t = text(10, 30, "Hello World");
    assert!(t.build() == "<text x=\"10\" y=\"30\">Hello World</text>", "basic text");
}

#[test]
fn test_text_positioned() {
    let t = text(100, 200, "Centered Text");
    assert!(t.build() == "<text x=\"100\" y=\"200\">Centered Text</text>", "positioned text");
}

#[test]
fn test_text_with_font_styling() {
    let t = text(50, 50, "Styled")
        .font_family("Arial, sans-serif")
        .font_size("24px")
        .font_weight("bold");
    assert!(
        t
            .build() == "<text x=\"50\" y=\"50\" font-family=\"Arial, sans-serif\" font-size=\"24px\" font-weight=\"bold\">Styled</text>",
        "styled text",
    );
}

#[test]
fn test_text_with_anchor() {
    let t = text(100, 100, "Middle").text_anchor("middle").fill("#333");
    assert!(
        t.build() == "<text x=\"100\" y=\"100\" text-anchor=\"middle\" fill=\"#333\">Middle</text>",
        "text with anchor",
    );
}

#[test]
fn test_text_with_dominant_baseline() {
    let t = text(50, 50, "Baseline").dominant_baseline("central");
    assert!(
        t.build() == "<text x=\"50\" y=\"50\" dominant-baseline=\"central\">Baseline</text>",
        "text with baseline",
    );
}


//
// Tspan Tests
//

#[test]
fn test_tspan_basic() {
    let ts = tspan("span content");
    assert!(ts.build() == "<tspan>span content</tspan>", "basic tspan");
}

#[test]
fn test_tspan_in_text() {
    let ts1 = tspan("First ").fill("red");
    let ts2 = tspan("Second").fill("blue");
    let t = TagImpl::new("text").attr("x", "10").attr("y", "30").insert(ts1).insert(ts2);
    assert!(
        t
            .build() == "<text x=\"10\" y=\"30\"><tspan fill=\"red\">First </tspan><tspan fill=\"blue\">Second</tspan></text>",
        "tspans in text",
    );
}


//
// Group Element Tests
//

#[test]
fn test_group_empty() {
    let group = g();
    assert!(group.build() == "<g />", "empty group");
}

#[test]
fn test_group_with_id() {
    let group = g().id("my-group");
    assert!(group.build() == "<g id=\"my-group\" />", "group with id");
}

#[test]
fn test_group_with_children() {
    let group = g().insert(rect(0, 0, 50, 50)).insert(circle(75, 25, 25));
    assert!(
        group
            .build() == "<g><rect x=\"0\" y=\"0\" width=\"50\" height=\"50\" /><circle cx=\"75\" cy=\"25\" r=\"25\" /></g>",
        "group with children",
    );
}

#[test]
fn test_group_with_transform() {
    let group = g().transform("translate(50, 50)").insert(rect(0, 0, 20, 20));
    assert!(
        group
            .build() == "<g transform=\"translate(50, 50)\"><rect x=\"0\" y=\"0\" width=\"20\" height=\"20\" /></g>",
        "group with transform",
    );
}

#[test]
fn test_nested_groups() {
    let inner = g().id("inner").insert(circle(0, 0, 10));
    let outer = g().id("outer").insert(inner);
    assert!(
        outer
            .build() == "<g id=\"outer\"><g id=\"inner\"><circle cx=\"0\" cy=\"0\" r=\"10\" /></g></g>",
        "nested groups",
    );
}


//
// Defs Element Tests
//

#[test]
fn test_defs_empty() {
    let d = defs();
    assert!(d.build() == "<defs />", "empty defs");
}

#[test]
fn test_defs_with_gradient() {
    let grad = linear_gradient("myGrad", "0%", "0%", "100%", "0%")
        .insert(stop("0%", "red"))
        .insert(stop("100%", "blue"));
    let d = defs().insert(grad);
    let built = d.build();
    assert!(
        built == "<defs><linearGradient id=\"myGrad\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"0%\"><stop offset=\"0%\" stop-color=\"red\" /><stop offset=\"100%\" stop-color=\"blue\" /></linearGradient></defs>",
        "defs with gradient",
    );
}


//
// Use Element Tests
//

#[test]
fn test_use_ref_basic() {
    let u = use_ref("#mySymbol");
    assert!(u.build() == "<use href=\"#mySymbol\" />", "basic use ref");
}

#[test]
fn test_use_with_position() {
    let u = use_ref("#icon").attr("x", "100").attr("y", "50");
    assert!(u.build() == "<use href=\"#icon\" x=\"100\" y=\"50\" />", "use with position");
}


//
// Symbol Element Tests
//

#[test]
fn test_symbol_basic() {
    let s = symbol("star-icon");
    assert!(s.build() == "<symbol id=\"star-icon\" />", "empty symbol");
}

#[test]
fn test_symbol_with_content() {
    let s = symbol("arrow").insert(path("M0 0 L10 5 L0 10 Z"));
    assert!(
        s.build() == "<symbol id=\"arrow\"><path d=\"M0 0 L10 5 L0 10 Z\" /></symbol>",
        "symbol with path",
    );
}


//
// Clip Path Tests
//

#[test]
fn test_clip_path_basic() {
    let cp = clip_path("myClip");
    assert!(cp.build() == "<clipPath id=\"myClip\" />", "empty clip path");
}

#[test]
fn test_clip_path_with_shape() {
    let cp = clip_path("circleClip").insert(circle(50, 50, 50));
    assert!(
        cp
            .build() == "<clipPath id=\"circleClip\"><circle cx=\"50\" cy=\"50\" r=\"50\" /></clipPath>",
        "clip path with circle",
    );
}


//
// Mask Element Tests
//

#[test]
fn test_mask_basic() {
    let m = mask("myMask");
    assert!(m.build() == "<mask id=\"myMask\" />", "empty mask");
}

#[test]
fn test_mask_with_gradient() {
    let m = mask("fadeMask").insert(rect(0, 0, 100, 100).fill("url(#fade)"));
    assert!(
        m
            .build() == "<mask id=\"fadeMask\"><rect x=\"0\" y=\"0\" width=\"100\" height=\"100\" fill=\"url(#fade)\" /></mask>",
        "mask with rect",
    );
}


//
// Linear Gradient Tests
//

#[test]
fn test_linear_gradient_horizontal() {
    let grad = linear_gradient("hGrad", "0%", "0%", "100%", "0%");
    assert!(
        grad.build() == "<linearGradient id=\"hGrad\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"0%\" />",
        "horizontal gradient",
    );
}

#[test]
fn test_linear_gradient_vertical() {
    let grad = linear_gradient("vGrad", "0%", "0%", "0%", "100%");
    assert!(
        grad.build() == "<linearGradient id=\"vGrad\" x1=\"0%\" y1=\"0%\" x2=\"0%\" y2=\"100%\" />",
        "vertical gradient",
    );
}

#[test]
fn test_linear_gradient_diagonal() {
    let grad = linear_gradient("dGrad", "0%", "0%", "100%", "100%");
    assert!(
        grad
            .build() == "<linearGradient id=\"dGrad\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\" />",
        "diagonal gradient",
    );
}

#[test]
fn test_linear_gradient_with_stops() {
    let grad = linear_gradient("rainbow", "0%", "0%", "100%", "0%")
        .insert(stop("0%", "red"))
        .insert(stop("50%", "green"))
        .insert(stop("100%", "blue"));
    assert!(
        grad
            .build() == "<linearGradient id=\"rainbow\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"0%\"><stop offset=\"0%\" stop-color=\"red\" /><stop offset=\"50%\" stop-color=\"green\" /><stop offset=\"100%\" stop-color=\"blue\" /></linearGradient>",
        "gradient with stops",
    );
}


//
// Radial Gradient Tests
//

#[test]
fn test_radial_gradient_basic() {
    let grad = radial_gradient("rGrad", "50%", "50%", "50%");
    assert!(
        grad.build() == "<radialGradient id=\"rGrad\" cx=\"50%\" cy=\"50%\" r=\"50%\" />",
        "basic radial gradient",
    );
}

#[test]
fn test_radial_gradient_offset() {
    let grad = radial_gradient("spotlight", "25%", "25%", "75%");
    assert!(
        grad.build() == "<radialGradient id=\"spotlight\" cx=\"25%\" cy=\"25%\" r=\"75%\" />",
        "offset radial gradient",
    );
}

#[test]
fn test_radial_gradient_with_stops() {
    let grad = radial_gradient("glow", "50%", "50%", "50%")
        .insert(stop("0%", "white"))
        .insert(stop("100%", "transparent"));
    assert!(
        grad
            .build() == "<radialGradient id=\"glow\" cx=\"50%\" cy=\"50%\" r=\"50%\"><stop offset=\"0%\" stop-color=\"white\" /><stop offset=\"100%\" stop-color=\"transparent\" /></radialGradient>",
        "radial with stops",
    );
}


//
// Stop Element Tests
//

#[test]
fn test_stop_basic() {
    let s = stop("50%", "#ff0000");
    assert!(s.build() == "<stop offset=\"50%\" stop-color=\"#ff0000\" />", "basic stop");
}

#[test]
fn test_stop_with_opacity() {
    let s = stop("0%", "black").attr("stop-opacity", "0.5");
    assert!(
        s.build() == "<stop offset=\"0%\" stop-color=\"black\" stop-opacity=\"0.5\" />",
        "stop with opacity",
    );
}


//
// Filter Tests
//

#[test]
fn test_filter_empty() {
    let f = filter("myFilter");
    assert!(f.build() == "<filter id=\"myFilter\" />", "empty filter");
}

#[test]
fn test_filter_with_blur() {
    let f = filter("blur").insert(fe_gaussian_blur("5"));
    assert!(
        f.build() == "<filter id=\"blur\"><feGaussianBlur stdDeviation=\"5\" /></filter>",
        "filter with blur",
    );
}

#[test]
fn test_filter_with_drop_shadow() {
    let f = filter("shadow").insert(fe_drop_shadow("3", "3", "2"));
    assert!(
        f
            .build() == "<filter id=\"shadow\"><feDropShadow dx=\"3\" dy=\"3\" stdDeviation=\"2\" /></filter>",
        "filter with drop shadow",
    );
}


//
// feGaussianBlur Tests
//

#[test]
fn test_fe_gaussian_blur_basic() {
    let blur = fe_gaussian_blur("3");
    assert!(blur.build() == "<feGaussianBlur stdDeviation=\"3\" />", "basic blur");
}

#[test]
fn test_fe_gaussian_blur_xy() {
    // Different x and y blur values
    let blur = fe_gaussian_blur("5,2");
    assert!(blur.build() == "<feGaussianBlur stdDeviation=\"5,2\" />", "xy blur");
}


//
// feDropShadow Tests
//

#[test]
fn test_fe_drop_shadow_basic() {
    let shadow = fe_drop_shadow("2", "2", "1");
    assert!(
        shadow.build() == "<feDropShadow dx=\"2\" dy=\"2\" stdDeviation=\"1\" />", "basic shadow",
    );
}

#[test]
fn test_fe_drop_shadow_large() {
    let shadow = fe_drop_shadow("10", "10", "5");
    assert!(
        shadow.build() == "<feDropShadow dx=\"10\" dy=\"10\" stdDeviation=\"5\" />", "large shadow",
    );
}


//
// Style Element Tests
//

#[test]
fn test_style_basic() {
    let s = style(".red { fill: red; }");
    assert!(s.build() == "<style>.red { fill: red; }</style>", "basic style");
}

#[test]
fn test_style_multiple_rules() {
    let s = style(".a { fill: red; } .b { stroke: blue; }");
    assert!(s.build() == "<style>.a { fill: red; } .b { stroke: blue; }</style>", "multiple rules");
}

#[test]
fn test_style_complex_css() {
    let css = ".icon { fill: #333; stroke: none; } .icon:hover { fill: #666; }";
    let s = style(css);
    assert!(
        s
            .build() == "<style>.icon { fill: #333; stroke: none; } .icon:hover { fill: #666; }</style>",
        "complex css",
    );
}


//
// Image Element Tests
//

#[test]
fn test_image_basic() {
    let img = image(0, 0, 100, 100, "image.png");
    assert!(
        img.build() == "<image x=\"0\" y=\"0\" width=\"100\" height=\"100\" href=\"image.png\" />",
        "basic image",
    );
}

#[test]
fn test_image_positioned() {
    let img = image(50, 50, 200, 150, "photo.jpg");
    assert!(
        img
            .build() == "<image x=\"50\" y=\"50\" width=\"200\" height=\"150\" href=\"photo.jpg\" />",
        "positioned image",
    );
}

#[test]
fn test_image_data_uri() {
    let img = image(0, 0, 64, 64, "data:image/png;base64,iVBORw0KGgo=");
    assert!(
        img
            .build() == "<image x=\"0\" y=\"0\" width=\"64\" height=\"64\" href=\"data:image/png;base64,iVBORw0KGgo=\" />",
        "data uri image",
    );
}


//
// Transform Attribute Tests
//

#[test]
fn test_transform_translate() {
    let r = rect(0, 0, 50, 50).transform("translate(100, 100)");
    assert!(
        r
            .build() == "<rect x=\"0\" y=\"0\" width=\"50\" height=\"50\" transform=\"translate(100, 100)\" />",
        "translate transform",
    );
}

#[test]
fn test_transform_rotate() {
    let r = rect(0, 0, 50, 50).transform("rotate(45)");
    assert!(
        r.build() == "<rect x=\"0\" y=\"0\" width=\"50\" height=\"50\" transform=\"rotate(45)\" />",
        "rotate transform",
    );
}

#[test]
fn test_transform_rotate_around_point() {
    let r = rect(0, 0, 50, 50).transform("rotate(45, 25, 25)");
    assert!(
        r
            .build() == "<rect x=\"0\" y=\"0\" width=\"50\" height=\"50\" transform=\"rotate(45, 25, 25)\" />",
        "rotate around point",
    );
}

#[test]
fn test_transform_scale() {
    let r = rect(0, 0, 50, 50).transform("scale(2)");
    assert!(
        r.build() == "<rect x=\"0\" y=\"0\" width=\"50\" height=\"50\" transform=\"scale(2)\" />",
        "scale transform",
    );
}

#[test]
fn test_transform_scale_xy() {
    let r = rect(0, 0, 50, 50).transform("scale(2, 0.5)");
    assert!(
        r
            .build() == "<rect x=\"0\" y=\"0\" width=\"50\" height=\"50\" transform=\"scale(2, 0.5)\" />",
        "scale xy transform",
    );
}

#[test]
fn test_transform_skew() {
    let r = rect(0, 0, 50, 50).transform("skewX(30)");
    assert!(
        r.build() == "<rect x=\"0\" y=\"0\" width=\"50\" height=\"50\" transform=\"skewX(30)\" />",
        "skew transform",
    );
}

#[test]
fn test_transform_combined() {
    let r = rect(0, 0, 50, 50).transform("translate(50, 50) rotate(45) scale(1.5)");
    assert!(
        r
            .build() == "<rect x=\"0\" y=\"0\" width=\"50\" height=\"50\" transform=\"translate(50, 50) rotate(45) scale(1.5)\" />",
        "combined transforms",
    );
}


//
// Fill and Stroke Attribute Tests
//

#[test]
fn test_fill_hex_color() {
    let c = circle(50, 50, 25).fill("#ff5500");
    assert!(
        c.build() == "<circle cx=\"50\" cy=\"50\" r=\"25\" fill=\"#ff5500\" />", "hex color fill",
    );
}

#[test]
fn test_fill_named_color() {
    let c = circle(50, 50, 25).fill("crimson");
    assert!(
        c.build() == "<circle cx=\"50\" cy=\"50\" r=\"25\" fill=\"crimson\" />", "named color fill",
    );
}

#[test]
fn test_fill_rgb() {
    let c = circle(50, 50, 25).fill("rgb(255, 128, 0)");
    assert!(
        c.build() == "<circle cx=\"50\" cy=\"50\" r=\"25\" fill=\"rgb(255, 128, 0)\" />",
        "rgb fill",
    );
}

#[test]
fn test_fill_url_gradient() {
    let c = circle(50, 50, 25).fill("url(#myGradient)");
    assert!(
        c.build() == "<circle cx=\"50\" cy=\"50\" r=\"25\" fill=\"url(#myGradient)\" />",
        "gradient fill",
    );
}

#[test]
fn test_fill_none() {
    let c = circle(50, 50, 25).fill("none");
    assert!(c.build() == "<circle cx=\"50\" cy=\"50\" r=\"25\" fill=\"none\" />", "no fill");
}

#[test]
fn test_stroke_color() {
    let c = circle(50, 50, 25).stroke("#000000");
    assert!(
        c.build() == "<circle cx=\"50\" cy=\"50\" r=\"25\" stroke=\"#000000\" />", "stroke color",
    );
}

#[test]
fn test_stroke_width_values() {
    let c = circle(50, 50, 25).stroke("black").stroke_width("5");
    assert!(
        c.build() == "<circle cx=\"50\" cy=\"50\" r=\"25\" stroke=\"black\" stroke-width=\"5\" />",
        "stroke width",
    );
}

#[test]
fn test_fill_opacity() {
    let r = rect(0, 0, 100, 100).fill("blue").fill_opacity("0.7");
    assert!(
        r
            .build() == "<rect x=\"0\" y=\"0\" width=\"100\" height=\"100\" fill=\"blue\" fill-opacity=\"0.7\" />",
        "fill opacity",
    );
}

#[test]
fn test_stroke_opacity() {
    let r = rect(0, 0, 100, 100).stroke("red").stroke_opacity("0.5");
    assert!(
        r
            .build() == "<rect x=\"0\" y=\"0\" width=\"100\" height=\"100\" stroke=\"red\" stroke-opacity=\"0.5\" />",
        "stroke opacity",
    );
}


//
// Class and ID Tests
//

#[test]
fn test_class_attribute() {
    let r = rect(0, 0, 100, 100).class("highlight");
    assert!(
        r.build() == "<rect x=\"0\" y=\"0\" width=\"100\" height=\"100\" class=\"highlight\" />",
        "class attribute",
    );
}

#[test]
fn test_multiple_classes() {
    let r = rect(0, 0, 100, 100).class("shape primary");
    assert!(
        r
            .build() == "<rect x=\"0\" y=\"0\" width=\"100\" height=\"100\" class=\"shape primary\" />",
        "multiple classes",
    );
}

#[test]
fn test_id_attribute() {
    let r = rect(0, 0, 100, 100).id("main-rect");
    assert!(
        r.build() == "<rect x=\"0\" y=\"0\" width=\"100\" height=\"100\" id=\"main-rect\" />",
        "id attribute",
    );
}

#[test]
fn test_style_attr() {
    let r = rect(0, 0, 100, 100).style_attr("fill: red; stroke: blue;");
    assert!(
        r
            .build() == "<rect x=\"0\" y=\"0\" width=\"100\" height=\"100\" style=\"fill: red; stroke: blue;\" />",
        "inline style",
    );
}


//
// Complete SVG Document Tests
//

#[test]
fn test_complete_svg_simple() {
    let svg = svg_root(200, 200)
        .insert(rect(10, 10, 180, 180).fill("#f0f0f0"))
        .insert(circle(100, 100, 50).fill("blue"));

    let built = svg.build();
    assert!(
        built == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"200\" height=\"200\"><rect x=\"10\" y=\"10\" width=\"180\" height=\"180\" fill=\"#f0f0f0\" /><circle cx=\"100\" cy=\"100\" r=\"50\" fill=\"blue\" /></svg>",
        "simple complete svg",
    );
}

#[test]
fn test_complete_svg_with_defs() {
    let gradient = linear_gradient("bg", "0%", "0%", "0%", "100%")
        .insert(stop("0%", "#1a1a2e"))
        .insert(stop("100%", "#16213e"));

    let svg = svg_root_with_viewbox(100, 100, "0 0 100 100")
        .insert(defs().insert(gradient))
        .insert(rect(0, 0, 100, 100).fill("url(#bg)"));

    let built = svg.build();
    assert!(built.len() > 0, "svg with defs built successfully");
}

#[test]
fn test_complete_svg_with_text() {
    let svg = svg_root(300, 100)
        .insert(
            text(150, 50, "Hello SVG")
                .font_family("Arial")
                .font_size("24")
                .text_anchor("middle")
                .fill("black"),
        );

    let built = svg.build();
    assert!(
        built == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"300\" height=\"100\"><text x=\"150\" y=\"50\" font-family=\"Arial\" font-size=\"24\" text-anchor=\"middle\" fill=\"black\">Hello SVG</text></svg>",
        "svg with centered text",
    );
}

#[test]
fn test_complete_svg_with_group() {
    let shapes = g()
        .id("shapes")
        .transform("translate(50, 50)")
        .insert(circle(0, 0, 20).fill("red"))
        .insert(rect(30, 30, 40, 40).fill("blue"));

    let svg = svg_root(200, 200).insert(shapes);
    let built = svg.build();
    assert!(built.len() > 0, "svg with grouped shapes built");
}

#[test]
fn test_complete_svg_with_filter() {
    let blur_filter = filter("softBlur").insert(fe_gaussian_blur("3"));

    let svg = svg_root(200, 200)
        .insert(defs().insert(blur_filter))
        .insert(circle(100, 100, 50).fill("green").attr("filter", "url(#softBlur)"));

    let built = svg.build();
    assert!(built.len() > 0, "svg with filter built");
}


//
// Edge Cases
//

#[test]
fn test_zero_dimensions() {
    let r = rect(0, 0, 0, 0);
    assert!(r.build() == "<rect x=\"0\" y=\"0\" width=\"0\" height=\"0\" />", "zero size rect");
}

#[test]
fn test_large_coordinates() {
    let r = rect(9999, 9999, 1, 1);
    assert!(
        r.build() == "<rect x=\"9999\" y=\"9999\" width=\"1\" height=\"1\" />", "large coordinates",
    );
}

#[test]
fn test_chaining_all_svg_attrs() {
    let r = rect(0, 0, 100, 100)
        .fill("#f00")
        .stroke("#000")
        .stroke_width("2")
        .opacity("0.9")
        .fill_opacity("0.8")
        .stroke_opacity("0.7")
        .class("myclass")
        .id("myid")
        .transform("rotate(45)")
        .style_attr("cursor: pointer");

    let built = r.build();
    // Just verify it builds without error and has expected length
    assert!(built.len() > 100, "all attrs chained");
}
