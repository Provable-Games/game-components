//! Tests for HTML document construction patterns based on examples/minimal_html.cairo
//!
//! These tests verify that the graffiti library can construct various HTML elements
//! and complete documents using the fluent Tag API.

use graffiti::{Tag, TagImpl};

// ============================================================================
// Complete HTML Document Tests
// ============================================================================

#[test]
fn test_complete_html_document() {
    // Build a complete HTML document similar to minimal_html example
    let mut html: Tag = TagImpl::new("html").attr("lang", "en");

    let mut head: Tag = TagImpl::new("head");
    let meta: Tag = TagImpl::new("meta").attr("charset", "utf-8");
    let title: Tag = TagImpl::new("title").content("Built by Graffiti");
    head = head.insert(meta).insert(title);

    let p: Tag = TagImpl::new("p").content("Hello, world!");
    let body: Tag = TagImpl::new("body").insert(p);

    let result = html.insert(head).insert(body).build();

    assert!(
        result == "<html lang=\"en\"><head><meta charset=\"utf-8\" /><title>Built by Graffiti</title></head><body><p>Hello, world!</p></body></html>",
        "complete HTML document mismatch",
    );
}

#[test]
fn test_html_with_doctype_simulation() {
    // While graffiti builds tags, we can prepend doctype manually
    let html: Tag = TagImpl::new("html").attr("lang", "en");
    let body: Tag = TagImpl::new("body").content("Content");

    let html_str = html.insert(body).build();

    // Verify the html tag structure
    assert!(html_str == "<html lang=\"en\"><body>Content</body></html>", "html structure mismatch");
}

// ============================================================================
// Meta and Charset Tests
// ============================================================================

#[test]
fn test_meta_charset_utf8() {
    let meta: Tag = TagImpl::new("meta").attr("charset", "utf-8");
    let result = meta.build();
    assert!(result == "<meta charset=\"utf-8\" />", "meta charset mismatch");
}

#[test]
fn test_meta_viewport() {
    let meta: Tag = TagImpl::new("meta")
        .attr("name", "viewport")
        .attr("content", "width=device-width, initial-scale=1.0");
    let result = meta.build();
    assert!(
        result == "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />",
        "meta viewport mismatch",
    );
}

#[test]
fn test_meta_description() {
    let meta: Tag = TagImpl::new("meta")
        .attr("name", "description")
        .attr("content", "A graffiti-built page");
    let result = meta.build();
    assert!(
        result == "<meta name=\"description\" content=\"A graffiti-built page\" />",
        "meta description mismatch",
    );
}

// ============================================================================
// Head Section Tests
// ============================================================================

#[test]
fn test_head_with_title() {
    let title: Tag = TagImpl::new("title").content("My Page Title");
    let head: Tag = TagImpl::new("head").insert(title);
    let result = head.build();
    assert!(result == "<head><title>My Page Title</title></head>", "head with title mismatch");
}

#[test]
fn test_head_with_multiple_elements() {
    let meta: Tag = TagImpl::new("meta").attr("charset", "utf-8");
    let title: Tag = TagImpl::new("title").content("Test Page");
    let link: Tag = TagImpl::new("link").attr("rel", "stylesheet").attr("href", "style.css");

    let head: Tag = TagImpl::new("head").insert(meta).insert(title).insert(link);
    let result = head.build();

    assert!(
        result == "<head><meta charset=\"utf-8\" /><title>Test Page</title><link rel=\"stylesheet\" href=\"style.css\" /></head>",
        "head with multiple elements mismatch",
    );
}

#[test]
fn test_script_tag_in_head() {
    let script: Tag = TagImpl::new("script").attr("src", "script.js");
    let head: Tag = TagImpl::new("head").insert(script);
    let result = head.build();
    assert!(result == "<head><script src=\"script.js\" /></head>", "script in head mismatch");
}

// ============================================================================
// Body Content Tests
// ============================================================================

#[test]
fn test_body_with_paragraph() {
    let p: Tag = TagImpl::new("p").content("Hello, world!");
    let body: Tag = TagImpl::new("body").insert(p);
    let result = body.build();
    assert!(result == "<body><p>Hello, world!</p></body>", "body with paragraph mismatch");
}

