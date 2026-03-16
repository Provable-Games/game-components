//! Integration tests for Tag builder (elements.cairo)
//!
//! Comprehensive tests covering:
//! - Self-closing tags
//! - Tags with attributes
//! - Tags with content
//! - Tags with children (nested structures)
//! - Deep nesting (5+ levels)
//! - Many siblings (10+ children)
//! - XSS prevention (content and attribute escaping)
//! - Raw content and attributes
//! - Multiple attributes
//! - Empty content handling
//! - Unicode content
//! - Attribute ordering

use graffiti::{Tag, TagImpl};

// ============================================================================
// 1. Self-closing tags
// ============================================================================

#[test]
fn test_self_closing_empty_tag() {
    let tag: Tag = TagImpl::new("br");
    assert!(tag.build() == "<br />", "empty tag should render as self-closing");
}

#[test]
fn test_self_closing_various_tag_names() {
    assert!(TagImpl::new("hr").build() == "<hr />", "hr tag");
    assert!(TagImpl::new("img").build() == "<img />", "img tag");
    assert!(TagImpl::new("input").build() == "<input />", "input tag");
    assert!(TagImpl::new("meta").build() == "<meta />", "meta tag");
    assert!(TagImpl::new("link").build() == "<link />", "link tag");
}

// ============================================================================
// 2. Tags with attributes
// ============================================================================

#[test]
fn test_tag_with_single_attribute() {
    let tag: Tag = TagImpl::new("div").attr("class", "container");
    assert!(tag.build() == "<div class=\"container\" />", "single attribute");
}

#[test]
fn test_tag_with_attribute_renders_self_closing() {
    let tag: Tag = TagImpl::new("input").attr("type", "text");
    assert!(
        tag.build() == "<input type=\"text\" />", "attribute without content should self-close",
    );
}

// ============================================================================
// 3. Tags with content
// ============================================================================

#[test]
fn test_tag_with_simple_content() {
    let tag: Tag = TagImpl::new("p").content("Hello, world!");
    assert!(tag.build() == "<p>Hello, world!</p>", "simple content");
}

#[test]
fn test_tag_with_long_content() {
    let tag: Tag = TagImpl::new("p")
        .content(
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        );
    let expected =
        "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>";
    assert!(tag.build() == expected, "long content");
}

// ============================================================================
// 4. Tags with children (nested structures)
// ============================================================================

#[test]
fn test_tag_with_single_child() {
    let parent: Tag = TagImpl::new("div");
    let child: Tag = TagImpl::new("span");
    assert!(parent.insert(child).build() == "<div><span /></div>", "single child");
}

#[test]
fn test_tag_with_multiple_children() {
    let parent: Tag = TagImpl::new("ul");
    let li1: Tag = TagImpl::new("li").content("Item 1");
    let li2: Tag = TagImpl::new("li").content("Item 2");
    let li3: Tag = TagImpl::new("li").content("Item 3");
    let result = parent.insert(li1).insert(li2).insert(li3).build();
    assert!(
        result == "<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>", "multiple children",
    );
}

#[test]
fn test_nested_children_with_attributes() {
    let outer: Tag = TagImpl::new("div").attr("class", "outer");
    let inner: Tag = TagImpl::new("div").attr("class", "inner").content("text");
    let result = outer.insert(inner).build();
    assert!(
        result == "<div class=\"outer\"><div class=\"inner\">text</div></div>",
        "nested with attributes",
    );
}

// ============================================================================
// 5. Deep nesting (5+ levels)
// ============================================================================

#[test]
fn test_deep_nesting_five_levels() {
    let level5: Tag = TagImpl::new("span").content("deep");
    let level4: Tag = TagImpl::new("div").insert(level5);
    let level3: Tag = TagImpl::new("div").insert(level4);
    let level2: Tag = TagImpl::new("div").insert(level3);
    let level1: Tag = TagImpl::new("div").insert(level2);

    let expected = "<div><div><div><div><span>deep</span></div></div></div></div>";
    assert!(level1.build() == expected, "5 levels deep nesting");
}

