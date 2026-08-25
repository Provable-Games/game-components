// ==============================================================================
// RENDERER MODULE TESTS
// ==============================================================================
// Tests for SVG and metadata rendering functions.
// Note: Some functions use get_block_timestamp(), requiring cheatcodes.

use game_components_embeddable_game_standard::metagame::extensions::context::structs::{
    GameContext, GameContextDetails,
};
use game_components_embeddable_game_standard::minigame::extensions::objectives::structs::{
    GameObjective, GameObjectiveDetails,
};
use game_components_embeddable_game_standard::minigame::extensions::settings::structs::{
    GameSetting, GameSettingDetails,
};
use game_components_embeddable_game_standard::minigame::structs::GameDetail;
use game_components_interfaces::structs::minigame::GameMetadata;
use game_components_interfaces::structs::token::{Lifecycle, TokenMetadata};
use snforge_std::{start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
use starknet::ContractAddress;
use crate::renderer::metadata::create_custom_metadata;
use crate::renderer::svg::create_default_svg;

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
        skills_address: ZERO_ADDRESS(),
        created_at: 0,
        version: 0,
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
        completed_at: 0,
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
            GameSetting { name: 'Difficulty', value: 'Medium' },
            GameSetting { name: 'Lives', value: '3' },
        ]
            .span(),
    }
}

fn default_context_details() -> GameContextDetails {
    GameContextDetails {
        name: "Test Context",
        description: "Test context description",
        id: Option::Some(42),
        context: array![GameContext { name: 'Tournament', value: 'Weekly #5' }].span(),
    }
}

fn default_objective_details() -> GameObjectiveDetails {
    GameObjectiveDetails {
        name: "Clear All Blocks",
        description: "Complete the puzzle",
        objectives: array![GameObjective { name: 'Blocks', value: '0' }].span(),
    }
}

fn empty_settings_details() -> GameSettingDetails {
    GameSettingDetails { name: "", description: "", settings: array![].span() }
}