#[test]
fn test_body_with_multiple_paragraphs() {
    let p1: Tag = TagImpl::new("p").content("First paragraph");
    let p2: Tag = TagImpl::new("p").content("Second paragraph");
    let p3: Tag = TagImpl::new("p").content("Third paragraph");

    let body: Tag = TagImpl::new("body").insert(p1).insert(p2).insert(p3);
    let result = body.build();

    assert!(
        result == "<body><p>First paragraph</p><p>Second paragraph</p><p>Third paragraph</p></body>",
        "body with multiple paragraphs mismatch",
    );
}

// ============================================================================
// Nested Div Tests
// ============================================================================

#[test]
fn test_single_div() {
    let div: Tag = TagImpl::new("div").attr("class", "container");
    let result = div.build();
    assert!(result == "<div class=\"container\" />", "single div mismatch");
}

#[test]
fn test_nested_divs_two_levels() {
    let inner: Tag = TagImpl::new("div").attr("class", "inner").content("Content");
    let outer: Tag = TagImpl::new("div").attr("class", "outer").insert(inner);
    let result = outer.build();
    assert!(
        result == "<div class=\"outer\"><div class=\"inner\">Content</div></div>",
        "nested divs two levels mismatch",
    );
}

#[test]
fn test_nested_divs_three_levels() {
    let innermost: Tag = TagImpl::new("div").attr("class", "level-3").content("Deep content");
    let middle: Tag = TagImpl::new("div").attr("class", "level-2").insert(innermost);
    let outer: Tag = TagImpl::new("div").attr("class", "level-1").insert(middle);
    let result = outer.build();
    assert!(
        result == "<div class=\"level-1\"><div class=\"level-2\"><div class=\"level-3\">Deep content</div></div></div>",
        "nested divs three levels mismatch",
    );
}

#[test]
fn test_div_with_multiple_children() {
    let child1: Tag = TagImpl::new("div").attr("class", "child").content("Child 1");
    let child2: Tag = TagImpl::new("div").attr("class", "child").content("Child 2");
    let parent: Tag = TagImpl::new("div").attr("class", "parent").insert(child1).insert(child2);
    let result = parent.build();
    assert!(
        result == "<div class=\"parent\"><div class=\"child\">Child 1</div><div class=\"child\">Child 2</div></div>",
        "div with multiple children mismatch",
    );
}

// ============================================================================
// Link Element Tests
// ============================================================================

#[test]
fn test_anchor_tag_basic() {
    let a: Tag = TagImpl::new("a").attr("href", "https://example.com").content("Click here");
    let result = a.build();
    assert!(
        result == "<a href=\"https://example.com\">Click here</a>", "anchor tag basic mismatch",
    );
}

#[test]
fn test_anchor_tag_with_target() {
    let a: Tag = TagImpl::new("a")
        .attr("href", "https://example.com")
        .attr("target", "_blank")
        .content("External Link");
    let result = a.build();
    assert!(
        result == "<a href=\"https://example.com\" target=\"_blank\">External Link</a>",
        "anchor with target mismatch",
    );
}

#[test]
fn test_anchor_tag_with_rel() {
    let a: Tag = TagImpl::new("a")
        .attr("href", "https://example.com")
        .attr("rel", "noopener noreferrer")
        .content("Safe Link");
    let result = a.build();
    assert!(
        result == "<a href=\"https://example.com\" rel=\"noopener noreferrer\">Safe Link</a>",
        "anchor with rel mismatch",
    );
}

#[test]
fn test_stylesheet_link() {
    let link: Tag = TagImpl::new("link").attr("rel", "stylesheet").attr("href", "styles.css");
    let result = link.build();
    assert!(
        result == "<link rel=\"stylesheet\" href=\"styles.css\" />", "stylesheet link mismatch",
    );
}

// ============================================================================
// List Element Tests
// ============================================================================

#[test]
fn test_unordered_list_basic() {
    let li1: Tag = TagImpl::new("li").content("Item 1");
    let li2: Tag = TagImpl::new("li").content("Item 2");
    let li3: Tag = TagImpl::new("li").content("Item 3");

    let ul: Tag = TagImpl::new("ul").insert(li1).insert(li2).insert(li3);
    let result = ul.build();

    assert!(
        result == "<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>",
        "unordered list mismatch",
    );
}