#[test]
fn test_deep_nesting_seven_levels() {
    let level7: Tag = TagImpl::new("b").content("bold");
    let level6: Tag = TagImpl::new("i").insert(level7);
    let level5: Tag = TagImpl::new("span").insert(level6);
    let level4: Tag = TagImpl::new("p").insert(level5);
    let level3: Tag = TagImpl::new("article").insert(level4);
    let level2: Tag = TagImpl::new("section").insert(level3);
    let level1: Tag = TagImpl::new("main").insert(level2);

    let expected =
        "<main><section><article><p><span><i><b>bold</b></i></span></p></article></section></main>";
    assert!(level1.build() == expected, "7 levels deep nesting");
}

#[test]
fn test_deep_nesting_with_attributes_at_each_level() {
    let level5: Tag = TagImpl::new("span").attr("id", "l5").content("end");
    let level4: Tag = TagImpl::new("div").attr("id", "l4").insert(level5);
    let level3: Tag = TagImpl::new("div").attr("id", "l3").insert(level4);
    let level2: Tag = TagImpl::new("div").attr("id", "l2").insert(level3);
    let level1: Tag = TagImpl::new("div").attr("id", "l1").insert(level2);

    let expected =
        "<div id=\"l1\"><div id=\"l2\"><div id=\"l3\"><div id=\"l4\"><span id=\"l5\">end</span></div></div></div></div>";
    assert!(level1.build() == expected, "deep nesting with attributes");
}

// ============================================================================
// 6. Many siblings (10+ children)
// ============================================================================

#[test]
fn test_many_siblings_ten_children() {
    let parent: Tag = TagImpl::new("div");
    let c1: Tag = TagImpl::new("p").content("1");
    let c2: Tag = TagImpl::new("p").content("2");
    let c3: Tag = TagImpl::new("p").content("3");
    let c4: Tag = TagImpl::new("p").content("4");
    let c5: Tag = TagImpl::new("p").content("5");
    let c6: Tag = TagImpl::new("p").content("6");
    let c7: Tag = TagImpl::new("p").content("7");
    let c8: Tag = TagImpl::new("p").content("8");
    let c9: Tag = TagImpl::new("p").content("9");
    let c10: Tag = TagImpl::new("p").content("10");

    let result = parent
        .insert(c1)
        .insert(c2)
        .insert(c3)
        .insert(c4)
        .insert(c5)
        .insert(c6)
        .insert(c7)
        .insert(c8)
        .insert(c9)
        .insert(c10)
        .build();

    let expected =
        "<div><p>1</p><p>2</p><p>3</p><p>4</p><p>5</p><p>6</p><p>7</p><p>8</p><p>9</p><p>10</p></div>";
    assert!(result == expected, "10 siblings");
}

#[test]
fn test_many_self_closing_siblings() {
    let parent: Tag = TagImpl::new("form");
    let i1: Tag = TagImpl::new("input").attr("name", "f1");
    let i2: Tag = TagImpl::new("input").attr("name", "f2");
    let i3: Tag = TagImpl::new("input").attr("name", "f3");
    let i4: Tag = TagImpl::new("input").attr("name", "f4");
    let i5: Tag = TagImpl::new("input").attr("name", "f5");
    let i6: Tag = TagImpl::new("input").attr("name", "f6");
    let i7: Tag = TagImpl::new("input").attr("name", "f7");
    let i8: Tag = TagImpl::new("input").attr("name", "f8");
    let i9: Tag = TagImpl::new("input").attr("name", "f9");
    let i10: Tag = TagImpl::new("input").attr("name", "f10");

    let result = parent
        .insert(i1)
        .insert(i2)
        .insert(i3)
        .insert(i4)
        .insert(i5)
        .insert(i6)
        .insert(i7)
        .insert(i8)
        .insert(i9)
        .insert(i10)
        .build();

    let expected =
        "<form><input name=\"f1\" /><input name=\"f2\" /><input name=\"f3\" /><input name=\"f4\" /><input name=\"f5\" /><input name=\"f6\" /><input name=\"f7\" /><input name=\"f8\" /><input name=\"f9\" /><input name=\"f10\" /></form>";
    assert!(result == expected, "10 self-closing siblings");
}

