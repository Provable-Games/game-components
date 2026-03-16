//! JSON builder with proper type support.
//!
//! Provides fluent API for constructing JSON objects with proper handling
//! of strings (escaped), numbers (unquoted), booleans, nulls, and nested structures.

use graffiti::escape::escape_json_string;
use graffiti::format::{
    felt252_to_string, i128_to_string, i64_to_string, u128_to_string, u16_to_string, u256_to_string,
    u32_to_string, u64_to_string, u8_to_string,
};
use graffiti::utils::constants::{
    BRACKET_CLOSE, BRACKET_OPEN, COLON, COMMA, QUOTE, SQUARE_BRACKET_CLOSE, SQUARE_BRACKET_OPEN,
};
use graffiti::utils::starts_with_bracket;


#[derive(Drop)]
pub struct JsonBuilder {
    data: Array<JsonAttribute>,
}

impl JsonBuilderDefault of Default<JsonBuilder> {
    fn default() -> JsonBuilder {
        JsonBuilder { data: array![] }
    }
}


#[derive(Drop)]
struct JsonAttribute {
    key: ByteArray,
    value: ByteArray,
    is_raw: bool // If true, value is not quoted (for numbers, bools, null, objects, arrays)
}

/// Converts an attribute to its JSON string representation.
fn attribute_to_bytes(attr: JsonAttribute) -> ByteArray {
    let mut ba: ByteArray = Default::default();

    ba.append_word(QUOTE, 1);
    ba.append(@attr.key);
    ba.append_word(QUOTE, 1);
    ba.append_word(COLON, 1);

    if attr.is_raw {
        ba.append(@attr.value);
    } else {
        ba.append_word(QUOTE, 1);
        ba.append(@attr.value);
        ba.append_word(QUOTE, 1);
    }
    ba
}

/// Trait for building JSON objects with fluent API.
pub trait Builder<T> {
    /// Creates a new empty JSON builder.
    fn new() -> T;

    /// Adds a string value (escaped and quoted).
    fn add(self: T, key: ByteArray, value: ByteArray) -> T;

    /// Adds an array of string values.
    fn add_array(self: T, key: ByteArray, value: Span<ByteArray>) -> T;

    /// Builds the final JSON string.
    fn build(self: T) -> ByteArray;
}

/// Extended builder trait with additional type support.
pub trait BuilderExt<T> {
    /// Adds a numeric value (unquoted).
    fn add_number_u8(self: T, key: ByteArray, value: u8) -> T;
    fn add_number_u16(self: T, key: ByteArray, value: u16) -> T;
    fn add_number_u32(self: T, key: ByteArray, value: u32) -> T;
    fn add_number_u64(self: T, key: ByteArray, value: u64) -> T;
    fn add_number_u128(self: T, key: ByteArray, value: u128) -> T;
    fn add_number_u256(self: T, key: ByteArray, value: u256) -> T;
    fn add_number_felt252(self: T, key: ByteArray, value: felt252) -> T;
    fn add_number_i64(self: T, key: ByteArray, value: i64) -> T;
    fn add_number_i128(self: T, key: ByteArray, value: i128) -> T;

    /// Adds a boolean value (true/false, unquoted).
    fn add_bool(self: T, key: ByteArray, value: bool) -> T;

    /// Adds a null value.
    fn add_null(self: T, key: ByteArray) -> T;

    /// Adds a raw JSON value (no escaping or quoting).
    /// Use for nested objects or pre-built JSON.
    fn add_raw(self: T, key: ByteArray, value: ByteArray) -> T;

    /// Adds an array of numeric values.
    fn add_number_array_u64(self: T, key: ByteArray, values: Span<u64>) -> T;
    fn add_number_array_u256(self: T, key: ByteArray, values: Span<u256>) -> T;

    /// Adds an array of boolean values.
    fn add_bool_array(self: T, key: ByteArray, values: Span<bool>) -> T;
}

pub impl JsonImpl of Builder<JsonBuilder> {
    fn new() -> JsonBuilder {
        JsonBuilder { data: array![] }
    }

    fn add(mut self: JsonBuilder, key: ByteArray, value: ByteArray) -> JsonBuilder {
        // Escape the string value
        let escaped = escape_json_string(value);
        self.data.append(JsonAttribute { key, value: escaped, is_raw: false });
        self
    }

