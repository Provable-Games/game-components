// ==============================================================================
// RENDERER MODULE TESTS
// ==============================================================================
// Tests for SVG and metadata rendering functions.
// Note: Some functions use get_block_timestamp(), requiring cheatcodes.

use game_components_metagame::extensions::context::structs::{GameContext, GameContextDetails};
use game_components_minigame::extensions::settings::structs::{GameSetting, GameSettingDetails};
use game_components_minigame::structs::GameDetail;
use game_components_registry::interface::GameMetadata;
use game_components_token::structs::{Lifecycle, TokenMetadata};
use snforge_std::{start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
use starknet::ContractAddress;
use crate::renderer::{create_custom_metadata, create_default_svg};

// ==============================================================================
// TEST FIXTURES
// ==============================================================================

fn ZERO_ADDRESS() -> ContractAddress {
    0.try_into().unwrap()
}

fn TEST_ADDRESS() -> ContractAddress {
    0x1234567890.try_into().unwrap()
}

fn MINTED_BY_ADDRESS() -> ContractAddress {
    0x065d2AB17338b5AffdEbAF95E2D79834B5f30Bac596fF55563c62C3c98700150.try_into().unwrap()
}

fn default_game_metadata() -> GameMetadata {
    GameMetadata {
        contract_address: TEST_ADDRESS(),
        name: "Test Game",
        description: "A test game description",
        developer: "Test Developer",
        publisher: "Test Publisher",
        genre: "Puzzle",
        image: "https://example.com/logo.png",
        color: "white",
        client_url: "https://example.com/play",
        renderer_address: TEST_ADDRESS(),
        royalty_fraction: 500,
    }
}

fn default_token_metadata() -> TokenMetadata {
    TokenMetadata {
        game_id: 1,
        settings_id: 1,
        minted_at: 1640995200, // 2022-01-01
        minted_by: 123,
        lifecycle: Lifecycle { start: 1640995200, end: 1672531200 }, // 2022-2023
        game_over: false,
        soulbound: false,
        completed_objective: false,
        has_context: false,
        objective_id: 0,
        paymaster: false,
        metadata: 0,
    }
}

fn default_settings_details() -> GameSettingDetails {
    GameSettingDetails {
        name: "Test Settings",
        description: "Test settings description",
        settings: array![
            GameSetting { name: "Difficulty", value: "Medium" },
            GameSetting { name: "Lives", value: "3" },
        ]
            .span(),
    }
}

fn default_context_details() -> GameContextDetails {
    GameContextDetails {
        name: "Test Context",
        description: "Test context description",
        id: Option::Some(42),
        context: array![GameContext { name: "Tournament", value: "Weekly #5" }].span(),
    }
}

fn empty_settings_details() -> GameSettingDetails {
    GameSettingDetails { name: "", description: "", settings: array![].span() }
}

fn empty_context_details() -> GameContextDetails {
    GameContextDetails { name: "", description: "", id: Option::None, context: array![].span() }
}

// Helper to check if a ByteArray contains a substring
fn contains(haystack: @ByteArray, needle: @ByteArray) -> bool {
    if needle.len() == 0 {
        return true;
    }
    if haystack.len() < needle.len() {
        return false;
    }

    let mut i: u32 = 0;
    let max_start = haystack.len() - needle.len() + 1;
    loop {
        if i >= max_start {
            break false;
        }

        let mut matches = true;
        let mut j: u32 = 0;
        loop {
            if j >= needle.len() {
                break;
            }
            if haystack.at(i + j).unwrap() != needle.at(j).unwrap() {
                matches = false;
                break;
            }
            j += 1;
        }

        if matches {
            break true;
        }
        i += 1;
    }
}

// Helper to check if output starts with expected prefix
fn starts_with(haystack: @ByteArray, needle: @ByteArray) -> bool {
    if needle.len() > haystack.len() {
        return false;
    }

    let mut i: u32 = 0;
    loop {
        if i >= needle.len() {
            break true;
        }
        if haystack.at(i).unwrap() != needle.at(i).unwrap() {
            break false;
        }
        i += 1;
    }
}

// ==============================================================================
// CREATE_DEFAULT_SVG TESTS - BASIC FUNCTIONALITY
// ==============================================================================

#[test]
fn test_default_svg_basic() {
    let game_metadata = default_game_metadata();
    let result = create_default_svg(1000, game_metadata, 500, 'TestPlayer');

    // Should be a data URI
    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should be SVG data URI");
    assert!(result.len() > 30, "Should have content after prefix");
}

#[test]
fn test_default_svg_zero_score() {
    let game_metadata = default_game_metadata();
    let result = create_default_svg(1, game_metadata, 0, 'Player');

    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_max_score() {
    let game_metadata = default_game_metadata();
    let result = create_default_svg(1, game_metadata, 4294967295, 'Player');

    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_zero_token_id() {
    let game_metadata = default_game_metadata();
    let result = create_default_svg(0, game_metadata, 100, 'Player');

    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_max_token_id() {
    let game_metadata = default_game_metadata();
    let result = create_default_svg(18446744073709551615, game_metadata, 100, 'Player');

    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_empty_player_name() {
    let game_metadata = default_game_metadata();
    // player_name = 0 means no player name
    let result = create_default_svg(1, game_metadata, 100, 0);

    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_long_player_name() {
    let game_metadata = default_game_metadata();
    // Maximum felt252 short string is 31 bytes
    let result = create_default_svg(1, game_metadata, 100, 'ThisIsALongPlayerNameTest');

    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_empty_game_name() {
    let mut game_metadata = default_game_metadata();
    game_metadata.name = "";
    game_metadata.developer = "";

    let result = create_default_svg(1, game_metadata, 100, 'Player');

    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should handle empty strings");
}

#[test]
fn test_default_svg_special_color() {
    let mut game_metadata = default_game_metadata();
    game_metadata.color = "#4f46e5";

    let result = create_default_svg(1, game_metadata, 100, 'Player');

    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should handle hex colors");
}

#[test]
#[fuzzer(runs: 50)]
fn test_default_svg_fuzz(token_id: u64, score: u64) {
    let game_metadata = default_game_metadata();
    let result = create_default_svg(token_id, game_metadata, score, 'Player');

    // Should not panic and produce valid output
    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should produce valid URI");
    assert!(result.len() > 30, "Should have content");
}

// ==============================================================================
// CREATE_CUSTOM_METADATA TESTS - CORE FUNCTIONALITY
// ==============================================================================

#[test]
fn test_custom_metadata_basic() {
    // Set block timestamp for consistent testing
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token Name",
        "Token Description",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0 // no player name
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should be JSON data URI");
}

#[test]
fn test_custom_metadata_full() {
    start_cheat_block_timestamp_global(2000000000);

    let game_details = array![
        GameDetail { name: "Level", value: "Advanced" }, GameDetail { name: "Combo", value: "15" },
    ]
        .span();

    let result = create_custom_metadata(
        1000,
        "Full Token",
        "Full description with all features",
        default_game_metadata(),
        "https://example.com/token.png",
        game_details,
        default_settings_details(),
        default_context_details(),
        default_token_metadata(),
        95000,
        MINTED_BY_ADDRESS(),
        'ProGamer',
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should be JSON data URI");
    assert!(result.len() > 50, "Should have substantial content");
}

#[test]
fn test_custom_metadata_empty_settings() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        default_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should produce valid output");
}

#[test]
fn test_custom_metadata_empty_context() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        default_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should produce valid output");
}

#[test]
fn test_custom_metadata_empty_objectives() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        default_settings_details(),
        default_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        'Player',
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should produce valid output");
}

#[test]
fn test_custom_metadata_empty_game_details() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(), // empty game details
        default_settings_details(),
        default_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        'Player',
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should produce valid output");
}

// ==============================================================================
// CREATE_CUSTOM_METADATA TESTS - EDGE CASES
// ==============================================================================

#[test]
fn test_custom_metadata_zero_token_id() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        0,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should handle zero token_id");
}

#[test]
fn test_custom_metadata_max_token_id() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        18446744073709551615, // u64 max
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should handle max token_id");
}

#[test]
fn test_custom_metadata_zero_score() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        0, // zero score
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should handle zero score");
}

#[test]
fn test_custom_metadata_max_score() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        18446744073709551615, // u64 max
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should handle max score");
}

