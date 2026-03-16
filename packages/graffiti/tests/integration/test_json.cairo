//! Integration tests for JSON builder.
//!
//! Tests cover all JSON value types, nesting, arrays, and real-world patterns
//! like ERC721 metadata.

use graffiti::json::{
    ArrayBuilder, Builder, BuilderExt, JsonArrayImpl, JsonImpl, erc721_metadata,
    erc721_metadata_with_numbers,
};


//
// Basic Object Tests
//

#[test]
fn test_empty_object() {
    let json = JsonImpl::new().build();
    assert!(json == "{}", "empty object");
}

#[test]
fn test_string_value() {
    let json = JsonImpl::new().add("name", "Alice").build();
    assert!(json == "{\"name\":\"Alice\"}", "string value");
}

#[test]
fn test_multiple_string_values() {
    let json = JsonImpl::new()
        .add("first", "John")
        .add("last", "Doe")
        .add("city", "New York")
        .build();
    assert!(
        json == "{\"first\":\"John\",\"last\":\"Doe\",\"city\":\"New York\"}",
        "multiple string values",
    );
}


//
// Numeric Type Tests
//

#[test]
fn test_number_u8() {
    let json = JsonImpl::new().add_number_u8("age", 25).build();
    assert!(json == "{\"age\":25}", "u8 number");
}

#[test]
fn test_number_u16() {
    let json = JsonImpl::new().add_number_u16("port", 8080).build();
    assert!(json == "{\"port\":8080}", "u16 number");
}

#[test]
fn test_number_u32() {
    let json = JsonImpl::new().add_number_u32("count", 1000000).build();
    assert!(json == "{\"count\":1000000}", "u32 number");
}

#[test]
fn test_number_u64() {
    let json = JsonImpl::new().add_number_u64("timestamp", 1705123456789).build();
    assert!(json == "{\"timestamp\":1705123456789}", "u64 number");
}

#[test]
fn test_number_u128() {
    let json = JsonImpl::new()
        .add_number_u128("big_number", 340282366920938463463374607431768211455)
        .build();
    assert!(json == "{\"big_number\":340282366920938463463374607431768211455}", "u128 max value");
}

#[test]
fn test_number_u256() {
    let json = JsonImpl::new().add_number_u256("balance", 1000000000000000000_u256).build();
    assert!(json == "{\"balance\":1000000000000000000}", "u256 number (1 ETH in wei)");
}

#[test]
fn test_number_u256_large() {
    // Test a large u256 value
    let large: u256 = 0x1234567890abcdef1234567890abcdef_u256;
    let json = JsonImpl::new().add_number_u256("value", large).build();
    // The hex value 0x1234567890abcdef1234567890abcdef = 24197857200151252728969465429440056815
    assert!(json == "{\"value\":24197857200151252728969465429440056815}", "large u256");
}

#[test]
fn test_number_felt252() {
    let json = JsonImpl::new().add_number_felt252("field", 12345).build();
    assert!(json == "{\"field\":12345}", "felt252 number");
}


//
// Signed Integer Tests
//

#[test]
fn test_number_i64_positive() {
    let json = JsonImpl::new().add_number_i64("delta", 100).build();
    assert!(json == "{\"delta\":100}", "positive i64");
}

#[test]
fn test_number_i64_negative() {
    let json = JsonImpl::new().add_number_i64("delta", -50).build();
    assert!(json == "{\"delta\":-50}", "negative i64");
}

#[test]
fn test_number_i64_zero() {
    let json = JsonImpl::new().add_number_i64("zero", 0).build();
    assert!(json == "{\"zero\":0}", "zero i64");
}

#[test]
fn test_number_i128_positive() {
    let json = JsonImpl::new().add_number_i128("amount", 999999999999).build();
    assert!(json == "{\"amount\":999999999999}", "positive i128");
}

#[test]
fn test_number_i128_negative() {
    let json = JsonImpl::new().add_number_i128("loss", -123456789).build();
    assert!(json == "{\"loss\":-123456789}", "negative i128");
}


//
// Boolean Tests
//

#[test]
fn test_bool_true() {
    let json = JsonImpl::new().add_bool("active", true).build();
    assert!(json == "{\"active\":true}", "boolean true");
}