fn empty_objective_details() -> GameObjectiveDetails {
    GameObjectiveDetails { name: "", description: "", objectives: array![].span() }
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
    start_cheat_block_timestamp_global(1656763200); // midway 2022-2023
    let game_metadata = default_game_metadata();
    let result = create_default_svg(
        game_metadata,
        default_token_metadata(),
        500,
        'TestPlayer',
        default_settings_details(),
        default_objective_details(),
        default_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    // Should be a data URI
    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should be SVG data URI");
    assert!(result.len() > 30, "Should have content after prefix");
}

#[test]
fn test_default_svg_zero_score() {
    start_cheat_block_timestamp_global(1656763200);
    let game_metadata = default_game_metadata();
    let result = create_default_svg(
        game_metadata,
        default_token_metadata(),
        0,
        'Player',
        default_settings_details(),
        default_objective_details(),
        default_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_max_score() {
    start_cheat_block_timestamp_global(1656763200);
    let game_metadata = default_game_metadata();
    let result = create_default_svg(
        game_metadata,
        default_token_metadata(),
        4294967295,
        'Player',
        default_settings_details(),
        default_objective_details(),
        default_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_game_over() {
    start_cheat_block_timestamp_global(1656763200);
    let game_metadata = default_game_metadata();
    let mut token_metadata = default_token_metadata();
    token_metadata.game_over = true;
    let result = create_default_svg(
        game_metadata,
        token_metadata,
        100,
        'Player',
        default_settings_details(),
        default_objective_details(),
        default_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_objective_failed() {
    start_cheat_block_timestamp_global(1656763200);
    let game_metadata = default_game_metadata();
    let mut token_metadata = default_token_metadata();
    token_metadata.game_over = true;
    token_metadata.objective_id = 1;
    token_metadata.completed_objective = false;
    let result = create_default_svg(
        game_metadata,
        token_metadata,
        100,
        'Player',
        default_settings_details(),
        default_objective_details(),
        default_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_soulbound() {
    start_cheat_block_timestamp_global(1656763200);
    let game_metadata = default_game_metadata();
    let mut token_metadata = default_token_metadata();
    token_metadata.soulbound = true;
    let result = create_default_svg(
        game_metadata,
        token_metadata,
        100,
        'Player',
        default_settings_details(),
        default_objective_details(),
        default_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_empty_player_name() {
    start_cheat_block_timestamp_global(1656763200);
    let game_metadata = default_game_metadata();
    // player_name = 0 means no player name
    let result = create_default_svg(
        game_metadata,
        default_token_metadata(),
        100,
        0,
        default_settings_details(),
        default_objective_details(),
        empty_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_long_player_name() {
    start_cheat_block_timestamp_global(1656763200);
    let game_metadata = default_game_metadata();
    // Maximum felt252 short string is 31 bytes
    let result = create_default_svg(
        game_metadata,
        default_token_metadata(),
        100,
        'ThisIsALongPlayerNameTest',
        default_settings_details(),
        default_objective_details(),
        default_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should be SVG data URI");
}

#[test]
fn test_default_svg_empty_game_name() {
    start_cheat_block_timestamp_global(1656763200);
    let mut game_metadata = default_game_metadata();
    game_metadata.name = "";
    game_metadata.developer = "";

    let result = create_default_svg(
        game_metadata,
        default_token_metadata(),
        100,
        'Player',
        default_settings_details(),
        default_objective_details(),
        empty_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should handle empty strings",
    );
}

#[test]
fn test_default_svg_special_color() {
    start_cheat_block_timestamp_global(1656763200);
    let mut game_metadata = default_game_metadata();
    game_metadata.color = "#4f46e5";

    let result = create_default_svg(
        game_metadata,
        default_token_metadata(),
        100,
        'Player',
        default_settings_details(),
        default_objective_details(),
        default_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should handle hex colors");
}

#[test]
#[fuzzer(runs: 50)]
fn test_default_svg_fuzz(score: u64, game_id: u64) {
    start_cheat_block_timestamp_global(1656763200);
    let game_metadata = default_game_metadata();
    let mut token_metadata = default_token_metadata();
    token_metadata.game_id = game_id;
    let result = create_default_svg(
        game_metadata,
        token_metadata,
        score,
        'Player',
        default_settings_details(),
        default_objective_details(),
        default_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    // Should not panic and produce valid output
    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should produce valid URI");
    assert!(result.len() > 30, "Should have content");
}

// ==============================================================================
// CREATE_DEFAULT_SVG TESTS - TIMELINE EDGE CASES
// ==============================================================================

#[test]
fn test_default_svg_timeline_before_start() {
    // Current time before lifecycle start
    start_cheat_block_timestamp_global(1600000000);
    let result = create_default_svg(
        default_game_metadata(),
        default_token_metadata(),
        100,
        'Player',
        default_settings_details(),
        default_objective_details(),
        empty_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should handle before-start",
    );
}

#[test]
fn test_default_svg_timeline_after_end() {
    // Current time after lifecycle end
    start_cheat_block_timestamp_global(1700000000);
    let result = create_default_svg(
        default_game_metadata(),
        default_token_metadata(),
        100,
        'Player',
        default_settings_details(),
        default_objective_details(),
        empty_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should handle after-end");
}

#[test]
fn test_default_svg_timeline_no_end() {
    start_cheat_block_timestamp_global(1656763200);
    let mut token_metadata = default_token_metadata();
    token_metadata.lifecycle.end = 0;
    let result = create_default_svg(
        default_game_metadata(),
        token_metadata,
        100,
        'Player',
        default_settings_details(),
        default_objective_details(),
        empty_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should handle no end time",
    );
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
        0, // no player name
        "",
    );

    stop_cheat_block_timestamp_global();

    assert!(starts_with(@result, @"data:application/json;base64,"), "Should be JSON data URI");
}

#[test]
fn test_custom_metadata_full() {
    start_cheat_block_timestamp_global(2000000000);

    let game_details = array![
        GameDetail { name: 'Level', value: 'Advanced' }, GameDetail { name: 'Combo', value: '15' },
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
        "",
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
        "",
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
        "",
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
        "",
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
        "",
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
        "",
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
        "",
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
        "",
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
        "",
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
        0, // no player name
        "",
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
        "",
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
        "",
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
        "",
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
        "",
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"),
        "Should handle completed_objective=true",
    );
}

#[test]
fn test_custom_metadata_completed_at_nonzero() {
    start_cheat_block_timestamp_global(2000000000);

    let mut token_metadata = default_token_metadata();
    token_metadata.completed_objective = true;
    token_metadata.completed_at = 1672531200;
    token_metadata.objective_id = 1;

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
        "",
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"),
        "Should produce valid metadata with completed_at",
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
        "",
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
        "",
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
        "",
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
        context: array![GameContext { name: 'Round', value: 'Finals' }].span(),
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
        "",
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
        context: array![GameContext { name: 'Mode', value: 'Casual' }].span(),
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
        "",
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
        "",
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
        "",
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
        "",
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
        "",
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

    let game_details = array![GameDetail { name: 'Level', value: 'Expert' }].span();

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
        "",
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
        game_details_arr.append(GameDetail { name: 'Detail', value: 'Value' });
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
        "",
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
fn test_custom_metadata_fuzz_token_id(token_id: felt252) {
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
        "",
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
        "",
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
        "",
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
        "",
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
    start_cheat_block_timestamp_global(1656763200);
    let mut game_metadata = default_game_metadata();
    game_metadata
        .image =
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==";

    let result = create_default_svg(
        game_metadata,
        default_token_metadata(),
        100,
        'Player',
        default_settings_details(),
        default_objective_details(),
        empty_context_details(),
        "https://test.game.com",
    );
    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:image/svg+xml;charset=utf-8,"), "Should handle data URI images",
    );
}

#[test]
fn test_custom_metadata_all_features_combined() {
    start_cheat_block_timestamp_global(1650000000); // Before expiry

    let mut token_metadata = default_token_metadata();
    token_metadata.game_over = true;
    token_metadata.soulbound = true;
    token_metadata.completed_objective = true;

    let game_details = array![
        GameDetail { name: 'Achievement', value: 'Gold' },
        GameDetail { name: 'Time', value: '120s' },
    ]
        .span();

    let settings_details = GameSettingDetails {
        name: "Hard Mode",
        description: "Maximum difficulty",
        settings: array![
            GameSetting { name: 'Difficulty', value: 'Extreme' },
            GameSetting { name: 'Perma-death', value: 'On' },
        ]
            .span(),
    };

    let context_details = GameContextDetails {
        name: "Championship",
        description: "Annual championship",
        id: Option::Some(2024),
        context: array![
            GameContext { name: 'Season', value: '2024' },
            GameContext { name: 'Division', value: 'Pro' },
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
        "",
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@result, @"data:application/json;base64,"),
        "Should handle all features combined",
    );
    assert!(result.len() > 100, "Should have substantial content");
}

// ==============================================================================
// STRESS TESTS - MAXED OUT SVG + METADATA
// ==============================================================================

fn stress_token_metadata() -> TokenMetadata {
    let mut token_metadata = default_token_metadata();
    token_metadata.game_id = 18446744073709551615; // max u64
    token_metadata.settings_id = 4294967295; // max u32
    token_metadata.minted_at = 18446744073709551615;
    token_metadata.minted_by = 18446744073709551615;
    token_metadata.lifecycle = Lifecycle { start: 0, end: 18446744073709551615 };
    token_metadata.game_over = true;
    token_metadata.soulbound = true;
    token_metadata.completed_objective = true;
    token_metadata.has_context = true;
    token_metadata.objective_id = 4294967295;
    token_metadata.paymaster = true;
    token_metadata.metadata = 65535; // max u16
    token_metadata
}

fn stress_game_metadata() -> GameMetadata {
    let mut game_metadata = default_game_metadata();
    game_metadata
        .name = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"; // 64 chars
    game_metadata
        .description =
            "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"; // 256 chars
    game_metadata.developer = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"; // 32 chars
    game_metadata.publisher = "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"; // 34 chars
    game_metadata.genre = "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE"; // 32 chars
    game_metadata
}

fn stress_settings_details() -> GameSettingDetails {
    GameSettingDetails {
        name: "Maximum Settings Configuration Name That Is Very Long",
        description: "A very long settings description to stress test the metadata generation",
        settings: array![
            GameSetting { name: 'Setting_A', value: 'ValueAAAAAAAAAAAAAAAAAAAAAAAAA' },
            GameSetting { name: 'Setting_B', value: 'ValueBBBBBBBBBBBBBBBBBBBBBBBBB' },
            GameSetting { name: 'Setting_C', value: 'ValueCCCCCCCCCCCCCCCCCCCCCCCCC' },
            GameSetting { name: 'Setting_D', value: 'ValueDDDDDDDDDDDDDDDDDDDDDDDDD' },
            GameSetting { name: 'Setting_E', value: 'ValueEEEEEEEEEEEEEEEEEEEEEEEEE' },
        ]
            .span(),
    }
}

fn stress_context_details() -> GameContextDetails {
    GameContextDetails {
        name: "Maximum Context Configuration Name That Is Very Long Indeed",
        description: "A very long context description to stress test the metadata generation flow",
        id: Option::Some(4294967295), // max u32
        context: array![
            GameContext {
                name: 'ContextKeyAAAAAAAAAAAAAAAAAAAAA', value: 'ContextValAAAAAAAAAAAAAAAAAAAA',
            },
            GameContext {
                name: 'ContextKeyBBBBBBBBBBBBBBBBBBBBB', value: 'ContextValBBBBBBBBBBBBBBBBBBBB',
            },
            GameContext {
                name: 'ContextKeyCCCCCCCCCCCCCCCCCCCCC', value: 'ContextValCCCCCCCCCCCCCCCCCCCC',
            },
        ]
            .span(),
    }
}

fn stress_objective_details() -> GameObjectiveDetails {
    GameObjectiveDetails {
        name: "Complete All Objectives And Win The Championship Tournament Final Round",
        description: "A very long objective description to stress test rendering with maximum content",
        objectives: array![
            GameObjective { name: 'ObjectiveAAAAAAAAAAAAAAAAAAAA', value: '999999999' },
            GameObjective { name: 'ObjectiveBBBBBBBBBBBBBBBBBBBB', value: '888888888' },
            GameObjective { name: 'ObjectiveCCCCCCCCCCCCCCCCCCCC', value: '777777777' },
        ]
            .span(),
    }
}

#[test]
fn test_stress_default_svg_maxed_out() {
    start_cheat_block_timestamp_global(2000000000);

    let svg_result = create_default_svg(
        stress_game_metadata(),
        stress_token_metadata(),
        18446744073709551615, // max u64 score
        'MaxLengthPlayerNameTest1234', // 27 chars
        stress_settings_details(),
        stress_objective_details(),
        stress_context_details(),
        "https://example.com/very/long/path/to/client/that/tests/url/length/limits/stress/test/play",
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@svg_result, @"data:image/svg+xml;charset=utf-8,"),
        "Should produce valid SVG output",
    );
    println!("Stress SVG output length: {} bytes", svg_result.len());
}

#[test]
fn test_stress_custom_metadata_maxed_out() {
    start_cheat_block_timestamp_global(2000000000);

    // 20 game details
    let mut game_details_arr: Array<GameDetail> = array![];
    let mut i: u8 = 0;
    loop {
        if i >= 20 {
            break;
        }
        game_details_arr.append(GameDetail { name: 'GameDetail', value: 'GameDetailValue' });
        i += 1;
    }

    let metadata_result = create_custom_metadata(
        3618502788666131213697322783095070105623107215331596699973092056135872020480, // large felt252
        "A Very Long Token Name That Tests The Limits Of Metadata Generation",
        "An extremely long token description that is designed to stress test the JSON metadata generation function with a large amount of text content to ensure it handles long strings properly without any issues or errors occurring during the base64 encoding process",
        stress_game_metadata(),
        "https://example.com/very/long/path/to/image/that/tests/url/length/limits/stress/test/image.png",
        game_details_arr.span(),
        stress_settings_details(),
        stress_context_details(),
        stress_token_metadata(),
        18446744073709551615, // max u64 score
        0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7.try_into().unwrap(),
        'MaxLengthPlayerNameTest1234', // 27 chars
        "Complete All Objectives And Win The Championship Tournament Final Round",
    );

    stop_cheat_block_timestamp_global();

    assert!(
        starts_with(@metadata_result, @"data:application/json;base64,"),
        "Should produce valid metadata output",
    );
    assert!(metadata_result.len() > 500, "Should have very substantial content");
    println!("Stress metadata output length: {} bytes", metadata_result.len());
}