    fn add_array(mut self: JsonBuilder, key: ByteArray, mut value: Span<ByteArray>) -> JsonBuilder {
        let mut str: ByteArray = "";
        str.append_word(SQUARE_BRACKET_OPEN, 1);
        let mut first = true;
        while let Option::Some(v) = value.pop_front() {
            if !first {
                str.append_word(COMMA, 1);
            }
            first = false;
            if starts_with_bracket(v) {
                str.append(v);
            } else {
                str.append_word(QUOTE, 1);
                str.append(@escape_json_string(v.clone()));
                str.append_word(QUOTE, 1);
            }
        }
        str.append_word(SQUARE_BRACKET_CLOSE, 1);

        self.data.append(JsonAttribute { key, value: str, is_raw: true });
        self
    }


    fn build(mut self: JsonBuilder) -> ByteArray {
        let mut ba: ByteArray = Default::default();

        ba.append_word(BRACKET_OPEN, 1);

        let mut first = true;
        while let Option::Some(attr) = self.data.pop_front() {
            if !first {
                ba.append_word(COMMA, 1);
            }
            first = false;
            ba.append(@attribute_to_bytes(attr));
        }

        ba.append_word(BRACKET_CLOSE, 1);

        ba
    }
}

pub impl JsonImplExt of BuilderExt<JsonBuilder> {
    fn add_number_u8(mut self: JsonBuilder, key: ByteArray, value: u8) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value: u8_to_string(value), is_raw: true });
        self
    }

    fn add_number_u16(mut self: JsonBuilder, key: ByteArray, value: u16) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value: u16_to_string(value), is_raw: true });
        self
    }

    fn add_number_u32(mut self: JsonBuilder, key: ByteArray, value: u32) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value: u32_to_string(value), is_raw: true });
        self
    }

    fn add_number_u64(mut self: JsonBuilder, key: ByteArray, value: u64) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value: u64_to_string(value), is_raw: true });
        self
    }

    fn add_number_u128(mut self: JsonBuilder, key: ByteArray, value: u128) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value: u128_to_string(value), is_raw: true });
        self
    }

    fn add_number_u256(mut self: JsonBuilder, key: ByteArray, value: u256) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value: u256_to_string(value), is_raw: true });
        self
    }

    fn add_number_felt252(mut self: JsonBuilder, key: ByteArray, value: felt252) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value: felt252_to_string(value), is_raw: true });
        self
    }

    fn add_number_i64(mut self: JsonBuilder, key: ByteArray, value: i64) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value: i64_to_string(value), is_raw: true });
        self
    }

    fn add_number_i128(mut self: JsonBuilder, key: ByteArray, value: i128) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value: i128_to_string(value), is_raw: true });
        self
    }

    fn add_bool(mut self: JsonBuilder, key: ByteArray, value: bool) -> JsonBuilder {
        let bool_str = if value {
            "true"
        } else {
            "false"
        };
        self.data.append(JsonAttribute { key, value: bool_str, is_raw: true });
        self
    }

    fn add_null(mut self: JsonBuilder, key: ByteArray) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value: "null", is_raw: true });
        self
    }

    fn add_raw(mut self: JsonBuilder, key: ByteArray, value: ByteArray) -> JsonBuilder {
        self.data.append(JsonAttribute { key, value, is_raw: true });
        self
    }

    fn add_number_array_u64(
        mut self: JsonBuilder, key: ByteArray, mut values: Span<u64>,
    ) -> JsonBuilder {
        let mut str: ByteArray = "";
        str.append_word(SQUARE_BRACKET_OPEN, 1);
        let mut first = true;
        while let Option::Some(v) = values.pop_front() {
            if !first {
                str.append_word(COMMA, 1);
            }
            first = false;
            str.append(@u64_to_string(*v));
        }
        str.append_word(SQUARE_BRACKET_CLOSE, 1);

        self.data.append(JsonAttribute { key, value: str, is_raw: true });
        self
    }

    fn add_number_array_u256(
        mut self: JsonBuilder, key: ByteArray, mut values: Span<u256>,
    ) -> JsonBuilder {
        let mut str: ByteArray = "";
        str.append_word(SQUARE_BRACKET_OPEN, 1);
        let mut first = true;
        while let Option::Some(v) = values.pop_front() {
            if !first {
                str.append_word(COMMA, 1);
            }
            first = false;
            str.append(@u256_to_string(*v));
        }
        str.append_word(SQUARE_BRACKET_CLOSE, 1);

        self.data.append(JsonAttribute { key, value: str, is_raw: true });
        self
    }

    fn add_bool_array(
        mut self: JsonBuilder, key: ByteArray, mut values: Span<bool>,
    ) -> JsonBuilder {
        let mut str: ByteArray = "";
        str.append_word(SQUARE_BRACKET_OPEN, 1);
        let mut first = true;
        while let Option::Some(v) = values.pop_front() {
            if !first {
                str.append_word(COMMA, 1);
            }
            first = false;
            if *v {
                str.append(@"true");
            } else {
                str.append(@"false");
            }
        }
        str.append_word(SQUARE_BRACKET_CLOSE, 1);

        self.data.append(JsonAttribute { key, value: str, is_raw: true });
        self
    }
}