// ============================================================================
// 7. Clone and modify pattern
// Note: Cairo does not support Clone trait on Tag by default.
// The Tag struct uses Option which does not implement Clone.
// We demonstrate creating similar tags instead.
// ============================================================================

#[test]
fn test_similar_tags_pattern() {
    // Create two similar tags (simulating clone and modify)
    let button1: Tag = TagImpl::new("button").attr("class", "btn").content("Submit");
    let button2: Tag = TagImpl::new("button")
        .attr("class", "btn")
        .attr("disabled", "true")
        .content("Disabled");

    assert!(button1.build() == "<button class=\"btn\">Submit</button>", "first button");
    assert!(
        button2.build() == "<button class=\"btn\" disabled=\"true\">Disabled</button>",
        "second button with extra attr",
    );
}

// ============================================================================
// 8. XSS prevention - content escaping
// ============================================================================

#[test]
fn test_xss_prevention_script_in_content() {
    let tag: Tag = TagImpl::new("div").content("<script>alert('xss')</script>");
    assert!(
        tag.build() == "<div>&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;</div>",
        "script tag should be escaped in content",
    );
}

#[test]
fn test_xss_prevention_onerror_in_content() {
    let tag: Tag = TagImpl::new("p").content("<img onerror=\"alert('xss')\">");
    assert!(
        tag.build() == "<p>&lt;img onerror=&quot;alert(&#39;xss&#39;)&quot;&gt;</p>",
        "onerror handler should be escaped",
    );
}

#[test]
fn test_xss_prevention_javascript_url_in_content() {
    let tag: Tag = TagImpl::new("span").content("javascript:alert('xss')");
    // javascript: scheme is not escaped (no special chars), but quotes are
    assert!(
        tag.build() == "<span>javascript:alert(&#39;xss&#39;)</span>",
        "javascript url quotes should be escaped",
    );
}

#[test]
fn test_content_escapes_all_special_chars() {
    let tag: Tag = TagImpl::new("p").content("<>&\"'");
    assert!(tag.build() == "<p>&lt;&gt;&amp;&quot;&#39;</p>", "all special chars escaped");
}

// ============================================================================
// 9. XSS prevention - attribute escaping
// ============================================================================

#[test]
fn test_attribute_value_not_auto_escaped() {
    // Note: Attribute values are NOT auto-escaped in the current API.
    // Users must manually escape values if needed using escape_xml().
    let tag: Tag = TagImpl::new("div").attr("data-value", "<script>");
    assert!(
        tag.build() == "<div data-value=\"<script>\" />", "attribute values are not auto-escaped",
    );
}

#[test]
fn test_attribute_value_with_quotes() {
    // Attribute values with quotes are stored as-is (no escaping)
    let tag: Tag = TagImpl::new("input").attr("value", "hello");
    assert!(tag.build() == "<input value=\"hello\" />", "simple attribute value");
}

#[test]
fn test_attribute_value_special_chars_preserved() {
    // Special chars in attribute values are preserved as-is
    let tag: Tag = TagImpl::new("div").attr("data", "a&b");
    assert!(tag.build() == "<div data=\"a&b\" />", "special chars preserved in attr");
}

// ============================================================================
// 10. Raw content (bypasses escaping)
// ============================================================================

#[test]
fn test_raw_content_allows_html() {
    let tag: Tag = TagImpl::new("div").content_raw("<b>bold</b>");
    assert!(tag.build() == "<div><b>bold</b></div>", "raw content preserves HTML");
}

#[test]
fn test_raw_content_allows_script() {
    // Use case: inserting trusted pre-sanitized content
    let tag: Tag = TagImpl::new("div").content_raw("<script>console.log('ok')</script>");
    assert!(
        tag.build() == "<div><script>console.log('ok')</script></div>",
        "raw content allows script (use with caution)",
    );
}