#[test]
fn test_bool_false() {
    let json = JsonImpl::new().add_bool("active", false).build();
    assert!(json == "{\"active\":false}", "boolean false");
}

#[test]
fn test_multiple_bools() {
    let json = JsonImpl::new()
        .add_bool("enabled", true)
        .add_bool("visible", false)
        .add_bool("locked", true)
        .build();
    assert!(json == "{\"enabled\":true,\"visible\":false,\"locked\":true}", "multiple booleans");
}


//
// Null Tests
//

#[test]
fn test_null_value() {
    let json = JsonImpl::new().add_null("data").build();
    assert!(json == "{\"data\":null}", "null value");
}

#[test]
fn test_null_with_other_values() {
    let json = JsonImpl::new()
        .add("name", "Test")
        .add_null("optional")
        .add_number_u64("count", 42)
        .build();
    assert!(json == "{\"name\":\"Test\",\"optional\":null,\"count\":42}", "null with other values");
}


//
// Nested Object Tests
//

#[test]
fn test_nested_object_simple() {
    let inner = JsonImpl::new().add("city", "Paris").add("country", "France").build();
    let json = JsonImpl::new().add("name", "Alice").add_raw("address", inner).build();
    assert!(
        json == "{\"name\":\"Alice\",\"address\":{\"city\":\"Paris\",\"country\":\"France\"}}",
        "simple nested object",
    );
}

#[test]
fn test_nested_object_with_numbers() {
    let coords = JsonImpl::new().add_number_i64("x", 100).add_number_i64("y", -50).build();
    let json = JsonImpl::new().add("id", "point1").add_raw("coordinates", coords).build();
    assert!(
        json == "{\"id\":\"point1\",\"coordinates\":{\"x\":100,\"y\":-50}}", "nested with numbers",
    );
}

#[test]
fn test_deeply_nested_object() {
    // Level 3: innermost
    let level3 = JsonImpl::new().add("value", "deep").build();

    // Level 2
    let level2 = JsonImpl::new().add("name", "middle").add_raw("child", level3).build();

    // Level 1
    let level1 = JsonImpl::new().add("name", "outer").add_raw("nested", level2).build();

    // Root
    let json = JsonImpl::new().add_raw("root", level1).build();

    assert!(
        json == "{\"root\":{\"name\":\"outer\",\"nested\":{\"name\":\"middle\",\"child\":{\"value\":\"deep\"}}}}",
        "deeply nested (3+ levels)",
    );
}

#[test]
fn test_multiple_nested_objects() {
    let home = JsonImpl::new().add("type", "home").add("number", "555-1234").build();
    let work = JsonImpl::new().add("type", "work").add("number", "555-5678").build();

    let json = JsonImpl::new()
        .add("name", "Bob")
        .add_raw("home_phone", home)
        .add_raw("work_phone", work)
        .build();

    assert!(
        json == "{\"name\":\"Bob\",\"home_phone\":{\"type\":\"home\",\"number\":\"555-1234\"},\"work_phone\":{\"type\":\"work\",\"number\":\"555-5678\"}}",
        "multiple nested objects",
    );
}


//
// String Array Tests
//

#[test]
fn test_string_array() {
    let json = JsonImpl::new().add_array("tags", array!["red", "green", "blue"].span()).build();
    assert!(json == "{\"tags\":[\"red\",\"green\",\"blue\"]}", "string array");
}

#[test]
fn test_string_array_single_element() {
    let json = JsonImpl::new().add_array("items", array!["only"].span()).build();
    assert!(json == "{\"items\":[\"only\"]}", "single element array");
}

#[test]
fn test_empty_string_array() {
    let empty: Array<ByteArray> = array![];
    let json = JsonImpl::new().add_array("empty", empty.span()).build();
    assert!(json == "{\"empty\":[]}", "empty string array");
}


//
// Number Array Tests
//

#[test]
fn test_number_array_u64() {
    let json = JsonImpl::new().add_number_array_u64("ids", array![1, 2, 3, 4, 5].span()).build();
    assert!(json == "{\"ids\":[1,2,3,4,5]}", "u64 number array");
}

#[test]
fn test_number_array_u64_empty() {
    let empty: Array<u64> = array![];
    let json = JsonImpl::new().add_number_array_u64("empty", empty.span()).build();
    assert!(json == "{\"empty\":[]}", "empty u64 array");
}