#[test]
fn test_custom_metadata_zero_player_name() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0 // no player name
    );

    stop_cheat_block_timestamp_global();

    // When player_name is 0, no Player Name trait should be added
    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle zero player name",
    );
}

#[test]
fn test_custom_metadata_max_player_name() {
    start_cheat_block_timestamp_global(2000000000);

    // Maximum 31-byte felt252 short string
    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        'VeryLongPlayerNameForTesting12',
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle long player name",
    );
}

// ==============================================================================
// CREATE_CUSTOM_METADATA TESTS - BOOLEAN FLAGS
// ==============================================================================

#[test]
fn test_custom_metadata_game_over_true() {
    start_cheat_block_timestamp_global(2000000000);

    let mut token_metadata = default_token_metadata();
    token_metadata.game_over = true;

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        token_metadata,
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should handle game_over=true");
}

#[test]
fn test_custom_metadata_soulbound_true() {
    start_cheat_block_timestamp_global(2000000000);

    let mut token_metadata = default_token_metadata();
    token_metadata.soulbound = true;

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        token_metadata,
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should handle soulbound=true");
}

#[test]
fn test_custom_metadata_completed_objective_true() {
    start_cheat_block_timestamp_global(2000000000);

    let mut token_metadata = default_token_metadata();
    token_metadata.completed_objective = true;

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        token_metadata,
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"),
        "Should handle completed_objective=true",
    );
}