#[test]
fn test_ordered_list_basic() {
    let li1: Tag = TagImpl::new("li").content("First");
    let li2: Tag = TagImpl::new("li").content("Second");
    let li3: Tag = TagImpl::new("li").content("Third");

    let ol: Tag = TagImpl::new("ol").insert(li1).insert(li2).insert(li3);
    let result = ol.build();

    assert!(
        result == "<ol><li>First</li><li>Second</li><li>Third</li></ol>", "ordered list mismatch",
    );
}

#[test]
fn test_list_with_styled_items() {
    let li1: Tag = TagImpl::new("li").attr("class", "item").content("Styled Item 1");
    let li2: Tag = TagImpl::new("li").attr("class", "item").content("Styled Item 2");

    let ul: Tag = TagImpl::new("ul").attr("class", "list").insert(li1).insert(li2);
    let result = ul.build();

    assert!(
        result == "<ul class=\"list\"><li class=\"item\">Styled Item 1</li><li class=\"item\">Styled Item 2</li></ul>",
        "styled list mismatch",
    );
}

#[test]
fn test_nested_list() {
    let sub_li1: Tag = TagImpl::new("li").content("Sub Item 1");
    let sub_li2: Tag = TagImpl::new("li").content("Sub Item 2");
    let sub_ul: Tag = TagImpl::new("ul").insert(sub_li1).insert(sub_li2);

    let li_with_sublist: Tag = TagImpl::new("li").content_raw("Parent Item").insert(sub_ul);
    let outer_ul: Tag = TagImpl::new("ul").insert(li_with_sublist);
    let result = outer_ul.build();

    // Note: content comes after children in current implementation
    assert!(
        result == "<ul><li><ul><li>Sub Item 1</li><li>Sub Item 2</li></ul>Parent Item</li></ul>",
        "nested list mismatch",
    );
}

// ============================================================================
// Form Element Tests (bonus HTML patterns)
// ============================================================================

#[test]
fn test_input_element() {
    let input: Tag = TagImpl::new("input")
        .attr("type", "text")
        .attr("name", "username")
        .attr("placeholder", "Enter username");
    let result = input.build();
    assert!(
        result == "<input type=\"text\" name=\"username\" placeholder=\"Enter username\" />",
        "input element mismatch",
    );
}

#[test]
fn test_form_with_input() {
    let input: Tag = TagImpl::new("input").attr("type", "text").attr("name", "email");
    let button: Tag = TagImpl::new("button").attr("type", "submit").content("Submit");
    let form: Tag = TagImpl::new("form")
        .attr("action", "/submit")
        .attr("method", "post")
        .insert(input)
        .insert(button);
    let result = form.build();

    assert!(
        result == "<form action=\"/submit\" method=\"post\"><input type=\"text\" name=\"email\" /><button type=\"submit\">Submit</button></form>",
        "form with input mismatch",
    );
}

// ============================================================================
// Semantic HTML Tests
// ============================================================================

#[test]
fn test_header_element() {
    let nav: Tag = TagImpl::new("nav").content("Navigation");
    let header: Tag = TagImpl::new("header").insert(nav);
    let result = header.build();
    assert!(result == "<header><nav>Navigation</nav></header>", "header element mismatch");
}

#[test]
fn test_footer_element() {
    let footer: Tag = TagImpl::new("footer").content("Copyright 2024");
    let result = footer.build();
    assert!(result == "<footer>Copyright 2024</footer>", "footer element mismatch");
}

#[test]
fn test_article_element() {
    let h2: Tag = TagImpl::new("h2").content("Article Title");
    let p: Tag = TagImpl::new("p").content("Article content goes here.");
    let article: Tag = TagImpl::new("article").insert(h2).insert(p);
    let result = article.build();
    assert!(
        result == "<article><h2>Article Title</h2><p>Article content goes here.</p></article>",
        "article element mismatch",
    );
}

#[test]
fn test_section_element() {
    let h3: Tag = TagImpl::new("h3").content("Section Title");
    let section: Tag = TagImpl::new("section").attr("id", "intro").insert(h3);
    let result = section.build();
    assert!(
        result == "<section id=\"intro\"><h3>Section Title</h3></section>",
        "section element mismatch",
    );
}