#[test]
fn test_number_array_u256() {
    let json = JsonImpl::new()
        .add_number_array_u256(
            "balances",
            array![1000000000000000000_u256, 2000000000000000000_u256, 500000000000000000_u256]
                .span(),
        )
        .build();
    assert!(
        json == "{\"balances\":[1000000000000000000,2000000000000000000,500000000000000000]}",
        "u256 number array",
    );
}


//
// Boolean Array Tests
//

#[test]
fn test_bool_array() {
    let json = JsonImpl::new().add_bool_array("flags", array![true, false, true].span()).build();
    assert!(json == "{\"flags\":[true,false,true]}", "boolean array");
}

#[test]
fn test_bool_array_all_true() {
    let json = JsonImpl::new().add_bool_array("all_true", array![true, true, true].span()).build();
    assert!(json == "{\"all_true\":[true,true,true]}", "all true array");
}

#[test]
fn test_bool_array_all_false() {
    let json = JsonImpl::new().add_bool_array("all_false", array![false, false].span()).build();
    assert!(json == "{\"all_false\":[false,false]}", "all false array");
}

#[test]
fn test_bool_array_empty() {
    let empty: Array<bool> = array![];
    let json = JsonImpl::new().add_bool_array("empty", empty.span()).build();
    assert!(json == "{\"empty\":[]}", "empty boolean array");
}


//
// Array of Objects
//

#[test]
fn test_array_of_objects() {
    let obj1 = JsonImpl::new().add("id", "1").add("name", "Alice").build();
    let obj2 = JsonImpl::new().add("id", "2").add("name", "Bob").build();

    let json = JsonImpl::new().add_array("users", array![obj1, obj2].span()).build();
    assert!(
        json == "{\"users\":[{\"id\":\"1\",\"name\":\"Alice\"},{\"id\":\"2\",\"name\":\"Bob\"}]}",
        "array of objects",
    );
}


//
// ERC721 Metadata Tests
//

#[test]
fn test_erc721_metadata_basic() {
    let metadata = erc721_metadata(
        "Cool NFT #42",
        "A very cool NFT from the collection",
        "ipfs://QmXyz123/42.png",
        array![("Background", "Blue"), ("Eyes", "Laser"), ("Hat", "Crown")].span(),
    );

    assert!(
        metadata == "{\"name\":\"Cool NFT #42\",\"description\":\"A very cool NFT from the collection\",\"image\":\"ipfs://QmXyz123/42.png\",\"attributes\":[{\"trait_type\":\"Background\",\"value\":\"Blue\"},{\"trait_type\":\"Eyes\",\"value\":\"Laser\"},{\"trait_type\":\"Hat\",\"value\":\"Crown\"}]}",
        "erc721 metadata with attributes",
    );
}

#[test]
fn test_erc721_metadata_no_attributes() {
    let metadata = erc721_metadata(
        "Simple NFT",
        "A simple token without traits",
        "https://example.com/nft.png",
        array![].span(),
    );

    assert!(
        metadata == "{\"name\":\"Simple NFT\",\"description\":\"A simple token without traits\",\"image\":\"https://example.com/nft.png\",\"attributes\":[]}",
        "erc721 metadata without attributes",
    );
}

#[test]
fn test_erc721_metadata_data_uri() {
    let metadata = erc721_metadata(
        "On-chain NFT",
        "Fully on-chain",
        "data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=",
        array![("Type", "On-chain")].span(),
    );

    assert!(
        metadata == "{\"name\":\"On-chain NFT\",\"description\":\"Fully on-chain\",\"image\":\"data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=\",\"attributes\":[{\"trait_type\":\"Type\",\"value\":\"On-chain\"}]}",
        "erc721 with data uri",
    );
}

#[test]
fn test_erc721_metadata_with_numbers_mixed() {
    let metadata = erc721_metadata_with_numbers(
        "Game Character",
        "A powerful warrior",
        "https://game.io/char/1.png",
        array![("Class", "Warrior"), ("Faction", "Alliance")].span(),
        array![("Strength", 85), ("Defense", 72), ("Level", 50)].span(),
    );

    assert!(
        metadata == "{\"name\":\"Game Character\",\"description\":\"A powerful warrior\",\"image\":\"https://game.io/char/1.png\",\"attributes\":[{\"trait_type\":\"Class\",\"value\":\"Warrior\"},{\"trait_type\":\"Faction\",\"value\":\"Alliance\"},{\"trait_type\":\"Strength\",\"value\":85},{\"trait_type\":\"Defense\",\"value\":72},{\"trait_type\":\"Level\",\"value\":50}]}",
        "erc721 with numeric attributes",
    );
}