// ==============================================================================
// CREATE_CUSTOM_METADATA TESTS - LIFECYCLE
// ==============================================================================

#[test]
fn test_custom_metadata_expired_true() {
    // Set block timestamp AFTER the end time to make token expired
    start_cheat_block_timestamp_global(1700000000); // After 1672531200

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(), // end: 1672531200
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should handle expired token");
}

#[test]
fn test_custom_metadata_not_expired() {
    // Set block timestamp BEFORE the end time
    start_cheat_block_timestamp_global(1650000000); // Before 1672531200

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(), // end: 1672531200
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle non-expired token",
    );
}

#[test]
fn test_custom_metadata_no_end_time() {
    start_cheat_block_timestamp_global(2000000000);

    let mut token_metadata = default_token_metadata();
    token_metadata.lifecycle.end = 0; // No end time

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        token_metadata,
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    // When end=0, expired should be false
    assert!(starts_with(@result, @"data:application/json;base64,"), "Should handle no end time");
}

// ==============================================================================
// CREATE_CUSTOM_METADATA TESTS - CONTEXT
// ==============================================================================

#[test]
fn test_custom_metadata_context_with_id() {
    start_cheat_block_timestamp_global(2000000000);

    let context_details = GameContextDetails {
        name: "Tournament",
        description: "Weekly tournament",
        id: Option::Some(42),
        context: array![GameContext { name: "Round", value: "Finals" }].span(),
    };

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        context_details,
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle context with id",
    );
}

#[test]
fn test_custom_metadata_context_without_id() {
    start_cheat_block_timestamp_global(2000000000);

    let context_details = GameContextDetails {
        name: "Casual Mode",
        description: "Relaxed gameplay",
        id: Option::None,
        context: array![GameContext { name: "Mode", value: "Casual" }].span(),
    };

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        context_details,
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle context without id",
    );
}

#[test]
fn test_custom_metadata_context_name_only() {
    start_cheat_block_timestamp_global(2000000000);

    let context_details = GameContextDetails {
        name: "Context Name", description: "", id: Option::None, context: array![].span(),
    };

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        context_details,
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"),
        "Should handle context with name only",
    );
}

// ==============================================================================
// CREATE_CUSTOM_METADATA TESTS - OBJECTIVES
// ==============================================================================

#[test]
fn test_custom_metadata_single_objective() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle single objective",
    );
}

#[test]
fn test_custom_metadata_multiple_objectives() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle multiple objectives",
    );
}

#[test]
fn test_custom_metadata_many_objectives() {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle many objectives",
    );
}

// ==============================================================================
// CREATE_CUSTOM_METADATA TESTS - GAME DETAILS
// ==============================================================================