//
// JSON Array Builder
//

#[derive(Drop)]
pub struct JsonArrayBuilder {
    items: Array<ByteArray>,
}

/// Trait for building JSON arrays with fluent API.
pub trait ArrayBuilder<T> {
    /// Creates a new empty JSON array builder.
    fn new() -> T;

    /// Pushes a string value (escaped and quoted).
    fn push(self: T, value: ByteArray) -> T;

    /// Pushes a numeric value (unquoted).
    fn push_number_u64(self: T, value: u64) -> T;
    fn push_number_u256(self: T, value: u256) -> T;

    /// Pushes a boolean value.
    fn push_bool(self: T, value: bool) -> T;

    /// Pushes a null value.
    fn push_null(self: T) -> T;

    /// Pushes a raw JSON object or array (no escaping).
    fn push_object(self: T, obj: ByteArray) -> T;

    /// Builds the final JSON array string.
    fn build(self: T) -> ByteArray;
}

pub impl JsonArrayImpl of ArrayBuilder<JsonArrayBuilder> {
    fn new() -> JsonArrayBuilder {
        JsonArrayBuilder { items: array![] }
    }

    fn push(mut self: JsonArrayBuilder, value: ByteArray) -> JsonArrayBuilder {
        let mut item: ByteArray = "\"";
        item.append(@escape_json_string(value));
        item.append(@"\"");
        self.items.append(item);
        self
    }

    fn push_number_u64(mut self: JsonArrayBuilder, value: u64) -> JsonArrayBuilder {
        self.items.append(u64_to_string(value));
        self
    }

    fn push_number_u256(mut self: JsonArrayBuilder, value: u256) -> JsonArrayBuilder {
        self.items.append(u256_to_string(value));
        self
    }

    fn push_bool(mut self: JsonArrayBuilder, value: bool) -> JsonArrayBuilder {
        if value {
            self.items.append("true");
        } else {
            self.items.append("false");
        }
        self
    }

    fn push_null(mut self: JsonArrayBuilder) -> JsonArrayBuilder {
        self.items.append("null");
        self
    }

    fn push_object(mut self: JsonArrayBuilder, obj: ByteArray) -> JsonArrayBuilder {
        self.items.append(obj);
        self
    }

    fn build(mut self: JsonArrayBuilder) -> ByteArray {
        let mut result: ByteArray = "[";
        let mut first = true;
        while let Option::Some(item) = self.items.pop_front() {
            if !first {
                result.append(@",");
            }
            first = false;
            result.append(@item);
        }
        result.append(@"]");
        result
    }
}


//
// ERC721 Metadata Helper
//

/// Creates standard ERC721 metadata JSON.
///
/// # Arguments
/// * `name` - Token name
/// * `description` - Token description
/// * `image` - Image URL or data URI
/// * `attributes` - Array of (trait_type, value) pairs
///
/// # Returns
/// JSON string in ERC721 metadata format
pub fn erc721_metadata(
    name: ByteArray,
    description: ByteArray,
    image: ByteArray,
    attributes: Span<(ByteArray, ByteArray)>,
) -> ByteArray {
    let mut json = JsonImpl::new()
        .add("name", name)
        .add("description", description)
        .add("image", image);

    // Build attributes array
    let mut attrs_array = JsonArrayImpl::new();
    let mut attrs = attributes;
    while let Option::Some((trait_type, value)) = attrs.pop_front() {
        let attr_obj = JsonImpl::new()
            .add("trait_type", trait_type.clone())
            .add("value", value.clone())
            .build();
        attrs_array = attrs_array.push_object(attr_obj);
    }

    json = JsonImplExt::add_raw(json, "attributes", attrs_array.build());
    json.build()
}

