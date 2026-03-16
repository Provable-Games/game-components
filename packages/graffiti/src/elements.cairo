//! Tag builder for XML/HTML/SVG construction.
//!
//! Provides a fluent API for constructing tags with attributes, content, and nested children.
//! Content is automatically XML-escaped by default for security.

use graffiti::escape::escape_xml;

//
// Attribute
//

#[derive(Drop)]
pub struct Attribute {
    pub name: ByteArray,
    pub value: ByteArray,
}

impl AttributeToBytes of super::ToBytes<Attribute> {
    #[inline]
    fn to_bytes(self: Attribute) -> ByteArray {
        let mut result: ByteArray = Default::default();
        result.append(@self.name);
        result.append_word('="', 2);
        result.append(@self.value);
        result.append_word('"', 1);
        result
    }
}

impl AttributeArrayToBytes of super::ToBytes<Array<Attribute>> {
    #[inline]
    fn to_bytes(mut self: Array<Attribute>) -> ByteArray {
        let mut s: ByteArray = Default::default();
        while let Option::Some(attr) = self.pop_front() {
            s.append_word(' ', 1);
            s.append(@attr.to_bytes());
        }
        s
    }
}

//
// Tag
//

#[derive(Drop)]
pub struct Tag {
    pub name: ByteArray,
    pub attrs: Option<Array<Attribute>>,
    pub children: Option<Array<Tag>>,
    pub content: Option<ByteArray>,
}

impl TagToBytes of super::ToBytes<Tag> {
    #[inline]
    fn to_bytes(self: Tag) -> ByteArray {
        self.build()
    }
}

impl TagArrayToBytes of super::ToBytes<Array<Tag>> {
    fn to_bytes(mut self: Array<Tag>) -> ByteArray {
        let mut s: ByteArray = Default::default();
        while let Option::Some(tag) = self.pop_front() {
            s.append(@tag.to_bytes());
        }
        s
    }
}

//
// TagBuilder trait
//

pub trait TagBuilder<T> {
    /// Creates a new tag with the given name.
    fn new(name: ByteArray) -> T;

    /// Builds the tag into its string representation.
    fn build(self: T) -> ByteArray;

    /// Adds an attribute to the tag.
    fn attr(self: T, name: ByteArray, value: ByteArray) -> T;

    /// Sets the text content of the tag (auto-escaped for XML/HTML safety).
    fn content(self: T, content: ByteArray) -> T;

    /// Sets the text content of the tag without escaping (use with caution).
    fn content_raw(self: T, content: ByteArray) -> T;

    /// Inserts a child tag.
    fn insert(self: T, child: T) -> T;
}

pub impl TagImpl of TagBuilder<Tag> {
    fn new(name: ByteArray) -> Tag {
        Tag { name: name, attrs: Option::None, children: Option::None, content: Option::None }
    }

    fn build(self: Tag) -> ByteArray {
        let Tag { name, attrs, children, content } = self;
        let mut result: ByteArray = Default::default();

        let has_attrs = attrs.is_some();
        let has_children = children.is_some();
        let has_content = content.is_some();

        // Fast path: self-closing tag with no attributes
        if !has_attrs && !has_children && !has_content {
            result.append_word('<', 1);
            result.append(@name);
            result.append_word(' /', 2);
            result.append_word('>', 1);
            return result;
        }

        // Build opening tag
        result.append_word('<', 1);
        result.append(@name);

        // Append attributes inline
        if let Option::Some(mut attrs_array) = attrs {
            while let Option::Some(attr) = attrs_array.pop_front() {
                result.append_word(' ', 1);
                result.append(@attr.name);
                result.append_word('="', 2);
                result.append(@attr.value);
                result.append_word('"', 1);
            }
        }

        // Self-closing if no content
        if !has_children && !has_content {
            result.append_word(' /', 2);
            result.append_word('>', 1);
            return result;
        }

        result.append_word('>', 1);

        // Append children inline
        if let Option::Some(mut children_array) = children {
            while let Option::Some(child) = children_array.pop_front() {
                result.append(@child.build());
            }
        }

        // Append content
        if let Option::Some(content_str) = content {
            result.append(@content_str);
        }

        // Closing tag
        result.append_word('<', 1);
        result.append_word('/', 1);
        result.append(@name);
        result.append_word('>', 1);

        result
    }

    fn attr(mut self: Tag, name: ByteArray, value: ByteArray) -> Tag {
        if self.attrs.is_none() {
            self.attrs = Option::Some(array![Attribute { name, value }]);
        } else {
            let mut attrs = self.attrs.unwrap();
            attrs.append(Attribute { name, value });
            self.attrs = Option::Some(attrs);
        }
        self
    }

    fn content(mut self: Tag, content: ByteArray) -> Tag {
        // Auto-escape XML special characters for safety
        self.content = Option::Some(escape_xml(content));
        self
    }

    fn content_raw(mut self: Tag, content: ByteArray) -> Tag {
        // No escaping - use with caution
        self.content = Option::Some(content);
        self
    }

    fn insert(mut self: Tag, child: Tag) -> Tag {
        if self.children.is_none() {
            self.children = Option::Some(array![child]);
        } else {
            let mut children = self.children.unwrap();
            children.append(child);
            self.children = Option::Some(children);
        }
        self
    }
}