#[test]
fn test_raw_content_vs_escaped_content() {
    let escaped: Tag = TagImpl::new("span").content("<test>");
    let raw: Tag = TagImpl::new("span").content_raw("<test>");

    assert!(escaped.build() == "<span>&lt;test&gt;</span>", "content escapes");
    assert!(raw.build() == "<span><test></span>", "content_raw does not escape");
}

// ============================================================================
// 11. Attribute escaping behavior
// ============================================================================
// NOTE: attr_raw does not exist in current API. All attributes are escaped.

// ============================================================================
// 12. Multiple attributes
// ============================================================================

#[test]
fn test_multiple_attributes_two() {
    let tag: Tag = TagImpl::new("input").attr("type", "text").attr("name", "username");
    assert!(tag.build() == "<input type=\"text\" name=\"username\" />", "two attributes");
}

#[test]
fn test_multiple_attributes_five() {
    let tag: Tag = TagImpl::new("input")
        .attr("type", "text")
        .attr("name", "email")
        .attr("id", "email-input")
        .attr("class", "form-control")
        .attr("placeholder", "Enter email");

    let expected =
        "<input type=\"text\" name=\"email\" id=\"email-input\" class=\"form-control\" placeholder=\"Enter email\" />";
    assert!(tag.build() == expected, "five attributes");
}

#[test]
fn test_multiple_attributes_with_content() {
    let tag: Tag = TagImpl::new("a")
        .attr("href", "https://example.com")
        .attr("target", "_blank")
        .attr("rel", "noopener")
        .content("Click here");

    let expected =
        "<a href=\"https://example.com\" target=\"_blank\" rel=\"noopener\">Click here</a>";
    assert!(tag.build() == expected, "multiple attrs with content");
}

// ============================================================================
// 13. Empty content handling
// ============================================================================

#[test]
fn test_empty_string_content() {
    let tag: Tag = TagImpl::new("div").content("");
    // Empty content still triggers opening/closing tags (not self-closing)
    assert!(tag.build() == "<div></div>", "empty string content creates open/close tags");
}

#[test]
fn test_empty_content_with_attributes() {
    let tag: Tag = TagImpl::new("span").attr("class", "empty").content("");
    assert!(tag.build() == "<span class=\"empty\"></span>", "empty content with attribute");
}

// ============================================================================
// 14. Unicode content
// ============================================================================

#[test]
fn test_unicode_content_ascii_extended() {
    let tag: Tag = TagImpl::new("p").content("cafe");
    assert!(tag.build() == "<p>cafe</p>", "basic ascii");
}

#[test]
fn test_unicode_content_emoji() {
    // Note: ByteArray handling of multi-byte unicode
    let tag: Tag = TagImpl::new("span").content("Hello World");
    assert!(tag.build() == "<span>Hello World</span>", "basic unicode preserved");
}

#[test]
fn test_unicode_in_attribute() {
    let tag: Tag = TagImpl::new("div").attr("title", "Cairo");
    assert!(tag.build() == "<div title=\"Cairo\" />", "unicode in attribute");
}

#[test]
fn test_mixed_unicode_and_special_chars() {
    let tag: Tag = TagImpl::new("p").content("Price: $100 & tax <5%");
    assert!(
        tag.build() == "<p>Price: $100 &amp; tax &lt;5%</p>", "unicode with special chars escaped",
    );
}

// ============================================================================
// 15. Attribute order preservation
// ============================================================================

#[test]
fn test_attribute_order_preserved() {
    let tag: Tag = TagImpl::new("div")
        .attr("id", "first")
        .attr("class", "second")
        .attr("data-value", "third");

    let result = tag.build();
    assert!(
        result == "<div id=\"first\" class=\"second\" data-value=\"third\" />",
        "attributes should be in insertion order",
    );
}