/// Creates ERC721 metadata with numeric attribute values.
///
/// # Arguments
/// * `name` - Token name
/// * `description` - Token description
/// * `image` - Image URL or data URI
/// * `string_attributes` - Array of (trait_type, value) string pairs
/// * `number_attributes` - Array of (trait_type, value) numeric pairs
///
/// # Returns
/// JSON string in ERC721 metadata format
pub fn erc721_metadata_with_numbers(
    name: ByteArray,
    description: ByteArray,
    image: ByteArray,
    string_attributes: Span<(ByteArray, ByteArray)>,
    number_attributes: Span<(ByteArray, u64)>,
) -> ByteArray {
    let mut json = JsonImpl::new()
        .add("name", name)
        .add("description", description)
        .add("image", image);

    // Build attributes array
    let mut attrs_array = JsonArrayImpl::new();

    let mut str_attrs = string_attributes;
    while let Option::Some((trait_type, value)) = str_attrs.pop_front() {
        let attr_obj = JsonImpl::new()
            .add("trait_type", trait_type.clone())
            .add("value", value.clone())
            .build();
        attrs_array = attrs_array.push_object(attr_obj);
    }

    let mut num_attrs = number_attributes;
    while let Option::Some((trait_type, value)) = num_attrs.pop_front() {
        let attr_obj = JsonImpl::new()
            .add("trait_type", trait_type.clone())
            .add_number_u64("value", *value)
            .build();
        attrs_array = attrs_array.push_object(attr_obj);
    }

    json = JsonImplExt::add_raw(json, "attributes", attrs_array.build());
    json.build()
}


#[cfg(test)]
mod tests {
    use super::{
        ArrayBuilder, Builder, BuilderExt, JsonArrayImpl, JsonImpl, erc721_metadata,
        erc721_metadata_with_numbers,
    };

    #[test]
    fn test_add() {
        let data = JsonImpl::new()
            .add("name", "Token Name")
            .add("description", "A description of what this token represents")
            .build();

        assert!(
            data == "{\"name\":\"Token Name\",\"description\":\"A description of what this token represents\"}",
            "wrong json data",
        );
    }

    #[test]
    fn test_add_escapes_strings() {
        let data = JsonImpl::new().add("text", "Hello \"World\"").build();
        assert!(data == "{\"text\":\"Hello \\\"World\\\"\"}", "should escape quotes");

        let data2 = JsonImpl::new().add("text", "line1\nline2").build();
        assert!(data2 == "{\"text\":\"line1\\nline2\"}", "should escape newlines");
    }

    #[test]
    fn test_add_number_u64() {
        let data = JsonImpl::new().add_number_u64("count", 42).build();
        assert!(data == "{\"count\":42}", "number should not be quoted");
    }

    #[test]
    fn test_add_number_u256() {
        let data = JsonImpl::new().add_number_u256("balance", 1000000000000000000_u256).build();
        assert!(data == "{\"balance\":1000000000000000000}", "u256 number");
    }

    #[test]
    fn test_add_number_i64_negative() {
        let data = JsonImpl::new().add_number_i64("delta", -42).build();
        assert!(data == "{\"delta\":-42}", "negative number");
    }

    #[test]
    fn test_add_bool_true() {
        let data = JsonImpl::new().add_bool("active", true).build();
        assert!(data == "{\"active\":true}", "bool true");
    }

    #[test]
    fn test_add_bool_false() {
        let data = JsonImpl::new().add_bool("active", false).build();
        assert!(data == "{\"active\":false}", "bool false");
    }

    #[test]
    fn test_add_null() {
        let data = JsonImpl::new().add_null("data").build();
        assert!(data == "{\"data\":null}", "null value");
    }

    #[test]
    fn test_add_raw() {
        let nested = JsonImpl::new().add("inner", "value").build();
        let data = JsonImpl::new().add_raw("nested", nested).build();
        assert!(data == "{\"nested\":{\"inner\":\"value\"}}", "raw nested object");
    }

    #[test]
    fn test_add_number_array_u64() {
        let data = JsonImpl::new().add_number_array_u64("ids", array![1, 2, 3].span()).build();
        assert!(data == "{\"ids\":[1,2,3]}", "number array");
    }

    #[test]
    fn test_add_bool_array() {
        let data = JsonImpl::new()
            .add_bool_array("flags", array![true, false, true].span())
            .build();
        assert!(data == "{\"flags\":[true,false,true]}", "bool array");
    }

