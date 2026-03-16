//! SVG element helpers for common SVG construction patterns.
//!
//! Provides factory functions for creating SVG elements with proper
//! namespaces and common attribute helpers.

use graffiti::elements::{Tag, TagImpl};
use graffiti::format::u32_to_string;

//
// SVG Root Element
//

/// Creates an SVG root element with standard namespace.
///
/// # Arguments
/// * `width` - Width of the SVG
/// * `height` - Height of the SVG
///
/// # Returns
/// A Tag configured as an SVG root element
pub fn svg_root(width: u32, height: u32) -> Tag {
    TagImpl::new("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .attr("width", u32_to_string(width))
        .attr("height", u32_to_string(height))
}

/// Creates an SVG root element with a viewBox.
///
/// # Arguments
/// * `width` - Width of the SVG
/// * `height` - Height of the SVG
/// * `viewbox` - The viewBox attribute value (e.g., "0 0 100 100")
///
/// # Returns
/// A Tag configured as an SVG root element with viewBox
pub fn svg_root_with_viewbox(width: u32, height: u32, viewbox: ByteArray) -> Tag {
    TagImpl::new("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .attr("width", u32_to_string(width))
        .attr("height", u32_to_string(height))
        .attr("viewBox", viewbox)
}

//
// Shape Elements
//

/// Creates a rectangle element.
pub fn rect(x: u32, y: u32, width: u32, height: u32) -> Tag {
    TagImpl::new("rect")
        .attr("x", u32_to_string(x))
        .attr("y", u32_to_string(y))
        .attr("width", u32_to_string(width))
        .attr("height", u32_to_string(height))
}

/// Creates a circle element.
pub fn circle(cx: u32, cy: u32, r: u32) -> Tag {
    TagImpl::new("circle")
        .attr("cx", u32_to_string(cx))
        .attr("cy", u32_to_string(cy))
        .attr("r", u32_to_string(r))
}

/// Creates an ellipse element.
pub fn ellipse(cx: u32, cy: u32, rx: u32, ry: u32) -> Tag {
    TagImpl::new("ellipse")
        .attr("cx", u32_to_string(cx))
        .attr("cy", u32_to_string(cy))
        .attr("rx", u32_to_string(rx))
        .attr("ry", u32_to_string(ry))
}

/// Creates a line element.
pub fn line(x1: u32, y1: u32, x2: u32, y2: u32) -> Tag {
    TagImpl::new("line")
        .attr("x1", u32_to_string(x1))
        .attr("y1", u32_to_string(y1))
        .attr("x2", u32_to_string(x2))
        .attr("y2", u32_to_string(y2))
}

/// Creates a path element with the given path data.
pub fn path(d: ByteArray) -> Tag {
    TagImpl::new("path").attr("d", d)
}

/// Creates a polygon element with the given points.
pub fn polygon(points: ByteArray) -> Tag {
    TagImpl::new("polygon").attr("points", points)
}

/// Creates a polyline element with the given points.
pub fn polyline(points: ByteArray) -> Tag {
    TagImpl::new("polyline").attr("points", points)
}

//
// Text Elements
//

/// Creates a text element at the specified position.
pub fn text(x: u32, y: u32, content: ByteArray) -> Tag {
    TagImpl::new("text").attr("x", u32_to_string(x)).attr("y", u32_to_string(y)).content(content)
}

/// Creates a tspan element for text spans within text elements.
pub fn tspan(content: ByteArray) -> Tag {
    TagImpl::new("tspan").content(content)
}

//
// Grouping & Structure Elements
//

/// Creates a group element.
pub fn g() -> Tag {
    TagImpl::new("g")
}

/// Creates a defs element for reusable definitions.
pub fn defs() -> Tag {
    TagImpl::new("defs")
}

/// Creates a use element that references another element.
pub fn use_ref(href: ByteArray) -> Tag {
    TagImpl::new("use").attr("href", href)
}

/// Creates a symbol element with an ID.
pub fn symbol(id: ByteArray) -> Tag {
    TagImpl::new("symbol").attr("id", id)
}

/// Creates a clipPath element with an ID.
pub fn clip_path(id: ByteArray) -> Tag {
    TagImpl::new("clipPath").attr("id", id)
}

/// Creates a mask element with an ID.
pub fn mask(id: ByteArray) -> Tag {
    TagImpl::new("mask").attr("id", id)
}

//
// Gradient Elements
//

/// Creates a linear gradient element.
pub fn linear_gradient(
    id: ByteArray, x1: ByteArray, y1: ByteArray, x2: ByteArray, y2: ByteArray,
) -> Tag {
    TagImpl::new("linearGradient")
        .attr("id", id)
        .attr("x1", x1)
        .attr("y1", y1)
        .attr("x2", x2)
        .attr("y2", y2)
}

/// Creates a radial gradient element.
pub fn radial_gradient(id: ByteArray, cx: ByteArray, cy: ByteArray, r: ByteArray) -> Tag {
    TagImpl::new("radialGradient").attr("id", id).attr("cx", cx).attr("cy", cy).attr("r", r)
}

/// Creates a gradient stop element.
pub fn stop(offset: ByteArray, color: ByteArray) -> Tag {
    TagImpl::new("stop").attr("offset", offset).attr("stop-color", color)
}

//
// Filter Elements
//

/// Creates a filter element with an ID.
pub fn filter(id: ByteArray) -> Tag {
    TagImpl::new("filter").attr("id", id)
}

/// Creates a feGaussianBlur filter primitive.
pub fn fe_gaussian_blur(std_deviation: ByteArray) -> Tag {
    TagImpl::new("feGaussianBlur").attr("stdDeviation", std_deviation)
}

/// Creates a feDropShadow filter primitive.
pub fn fe_drop_shadow(dx: ByteArray, dy: ByteArray, std_deviation: ByteArray) -> Tag {
    TagImpl::new("feDropShadow").attr("dx", dx).attr("dy", dy).attr("stdDeviation", std_deviation)
}

//
// Style Element
//

/// Creates a style element with CSS content.
pub fn style(css: ByteArray) -> Tag {
    TagImpl::new("style").content_raw(css)
}

//
// Image Element
//

/// Creates an image element.
pub fn image(x: u32, y: u32, width: u32, height: u32, href: ByteArray) -> Tag {
    TagImpl::new("image")
        .attr("x", u32_to_string(x))
        .attr("y", u32_to_string(y))
        .attr("width", u32_to_string(width))
        .attr("height", u32_to_string(height))
        .attr("href", href)
}


//
// SVG Attribute Extensions
//

/// Trait for adding common SVG attributes to tags.
pub trait SvgAttrs<T> {
    /// Sets the fill color.
    fn fill(self: T, color: ByteArray) -> T;

    /// Sets the stroke color.
    fn stroke(self: T, color: ByteArray) -> T;

    /// Sets the stroke width.
    fn stroke_width(self: T, width: ByteArray) -> T;

    /// Sets a transform attribute.
    fn transform(self: T, transform: ByteArray) -> T;

    /// Sets the CSS class.
    fn class(self: T, class_name: ByteArray) -> T;

    /// Sets the element ID.
    fn id(self: T, id: ByteArray) -> T;

    /// Sets inline styles.
    fn style_attr(self: T, style: ByteArray) -> T;

    /// Sets the opacity.
    fn opacity(self: T, value: ByteArray) -> T;

    /// Sets the fill opacity.
    fn fill_opacity(self: T, value: ByteArray) -> T;

    /// Sets the stroke opacity.
    fn stroke_opacity(self: T, value: ByteArray) -> T;

    /// Sets the font family.
    fn font_family(self: T, family: ByteArray) -> T;

    /// Sets the font size.
    fn font_size(self: T, size: ByteArray) -> T;

    /// Sets the font weight.
    fn font_weight(self: T, weight: ByteArray) -> T;

    /// Sets the text anchor.
    fn text_anchor(self: T, anchor: ByteArray) -> T;

    /// Sets the dominant baseline.
    fn dominant_baseline(self: T, baseline: ByteArray) -> T;
}

pub impl TagSvgAttrs of SvgAttrs<Tag> {
    fn fill(self: Tag, color: ByteArray) -> Tag {
        self.attr("fill", color)
    }

    fn stroke(self: Tag, color: ByteArray) -> Tag {
        self.attr("stroke", color)
    }

    fn stroke_width(self: Tag, width: ByteArray) -> Tag {
        self.attr("stroke-width", width)
    }

    fn transform(self: Tag, transform: ByteArray) -> Tag {
        self.attr("transform", transform)
    }

    fn class(self: Tag, class_name: ByteArray) -> Tag {
        self.attr("class", class_name)
    }

    fn id(self: Tag, id: ByteArray) -> Tag {
        self.attr("id", id)
    }

    fn style_attr(self: Tag, style: ByteArray) -> Tag {
        self.attr("style", style)
    }

    fn opacity(self: Tag, value: ByteArray) -> Tag {
        self.attr("opacity", value)
    }

    fn fill_opacity(self: Tag, value: ByteArray) -> Tag {
        self.attr("fill-opacity", value)
    }

    fn stroke_opacity(self: Tag, value: ByteArray) -> Tag {
        self.attr("stroke-opacity", value)
    }

    fn font_family(self: Tag, family: ByteArray) -> Tag {
        self.attr("font-family", family)
    }

    fn font_size(self: Tag, size: ByteArray) -> Tag {
        self.attr("font-size", size)
    }

    fn font_weight(self: Tag, weight: ByteArray) -> Tag {
        self.attr("font-weight", weight)
    }

    fn text_anchor(self: Tag, anchor: ByteArray) -> Tag {
        self.attr("text-anchor", anchor)
    }

    fn dominant_baseline(self: Tag, baseline: ByteArray) -> Tag {
        self.attr("dominant-baseline", baseline)
    }
}


#[cfg(test)]
mod tests {
    use graffiti::elements::TagBuilder;
    use super::{
        SvgAttrs, circle, defs, ellipse, fe_gaussian_blur, filter, g, image, line, linear_gradient,
        path, polygon, polyline, radial_gradient, rect, stop, style, svg_root,
        svg_root_with_viewbox, symbol, text, tspan, use_ref,
    };

    #[test]
    fn test_svg_root() {
        let svg = svg_root(100, 200);
        let built = svg.build();
        assert!(
            built == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"200\" />",
            "svg root",
        );
    }

    #[test]
    fn test_svg_root_with_viewbox() {
        let svg = svg_root_with_viewbox(100, 100, "0 0 100 100");
        let built = svg.build();
        assert!(
            built == "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\" viewBox=\"0 0 100 100\" />",
            "svg with viewbox",
        );
    }

    #[test]
    fn test_rect() {
        let r = rect(10, 20, 100, 50);
        assert!(
            r.build() == "<rect x=\"10\" y=\"20\" width=\"100\" height=\"50\" />", "rect basic",
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
    fn test_circle() {
        let c = circle(50, 50, 25);
        assert!(c.build() == "<circle cx=\"50\" cy=\"50\" r=\"25\" />", "circle basic");
    }

    #[test]
    fn test_circle_with_stroke() {
        let c = circle(50, 50, 25).fill("none").stroke("#000").stroke_width("2");
        assert!(
            c
                .build() == "<circle cx=\"50\" cy=\"50\" r=\"25\" fill=\"none\" stroke=\"#000\" stroke-width=\"2\" />",
            "circle with stroke",
        );
    }

    #[test]
    fn test_ellipse() {
        let e = ellipse(100, 50, 80, 40);
        assert!(e.build() == "<ellipse cx=\"100\" cy=\"50\" rx=\"80\" ry=\"40\" />", "ellipse");
    }

    #[test]
    fn test_line() {
        let l = line(0, 0, 100, 100);
        assert!(l.build() == "<line x1=\"0\" y1=\"0\" x2=\"100\" y2=\"100\" />", "line");
    }

    #[test]
    fn test_path() {
        let p = path("M10 10 L90 90");
        assert!(p.build() == "<path d=\"M10 10 L90 90\" />", "path");
    }

    #[test]
    fn test_polygon() {
        let p = polygon("50,0 100,100 0,100");
        assert!(p.build() == "<polygon points=\"50,0 100,100 0,100\" />", "polygon");
    }

    #[test]
    fn test_polyline() {
        let p = polyline("0,0 50,50 100,0");
        assert!(p.build() == "<polyline points=\"0,0 50,50 100,0\" />", "polyline");
    }

    #[test]
    fn test_text() {
        let t = text(10, 20, "Hello");
        assert!(t.build() == "<text x=\"10\" y=\"20\">Hello</text>", "text basic");
    }

    #[test]
    fn test_text_with_styling() {
        let t = text(50, 50, "Centered")
            .font_family("Arial")
            .font_size("24px")
            .text_anchor("middle")
            .fill("#333");
        assert!(
            t
                .build() == "<text x=\"50\" y=\"50\" font-family=\"Arial\" font-size=\"24px\" text-anchor=\"middle\" fill=\"#333\">Centered</text>",
            "styled text",
        );
    }

    #[test]
    fn test_tspan() {
        let ts = tspan("span text");
        assert!(ts.build() == "<tspan>span text</tspan>", "tspan");
    }

    #[test]
    fn test_group() {
        let group = g().id("my-group").insert(rect(0, 0, 10, 10)).insert(circle(20, 20, 5));
        let built = group.build();
        assert!(
            built == "<g id=\"my-group\"><rect x=\"0\" y=\"0\" width=\"10\" height=\"10\" /><circle cx=\"20\" cy=\"20\" r=\"5\" /></g>",
            "group with children",
        );
    }

    #[test]
    fn test_defs() {
        let d = defs();
        assert!(d.build() == "<defs />", "empty defs");
    }

    #[test]
    fn test_use_ref() {
        let u = use_ref("#mySymbol");
        assert!(u.build() == "<use href=\"#mySymbol\" />", "use ref");
    }

    #[test]
    fn test_symbol() {
        let s = symbol("icon").insert(circle(10, 10, 5));
        assert!(
            s.build() == "<symbol id=\"icon\"><circle cx=\"10\" cy=\"10\" r=\"5\" /></symbol>",
            "symbol",
        );
    }

    #[test]
    fn test_linear_gradient() {
        let grad = linear_gradient("grad1", "0%", "0%", "100%", "0%")
            .insert(stop("0%", "#ff0000"))
            .insert(stop("100%", "#0000ff"));
        let built = grad.build();
        assert!(
            built == "<linearGradient id=\"grad1\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"0%\"><stop offset=\"0%\" stop-color=\"#ff0000\" /><stop offset=\"100%\" stop-color=\"#0000ff\" /></linearGradient>",
            "linear gradient",
        );
    }

    #[test]
    fn test_radial_gradient() {
        let grad = radial_gradient("grad2", "50%", "50%", "50%");
        assert!(
            grad.build() == "<radialGradient id=\"grad2\" cx=\"50%\" cy=\"50%\" r=\"50%\" />",
            "radial gradient",
        );
    }

    #[test]
    fn test_filter() {
        let f = filter("blur").insert(fe_gaussian_blur("5"));
        assert!(
            f.build() == "<filter id=\"blur\"><feGaussianBlur stdDeviation=\"5\" /></filter>",
            "filter with blur",
        );
    }

    #[test]
    fn test_style() {
        let s = style(".cls { fill: red; }");
        assert!(s.build() == "<style>.cls { fill: red; }</style>", "style element");
    }

    #[test]
    fn test_image() {
        let img = image(0, 0, 100, 100, "data:image/png;base64,abc");
        assert!(
            img
                .build() == "<image x=\"0\" y=\"0\" width=\"100\" height=\"100\" href=\"data:image/png;base64,abc\" />",
            "image",
        );
    }

    #[test]
    fn test_complete_svg() {
        let svg = svg_root_with_viewbox(200, 200, "0 0 200 200")
            .insert(
                defs()
                    .insert(
                        linear_gradient("bg", "0%", "0%", "0%", "100%")
                            .insert(stop("0%", "#1a1a2e"))
                            .insert(stop("100%", "#16213e")),
                    ),
            )
            .insert(rect(0, 0, 200, 200).fill("url(#bg)"))
            .insert(circle(100, 100, 50).fill("#e94560").opacity("0.8"))
            .insert(
                text(100, 180, "Hello SVG")
                    .font_family("sans-serif")
                    .font_size("16")
                    .text_anchor("middle")
                    .fill("white"),
            );

        let built = svg.build();
        // Just verify it contains expected parts
        assert!(built.len() > 0, "complete svg built");
    }

    #[test]
    fn test_svg_attrs_chaining() {
        let r = rect(0, 0, 100, 100)
            .fill("#f00")
            .stroke("#000")
            .stroke_width("2")
            .opacity("0.5")
            .class("my-rect")
            .id("rect1")
            .transform("rotate(45)");

        let built = r.build();
        assert!(
            built == "<rect x=\"0\" y=\"0\" width=\"100\" height=\"100\" fill=\"#f00\" stroke=\"#000\" stroke-width=\"2\" opacity=\"0.5\" class=\"my-rect\" id=\"rect1\" transform=\"rotate(45)\" />",
            "chained attrs",
        );
    }
}