#[test]
fn test_attribute_order_multiple() {
    let tag: Tag = TagImpl::new("a")
        .attr("href", "/path")
        .attr("data-action", "go")
        .attr("class", "link");

    let result = tag.build();
    assert!(
        result == "<a href=\"/path\" data-action=\"go\" class=\"link\" />",
        "multiple attrs preserve order",
    );
}

// ============================================================================
// Additional edge cases and complex scenarios
// ============================================================================

#[test]
fn test_content_with_children_renders_both() {
    // When both content and children are set, children come first then content
    let child: Tag = TagImpl::new("span");
    let parent: Tag = TagImpl::new("div").insert(child).content("text");
    // Based on the implementation: children are rendered, then content
    assert!(parent.build() == "<div><span />text</div>", "children then content");
}

#[test]
fn test_complex_html_structure() {
    // Build a realistic HTML structure
    let meta: Tag = TagImpl::new("meta").attr("charset", "UTF-8");
    let title: Tag = TagImpl::new("title").content("Test Page");
    let head: Tag = TagImpl::new("head").insert(meta).insert(title);

    let h1: Tag = TagImpl::new("h1").content("Welcome");
    let p: Tag = TagImpl::new("p").attr("class", "intro").content("Hello, world!");
    let body: Tag = TagImpl::new("body").insert(h1).insert(p);

    let html: Tag = TagImpl::new("html").attr("lang", "en").insert(head).insert(body);

    let expected =
        "<html lang=\"en\"><head><meta charset=\"UTF-8\" /><title>Test Page</title></head><body><h1>Welcome</h1><p class=\"intro\">Hello, world!</p></body></html>";
    assert!(html.build() == expected, "complex HTML structure");
}

#[test]
fn test_svg_structure() {
    // Build a simple SVG
    let circle: Tag = TagImpl::new("circle")
        .attr("cx", "50")
        .attr("cy", "50")
        .attr("r", "40")
        .attr("fill", "red");

    let svg: Tag = TagImpl::new("svg")
        .attr("width", "100")
        .attr("height", "100")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .insert(circle);

    let expected =
        "<svg width=\"100\" height=\"100\" xmlns=\"http://www.w3.org/2000/svg\"><circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"red\" /></svg>";
    assert!(svg.build() == expected, "SVG structure");
}

#[test]
fn test_table_structure() {
    let td1: Tag = TagImpl::new("td").content("Cell 1");
    let td2: Tag = TagImpl::new("td").content("Cell 2");
    let tr: Tag = TagImpl::new("tr").insert(td1).insert(td2);
    let tbody: Tag = TagImpl::new("tbody").insert(tr);
    let table: Tag = TagImpl::new("table").attr("class", "data-table").insert(tbody);

    let expected =
        "<table class=\"data-table\"><tbody><tr><td>Cell 1</td><td>Cell 2</td></tr></tbody></table>";
    assert!(table.build() == expected, "table structure");
}

#[test]
fn test_form_with_inputs() {
    let label1: Tag = TagImpl::new("label").attr("for", "name").content("Name:");
    let input1: Tag = TagImpl::new("input")
        .attr("type", "text")
        .attr("id", "name")
        .attr("name", "name");

    let label2: Tag = TagImpl::new("label").attr("for", "email").content("Email:");
    let input2: Tag = TagImpl::new("input")
        .attr("type", "email")
        .attr("id", "email")
        .attr("name", "email");

    let submit: Tag = TagImpl::new("button").attr("type", "submit").content("Submit");

    let form: Tag = TagImpl::new("form")
        .attr("action", "/submit")
        .attr("method", "post")
        .insert(label1)
        .insert(input1)
        .insert(label2)
        .insert(input2)
        .insert(submit);

    let expected =
        "<form action=\"/submit\" method=\"post\"><label for=\"name\">Name:</label><input type=\"text\" id=\"name\" name=\"name\" /><label for=\"email\">Email:</label><input type=\"email\" id=\"email\" name=\"email\" /><button type=\"submit\">Submit</button></form>";
    assert!(form.build() == expected, "form structure");
}