    #[test]
    fn test_combined_types() {
        let data = JsonImpl::new()
            .add("name", "Test")
            .add_number_u64("count", 42)
            .add_bool("active", true)
            .add_null("optional")
            .build();
        assert!(
            data == "{\"name\":\"Test\",\"count\":42,\"active\":true,\"optional\":null}",
            "combined types",
        );
    }

    #[test]
    fn test_add_array() {
        let sub = JsonImpl::new()
            .add("streetAddress", "21 2nd Street")
            .add("city", "San Bryyy")
            .build();
        let mainarr = JsonImpl::new()
            .add("firstName", "John")
            .add("lastName", "Kevin")
            .add_raw("address", sub.clone())
            .add_array("list_of_str", array!["trait_type", "Base", "value", "Starfish"].span())
            .add_array("attributes", array![sub.clone(), sub.clone()].span())
            .add("safety", "Green");

        let z = mainarr.build();

        assert!(
            z == "{\"firstName\":\"John\",\"lastName\":\"Kevin\",\"address\":{\"streetAddress\":\"21 2nd Street\",\"city\":\"San Bryyy\"},\"list_of_str\":[\"trait_type\",\"Base\",\"value\",\"Starfish\"],\"attributes\":[{\"streetAddress\":\"21 2nd Street\",\"city\":\"San Bryyy\"},{\"streetAddress\":\"21 2nd Street\",\"city\":\"San Bryyy\"}],\"safety\":\"Green\"}",
            "wrong json data",
        );
    }

    // JSON Array Builder tests

    #[test]
    fn test_array_builder_strings() {
        let arr = JsonArrayImpl::new().push("a").push("b").push("c").build();
        assert!(arr == "[\"a\",\"b\",\"c\"]", "string array");
    }

    #[test]
    fn test_array_builder_numbers() {
        let arr = JsonArrayImpl::new()
            .push_number_u64(1)
            .push_number_u64(2)
            .push_number_u64(3)
            .build();
        assert!(arr == "[1,2,3]", "number array");
    }

    #[test]
    fn test_array_builder_mixed() {
        let arr = JsonArrayImpl::new()
            .push("text")
            .push_number_u64(42)
            .push_bool(true)
            .push_null()
            .build();
        assert!(arr == "[\"text\",42,true,null]", "mixed array");
    }

    #[test]
    fn test_array_builder_nested_objects() {
        let obj1 = JsonImpl::new().add("id", "1").build();
        let obj2 = JsonImpl::new().add("id", "2").build();
        let arr = JsonArrayImpl::new().push_object(obj1).push_object(obj2).build();
        assert!(arr == "[{\"id\":\"1\"},{\"id\":\"2\"}]", "nested objects");
    }

    // ERC721 Metadata tests

    #[test]
    fn test_erc721_metadata_basic() {
        let metadata = erc721_metadata(
            "Test NFT",
            "A test token",
            "https://example.com/image.png",
            array![("Background", "Blue"), ("Rarity", "Common")].span(),
        );

        assert!(
            metadata == "{\"name\":\"Test NFT\",\"description\":\"A test token\",\"image\":\"https://example.com/image.png\",\"attributes\":[{\"trait_type\":\"Background\",\"value\":\"Blue\"},{\"trait_type\":\"Rarity\",\"value\":\"Common\"}]}",
            "erc721 metadata",
        );
    }

    #[test]
    fn test_erc721_metadata_empty_attributes() {
        let metadata = erc721_metadata(
            "Simple NFT", "No attributes", "https://example.com/img.png", array![].span(),
        );

        assert!(
            metadata == "{\"name\":\"Simple NFT\",\"description\":\"No attributes\",\"image\":\"https://example.com/img.png\",\"attributes\":[]}",
            "empty attributes",
        );
    }

    #[test]
    fn test_erc721_metadata_with_numbers() {
        let metadata = erc721_metadata_with_numbers(
            "Game Item",
            "A powerful sword",
            "https://example.com/sword.png",
            array![("Type", "Weapon"), ("Rarity", "Legendary")].span(),
            array![("Attack", 150), ("Defense", 50)].span(),
        );

        assert!(
            metadata == "{\"name\":\"Game Item\",\"description\":\"A powerful sword\",\"image\":\"https://example.com/sword.png\",\"attributes\":[{\"trait_type\":\"Type\",\"value\":\"Weapon\"},{\"trait_type\":\"Rarity\",\"value\":\"Legendary\"},{\"trait_type\":\"Attack\",\"value\":150},{\"trait_type\":\"Defense\",\"value\":50}]}",
            "metadata with numbers",
        );
    }
}