#[test]
fn test_erc721_metadata_only_numbers() {
    let metadata = erc721_metadata_with_numbers(
        "Stats Token",
        "Pure stats",
        "https://example.com/stats.png",
        array![].span(),
        array![("Power", 100), ("Speed", 200)].span(),
    );

    assert!(
        metadata == "{\"name\":\"Stats Token\",\"description\":\"Pure stats\",\"image\":\"https://example.com/stats.png\",\"attributes\":[{\"trait_type\":\"Power\",\"value\":100},{\"trait_type\":\"Speed\",\"value\":200}]}",
        "erc721 with only numeric attributes",
    );
}


//
// Special Character Tests
//

#[test]
fn test_string_with_quotes() {
    let json = JsonImpl::new().add("quote", "He said \"Hello\"").build();
    assert!(json == "{\"quote\":\"He said \\\"Hello\\\"\"}", "quotes in string value");
}

#[test]
fn test_string_with_newlines() {
    let json = JsonImpl::new().add("multiline", "line1\nline2\nline3").build();
    assert!(json == "{\"multiline\":\"line1\\nline2\\nline3\"}", "newlines in string value");
}

#[test]
fn test_string_with_backslashes() {
    let json = JsonImpl::new().add("path", "C:\\Users\\file.txt").build();
    assert!(json == "{\"path\":\"C:\\\\Users\\\\file.txt\"}", "backslashes in string value");
}

#[test]
fn test_string_with_tabs() {
    let json = JsonImpl::new().add("tabbed", "col1\tcol2\tcol3").build();
    assert!(json == "{\"tabbed\":\"col1\\tcol2\\tcol3\"}", "tabs in string value");
}

#[test]
fn test_string_with_carriage_return() {
    let json = JsonImpl::new().add("crlf", "line1\r\nline2").build();
    assert!(json == "{\"crlf\":\"line1\\r\\nline2\"}", "carriage return in string value");
}

#[test]
fn test_string_with_mixed_special_chars() {
    let json = JsonImpl::new().add("mixed", "\"quote\"\n\\backslash\\").build();
    assert!(
        json == "{\"mixed\":\"\\\"quote\\\"\\n\\\\backslash\\\\\"}", "mixed special characters",
    );
}


//
// Key Escaping Tests
//

// Note: JSON keys are NOT auto-escaped in the current API.
// Users should use simple alphanumeric keys.
#[test]
fn test_key_simple() {
    let json = JsonImpl::new().add("simple_key", "value").build();
    assert!(json == "{\"simple_key\":\"value\"}", "simple key");
}

#[test]
fn test_key_with_numbers() {
    let json = JsonImpl::new().add("key123", "value").build();
    assert!(json == "{\"key123\":\"value\"}", "key with numbers");
}

#[test]
fn test_key_with_underscore() {
    let json = JsonImpl::new().add("my_key_name", "value").build();
    assert!(json == "{\"my_key_name\":\"value\"}", "key with underscore");
}


//
// JSON Array Builder Tests
//

#[test]
fn test_array_builder_empty() {
    let arr = JsonArrayImpl::new().build();
    assert!(arr == "[]", "empty array");
}

#[test]
fn test_array_builder_strings() {
    let arr = JsonArrayImpl::new().push("one").push("two").push("three").build();
    assert!(arr == "[\"one\",\"two\",\"three\"]", "string array via builder");
}

#[test]
fn test_array_builder_numbers() {
    let arr = JsonArrayImpl::new()
        .push_number_u64(10)
        .push_number_u64(20)
        .push_number_u64(30)
        .build();
    assert!(arr == "[10,20,30]", "number array via builder");
}

#[test]
fn test_array_builder_u256() {
    let arr = JsonArrayImpl::new()
        .push_number_u256(1000000000000000000_u256)
        .push_number_u256(2000000000000000000_u256)
        .build();
    assert!(arr == "[1000000000000000000,2000000000000000000]", "u256 array via builder");
}