#[cfg(test)]
mod tests {
    use super::{Tag, TagImpl};

    #[test]
    fn test_build_empty() {
        let tag: Tag = TagImpl::new("html");
        assert!(tag.build() == "<html />", "build mismatch");
    }

    #[test]
    fn test_build_with_attrs() {
        let rect: Tag = TagImpl::new("rect").attr("width", "200");
        assert!(rect.build() == "<rect width=\"200\" />", "build rect 1");

        let rect: Tag = TagImpl::new("rect").attr("width", "200").attr("height", "100");
        assert!(rect.build() == "<rect width=\"200\" height=\"100\" />", "build rect 2");
    }

    #[test]
    fn test_build_with_content() {
        let div: Tag = TagImpl::new("div").content("Hello, world!");
        assert!(div.build() == "<div>Hello, world!</div>", "build div");
    }

    #[test]
    fn test_build_with_attrs_and_content() {
        let div: Tag = TagImpl::new("div").attr("class", "big").content("Hello, world!");
        assert!(div.build() == "<div class=\"big\">Hello, world!</div>", "build div");
    }

    #[test]
    fn test_insert_one_child() {
        let html: Tag = TagImpl::new("html");
        let head: Tag = TagImpl::new("head");
        assert!(html.insert(head).build() == "<html><head /></html>", "should have one child");
    }

    #[test]
    fn test_insert_multiple_children() {
        let body: Tag = TagImpl::new("body");
        let h1: Tag = TagImpl::new("h1");
        let h2: Tag = TagImpl::new("h2");
        let p: Tag = TagImpl::new("p");
        let built = body.insert(h1).insert(h2).insert(p).build();
        assert!(built == "<body><h1 /><h2 /><p /></body>", "should have three children");
    }

    #[test]
    fn test_build_one_child_with_attrs() {
        let div: Tag = TagImpl::new("div");
        let p: Tag = TagImpl::new("p").attr("class", "foo").attr("id", "bar");
        let built = div.insert(p).build();
        assert!(built == "<div><p class=\"foo\" id=\"bar\" /></div>", "built");
    }

    #[test]
    fn test_build_multiple_children_and_attrs() {
        let body: Tag = TagImpl::new("body");
        let h1: Tag = TagImpl::new("h1").attr("class", "main").attr("title", "heading");
        let h2: Tag = TagImpl::new("h2").attr("class", "sub").attr("title", "subtitle");
        let p: Tag = TagImpl::new("p");
        let text: Tag = TagImpl::new("text").attr("class", "r");
        let built = body.insert(h1).insert(h2).insert(p.insert(text)).build();
        assert!(
            built == "<body><h1 class=\"main\" title=\"heading\" /><h2 class=\"sub\" title=\"subtitle\" /><p><text class=\"r\" /></p></body>",
            "built",
        );
    }

    #[test]
    fn test_build_nested_structure() {
        // Build head with meta
        let meta: Tag = TagImpl::new("meta")
            .attr("name", "keywords")
            .attr("content", "graffiti, cairo, starknet");
        let head: Tag = TagImpl::new("head").insert(meta);

        // Build body with multiple children
        let h1: Tag = TagImpl::new("h1").attr("class", "main").content("Title");
        let p: Tag = TagImpl::new("p").content("Hello, world!");
        let body: Tag = TagImpl::new("body").insert(h1).insert(p);

        // Combine into html
        let html: Tag = TagImpl::new("html").insert(head).insert(body);

        let expected =
            "<html><head><meta name=\"keywords\" content=\"graffiti, cairo, starknet\" /></head><body><h1 class=\"main\">Title</h1><p>Hello, world!</p></body></html>";
        assert!(html.build() == expected, "built");
    }

    // Tests for auto-escaping

    #[test]
    fn test_content_escapes_angle_brackets() {
        let div: Tag = TagImpl::new("div").content("<script>alert('xss')</script>");
        assert!(
            div.build() == "<div>&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;</div>",
            "should escape angle brackets",
        );
    }

    #[test]
    fn test_content_escapes_ampersand() {
        let p: Tag = TagImpl::new("p").content("Tom & Jerry");
        assert!(p.build() == "<p>Tom &amp; Jerry</p>", "should escape ampersand");
    }

    #[test]
    fn test_content_escapes_quotes() {
        let span: Tag = TagImpl::new("span").content("Say \"hello\"");
        assert!(span.build() == "<span>Say &quot;hello&quot;</span>", "should escape quotes");
    }

    #[test]
    fn test_content_raw_no_escaping() {
        // content_raw should NOT escape - use for trusted pre-escaped content
        let div: Tag = TagImpl::new("div").content_raw("<b>bold</b>");
        assert!(div.build() == "<div><b>bold</b></div>", "should not escape raw content");
    }

    #[test]
    fn test_content_raw_vs_content() {
        let escaped: Tag = TagImpl::new("p").content("<test>");
        let raw: Tag = TagImpl::new("p").content_raw("<test>");

        assert!(escaped.build() == "<p>&lt;test&gt;</p>", "content escapes");
        assert!(raw.build() == "<p><test></p>", "content_raw does not escape");
    }
}