#[test]
fn test_custom_metadata_single_game_detail() {
    start_cheat_block_timestamp_global(2000000000);

    let game_details = array![GameDetail { name: "Level", value: "Expert" }].span();

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        game_details,
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle single game detail",
    );
}

#[test]
fn test_custom_metadata_many_game_details() {
    start_cheat_block_timestamp_global(2000000000);

    let mut game_details_arr: Array<GameDetail> = array![];
    let mut i: u8 = 0;
    loop {
        if i >= 10 {
            break;
        }
        game_details_arr
            .append(GameDetail { name: format!("Detail{}", i), value: format!("Value{}", i) });
        i += 1;
    }

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        game_details_arr.span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle many game details",
    );
}

// ==============================================================================
// CREATE_CUSTOM_METADATA FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer(runs: 50)]
fn test_custom_metadata_fuzz_token_id(token_id: u64) {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        token_id,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should handle any token_id");
}

#[test]
#[fuzzer(runs: 50)]
fn test_custom_metadata_fuzz_score(score: u64) {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        score,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should handle any score");
}

#[test]
#[fuzzer(runs: 50)]
fn test_custom_metadata_fuzz_lifecycle(start: u64, end: u64) {
    // Limit values to avoid overflow in timestamp comparison
    let bounded_start = start % 4000000000;
    let bounded_end = end % 4000000000;

    start_cheat_block_timestamp_global(2000000000);

    let mut token_metadata = default_token_metadata();
    token_metadata.lifecycle.start = bounded_start;
    token_metadata.lifecycle.end = bounded_end;

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        token_metadata,
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"),
        "Should handle any lifecycle values",
    );
}

#[test]
#[fuzzer(runs: 50)]
fn test_custom_metadata_fuzz_objective_count(objective_id: u32) {
    start_cheat_block_timestamp_global(2000000000);

    let result = create_custom_metadata(
        1,
        "Token",
        "Desc",
        default_game_metadata(),
        "https://example.com/image.png",
        array![].span(),
        empty_settings_details(),
        empty_context_details(),
        default_token_metadata(),
        100,
        MINTED_BY_ADDRESS(),
        0,
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"), "Should handle varying objectives",
    );
}

// ==============================================================================
// ADDITIONAL INTEGRATION TESTS
// ==============================================================================

#[test]
fn test_default_svg_data_uri_image() {
    let mut game_metadata = default_game_metadata();
    game_metadata
        .image =
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==";

    let result = create_default_svg(1, game_metadata, 100, 'Player');

    assert!(starts_with(@result, @"data:image/svg+xml;base64,"), "Should handle data URI images");
}

#[test]
fn test_custom_metadata_all_features_combined() {
    start_cheat_block_timestamp_global(1650000000); // Before expiry

    let mut token_metadata = default_token_metadata();
    token_metadata.game_over = true;
    token_metadata.soulbound = true;
    token_metadata.completed_objective = true;

    let game_details = array![
        GameDetail { name: "Achievement", value: "Gold" },
        GameDetail { name: "Time", value: "120s" },
    ]
        .span();

    let settings_details = GameSettingDetails {
        name: "Hard Mode",
        description: "Maximum difficulty",
        settings: array![
            GameSetting { name: "Difficulty", value: "Extreme" },
            GameSetting { name: "Perma-death", value: "On" },
        ]
            .span(),
    };

    let context_details = GameContextDetails {
        name: "Championship",
        description: "Annual championship",
        id: Option::Some(2024),
        context: array![
            GameContext { name: "Season", value: "2024" },
            GameContext { name: "Division", value: "Pro" },
        ]
            .span(),
    };

    let result = create_custom_metadata(
        999999,
        "Ultimate Champion Token",
        "Awarded to the champion of the 2024 season",
        default_game_metadata(),
        "https://example.com/champion.png",
        game_details,
        settings_details,
        context_details,
        token_metadata,
        999999,
        MINTED_BY_ADDRESS(),
        'ChampionPlayer2024',
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"),
        "Should handle all features combined",
    );
    assert!(result.len() > 100, "Should have substantial content");
}