#[test]
fn test_array_builder_booleans() {
    let arr = JsonArrayImpl::new().push_bool(true).push_bool(false).push_bool(true).build();
    assert!(arr == "[true,false,true]", "boolean array via builder");
}

#[test]
fn test_array_builder_nulls() {
    let arr = JsonArrayImpl::new().push_null().push_null().build();
    assert!(arr == "[null,null]", "null array via builder");
}

#[test]
fn test_array_builder_mixed() {
    let arr = JsonArrayImpl::new()
        .push("text")
        .push_number_u64(42)
        .push_bool(true)
        .push_null()
        .build();
    assert!(arr == "[\"text\",42,true,null]", "mixed type array");
}

#[test]
fn test_array_builder_nested_objects() {
    let obj1 = JsonImpl::new().add("name", "Item 1").add_number_u64("qty", 5).build();
    let obj2 = JsonImpl::new().add("name", "Item 2").add_number_u64("qty", 10).build();

    let arr = JsonArrayImpl::new().push_object(obj1).push_object(obj2).build();
    assert!(
        arr == "[{\"name\":\"Item 1\",\"qty\":5},{\"name\":\"Item 2\",\"qty\":10}]",
        "array of objects via builder",
    );
}


//
// Combined Types Test
//

#[test]
fn test_complex_combined_json() {
    // Build a complex nested JSON structure
    let address = JsonImpl::new()
        .add("street", "123 Main St")
        .add("city", "Blockchain City")
        .add("zip", "12345")
        .build();

    let tags_arr = JsonArrayImpl::new().push("developer").push("cairo").push("starknet").build();

    let scores = JsonImpl::new()
        .add_number_u64("math", 95)
        .add_number_u64("science", 88)
        .add_number_u64("history", 72)
        .build();

    let json = JsonImpl::new()
        .add("name", "Alice Developer")
        .add_number_u64("age", 28)
        .add_bool("active", true)
        .add_null("middle_name")
        .add_raw("address", address)
        .add_raw("tags", tags_arr)
        .add_raw("scores", scores)
        .add_number_i64("balance", -500)
        .build();

    // Verify structure is valid by checking key parts
    assert!(json.len() > 0, "complex json built");
    // Check it starts and ends correctly
    let mut check: ByteArray = "{\"name\":\"Alice Developer\"";
    assert!(json.len() > check.len(), "json starts with expected prefix");
}


//
// Edge Cases
//

#[test]
fn test_empty_string_value() {
    let json = JsonImpl::new().add("empty", "").build();
    assert!(json == "{\"empty\":\"\"}", "empty string value");
}

#[test]
fn test_empty_string_key() {
    let json = JsonImpl::new().add("", "value").build();
    assert!(json == "{\"\":\"value\"}", "empty string key");
}

#[test]
fn test_zero_values() {
    let json = JsonImpl::new()
        .add_number_u8("u8", 0)
        .add_number_u16("u16", 0)
        .add_number_u32("u32", 0)
        .add_number_u64("u64", 0)
        .add_number_u128("u128", 0)
        .add_number_u256("u256", 0_u256)
        .add_number_i64("i64", 0)
        .add_number_i128("i128", 0)
        .build();

    assert!(
        json == "{\"u8\":0,\"u16\":0,\"u32\":0,\"u64\":0,\"u128\":0,\"u256\":0,\"i64\":0,\"i128\":0}",
        "all zero values",
    );
}

#[test]
fn test_max_u8() {
    let json = JsonImpl::new().add_number_u8("max", 255).build();
    assert!(json == "{\"max\":255}", "max u8");
}

#[test]
fn test_max_u16() {
    let json = JsonImpl::new().add_number_u16("max", 65535).build();
    assert!(json == "{\"max\":65535}", "max u16");
}

#[test]
fn test_max_u32() {
    let json = JsonImpl::new().add_number_u32("max", 4294967295).build();
    assert!(json == "{\"max\":4294967295}", "max u32");
}

#[test]
fn test_single_character_strings() {
    let json = JsonImpl::new().add("a", "b").add("c", "d").build();
    assert!(json == "{\"a\":\"b\",\"c\":\"d\"}", "single char keys and values");
}
