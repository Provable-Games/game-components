use alexandria_encoding::base64::Base64Encoder;
use core::array::{SpanTrait};
use core::clone::Clone;
use core::traits::Into;
use core::num::traits::Zero;
use crate::encoding::{U256BytesUsedTraitImpl, bytes_base64_encode};
use graffiti::json::JsonImpl;
use game_components_minigame::structs::GameDetail;
use game_components_minigame::extensions::settings::structs::GameSettingDetails;
use starknet::{ContractAddress, get_block_timestamp};
use game_components_token::structs::TokenMetadata;
use game_components_token::examples::minigame_registry_contract::GameMetadata;
use game_components_metagame::extensions::context::structs::GameContextDetails;

fn logo(image: ByteArray) -> ByteArray {
    format!(
        "<defs><clipPath id='circle'><circle cx='70' cy='75' r='50'/></clipPath></defs><image x='20' y='25' width='100' height='100' href='{}' clip-path='url(#circle)'/>",
        image,
    )
}

fn create_text(
    text: ByteArray,
    x: ByteArray,
    y: ByteArray,
    fontsize: ByteArray,
    baseline: ByteArray,
    text_anchor: ByteArray,
) -> ByteArray {
    "<text x='"
        + x
        + "' y='"
        + y
        + "' font-size='"
        + fontsize
        + "' text-anchor='"
        + text_anchor
        + "' dominant-baseline='"
        + baseline
        + "'>"
        + text
        + "</text>"
}

fn combine_elements(ref elements: Span<ByteArray>) -> ByteArray {
    let mut count: u8 = 1;

    let mut combined: ByteArray = "";
    loop {
        match elements.pop_front() {
            Option::Some(element) => {
                combined += element.clone();

                count += 1;
            },
            Option::None(()) => { break; },
        };
    };

    combined
}

fn create_rect(color: ByteArray) -> ByteArray {
    "<rect x='0.5' y='0.5' width='469' height='599' rx='27.5' fill='black' stroke='" + color + "'/>"
}

// @notice Generates an SVG string for game token uri
// @param internals The internals of the SVG
// @return The generated SVG string
fn create_svg(color: ByteArray, internals: ByteArray) -> ByteArray {
    "<svg xmlns='http://www.w3.org/2000/svg' width='470' height='600'><style>text{text-transform: uppercase;font-family: Courier, monospace;fill: "
        + color.clone()
        + ";}g{fill: "
        + color.clone()
        + ";}</style>"
        + internals
        + "</svg>"
}

fn create_trait(name: ByteArray, value: ByteArray) -> ByteArray {
    JsonImpl::new().add("trait", name).add("value", value).build()
}

pub fn create_default_svg(
    token_id: u64, game_metadata: GameMetadata, score: u32, player_name: felt252,
) -> ByteArray {
    let rect = create_rect(game_metadata.color.clone());
    let logo_element = logo(game_metadata.image);
    let _game_name = format!("{}", game_metadata.name);
    let _game_developer = format!("{}", game_metadata.developer);
    let _score = format!("{}", score);

    // if player_name.is_non_zero() {
    let mut _player_name = Default::default();
    _player_name
        .append_word(player_name, U256BytesUsedTraitImpl::bytes_used(player_name.into()).into());
    // }

    let _token_id = format!("{}", token_id);

    let mut elements = array![
        rect,
        logo_element,
        // Header section - Game ID and State
        create_text("#" + _token_id.clone(), "140", "50", "24", "middle", "left"),
        // Game information section - starting after logo
        create_text("Game:", "30", "160", "16", "middle", "left"),
        create_text(_game_name.clone(), "30", "180", "20", "middle", "left"),
        create_text("Developer:", "30", "220", "16", "middle", "left"),
        create_text(_game_developer.clone(), "30", "240", "18", "middle", "left"),
        // Player and score section
        create_text("Player:", "30", "280", "16", "middle", "left"),
        create_text(_player_name.clone(), "30", "300", "18", "middle", "left"),
        create_text("Score:", "30", "340", "16", "middle", "left"),
        create_text(_score.clone(), "30", "360", "24", "middle", "left"),
    ];

    let mut elements = elements.span();
    let image = create_svg(game_metadata.color.clone(), combine_elements(ref elements));

    format!("data:image/svg+xml;base64,{}", bytes_base64_encode(image))
}

pub fn create_custom_metadata(
    token_id: u64,
    token_name: ByteArray,
    token_description: ByteArray,
    game_metadata: GameMetadata,
    game_details_image: ByteArray,
    game_details: Span<GameDetail>,
    settings_details: GameSettingDetails,
    context_details: GameContextDetails,
    token_metadata: TokenMetadata,
    score: u32,
    minted_by: ContractAddress,
    player_name: felt252,
    objective_ids: Span<u32>,
) -> ByteArray {
    let _token_id = format!("{}", token_id);
    let _game_id = format!("{}", token_metadata.game_id);
    let _score = format!("{}", score);
    let _minted_at = format!("{}", token_metadata.minted_at);
    let _start = format!("{}", token_metadata.lifecycle.start);
    let _end = format!("{}", token_metadata.lifecycle.end);
    let _expired = if token_metadata.lifecycle.end > 0 {
        get_block_timestamp() >= token_metadata.lifecycle.end
    } else {
        false
    };
    let _settings_id = format!("{}", token_metadata.settings_id);
    let address_as_felt: felt252 = minted_by.into();
    let _minted_by = format!("0x{:x}", address_as_felt);

    let mut metadata = JsonImpl::new()
        .add("name", token_name + " #" + _token_id)
        .add("description", token_description)
        .add("image", game_details_image);

    // Core game metadata traits
    let mut attributes = array![
        create_trait("Game ID", _game_id),
        create_trait("Game Name", game_metadata.name),
        create_trait("Game Developer", game_metadata.developer),
        create_trait("Minted By", _minted_by),
        create_trait("Score", _score),
        create_trait("Minted Time", _minted_at),
        create_trait("Start Time", _start),
        create_trait("End Time", _end),
        create_trait("Expired", if _expired {
            "True"
        } else {
            "False"
        }),
        create_trait("Game Over", if token_metadata.game_over {
            "True"
        } else {
            "False"
        }),
        create_trait("Soulbound", if token_metadata.soulbound {
            "True"
        } else {
            "False"
        }),
        create_trait("Settings ID", _settings_id),
    ];

    // Optional settings traits
    if settings_details.name.clone().len() > 0 {
        attributes.append(create_trait("Settings Name", settings_details.name));
    }

    // Optional context traits
    if context_details.name.clone().len() > 0 {
        attributes.append(create_trait("Context Name", context_details.name));
        match context_details.id {
            Option::Some(id) => {
                let _context_id = format!("{}", id);
                attributes.append(create_trait("Context ID", _context_id));
            },
            Option::None => {},
        }
    }

    // Optional objectives traits
    if objective_ids.len() > 0 {
        let mut objective_ids_str: ByteArray = "[";
        let mut i = 0;
        loop {
            if i >= objective_ids.len() {
                break;
            }
            if i > 0 {
                objective_ids_str += ",";
            }
            objective_ids_str += format!("{}", *objective_ids.at(i));
            i += 1;
        };
        objective_ids_str += "]";

        attributes.append(create_trait("Objective IDs", objective_ids_str));
        attributes
            .append(
                create_trait(
                    "Objectives Completed",
                    if token_metadata.completed_all_objectives {
                        "True"
                    } else {
                        "False"
                    },
                ),
            );
    }

    // Optional player name trait
    if !player_name.is_zero() {
        let mut _player_name = Default::default();
        _player_name
            .append_word(
                player_name, U256BytesUsedTraitImpl::bytes_used(player_name.into()).into(),
            );
        attributes.append(create_trait("Player Name", _player_name));
    }

    // Add dynamic game details as traits
    let mut game_details_index = 0;
    loop {
        if game_details_index == game_details.len() {
            break;
        }

        let game_detail = game_details.at(game_details_index);
        attributes.append(create_trait(game_detail.name.clone(), game_detail.value.clone()));

        game_details_index += 1;
    };

    let metadata = metadata.add_array("attributes", attributes.span()).build();

    format!("data:application/json;base64,{}", bytes_base64_encode(metadata))
}

#[cfg(test)]
mod tests {
    use super::{create_default_svg, create_custom_metadata};
    use starknet::contract_address_const;
    use game_components_minigame::structs::GameDetail;
    use game_components_minigame::extensions::settings::structs::{GameSettingDetails, GameSetting};
    use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
    use game_components_token::examples::minigame_registry_contract::GameMetadata;
    use game_components_token::structs::{TokenMetadata, Lifecycle};

    #[test]
    fn test_default_svg() {
        let game_metadata = GameMetadata {
            contract_address: contract_address_const::<
                0x1234567890123456789012345678901234567890,
            >(),
            name: "zKube",
            description: "A puzzle game on Starknet",
            developer: "zKorp",
            publisher: "Starknet Games",
            genre: "Puzzle",
            image: "https://zkube.vercel.app/assets/pwa-512x512.png",
            color: "white",
            client_url: "https://zkube.vercel.app",
            renderer_address: contract_address_const::<
                0x9876543210987654321098765432109876543210,
            >(),
        };

        let svg_result = create_default_svg(1000000, game_metadata, 100, 'test Player');

        println!("Default SVG: {}", svg_result);
    }

    #[test]
    fn test_custom_metadata_full() {
        let game_metadata = GameMetadata {
            contract_address: contract_address_const::<
                0x1234567890123456789012345678901234567890,
            >(),
            name: "zKube",
            description: "A puzzle game on Starknet",
            developer: "zKorp",
            publisher: "Starknet Games",
            genre: "Puzzle",
            image: "https://zkube.vercel.app/assets/pwa-512x512.png",
            color: "#4f46e5",
            client_url: "https://zkube.vercel.app",
            renderer_address: contract_address_const::<
                0x9876543210987654321098765432109876543210,
            >(),
        };

        let settings_details = GameSettingDetails {
            name: "Difficulty Settings",
            description: "Game difficulty configuration",
            settings: array![
                GameSetting { name: "Difficulty", value: "Hard" },
                GameSetting { name: "Time Limit", value: "300" },
                GameSetting { name: "Lives", value: "3" },
            ]
                .span(),
        };

        let context_details = GameContextDetails {
            name: "Tournament Context",
            description: "Weekly tournament settings",
            id: Option::Some(42),
            context: array![
                GameContext { name: "Tournament", value: "Weekly Challenge #5" },
                GameContext { name: "Prize Pool", value: "1000 STRK" },
                GameContext { name: "Participants", value: "156" },
            ]
                .span(),
        };

        let token_metadata = TokenMetadata {
            game_id: 1,
            settings_id: 1,
            minted_at: 1640995200, // 2022-01-01 00:00:00 UTC
            minted_by: 123,
            lifecycle: Lifecycle { start: 1640995200, end: 1672531200 }, // 2022-2023
            game_over: false,
            soulbound: false,
            completed_all_objectives: true,
            has_context: true,
            objectives_count: 5,
        };

        let objective_ids = array![1, 2, 3, 5, 8].span();

        let metadata = create_custom_metadata(
            1000000,
            game_metadata.name.clone(),
            "This is a comprehensive test game token with all features",
            game_metadata,
            "https://zkube.vercel.app/assets/token-image.png",
            array![
                GameDetail { name: "Level", value: "Advanced" },
                GameDetail { name: "Combo Streak", value: "15" },
                GameDetail { name: "Special Power", value: "Lightning Bolt" },
            ]
                .span(),
            settings_details,
            context_details,
            token_metadata,
            95000,
            contract_address_const::<
                0x065d2AB17338b5AffdEbAF95E2D79834B5f30Bac596fF55563c62C3c98700150,
            >(),
            'ProGamer2024',
            objective_ids,
        );

        println!("Full metadata: {}", metadata);
    }

    #[test]
    fn test_custom_metadata_empty_settings() {
        let game_metadata = GameMetadata {
            contract_address: contract_address_const::<
                0x1234567890123456789012345678901234567890,
            >(),
            name: "Simple Game",
            description: "A basic game",
            developer: "Indie Dev",
            publisher: "Self Published",
            genre: "Arcade",
            image: "https://example.com/game.png",
            color: "#ffffff",
            client_url: "https://example.com/play",
            renderer_address: contract_address_const::<
                0x9876543210987654321098765432109876543210,
            >(),
        };

        // Empty settings
        let settings_details = GameSettingDetails {
            name: "", description: "", settings: [].span(),
        };

        // Empty context
        let context_details = GameContextDetails {
            name: "", description: "", id: Option::None, context: [].span(),
        };

        let token_metadata = TokenMetadata {
            game_id: 1,
            settings_id: 0,
            minted_at: 1640995200,
            minted_by: 456,
            lifecycle: Lifecycle { start: 1640995200, end: 1672531200 },
            game_over: true,
            soulbound: true,
            completed_all_objectives: false,
            has_context: false,
            objectives_count: 0,
        };

        let metadata = create_custom_metadata(
            2000000,
            game_metadata.name.clone(),
            "Basic game token with minimal features",
            game_metadata,
            "https://example.com/basic-token.png",
            [].span(), // No game details
            settings_details,
            context_details,
            token_metadata,
            1200,
            contract_address_const::<
                0x065d2AB17338b5AffdEbAF95E2D79834B5f30Bac596fF55563c62C3c98700150,
            >(),
            0, // No player name
            [].span() // No objectives
        );

        println!("Empty settings metadata: {}", metadata);
    }

    #[test]
    fn test_custom_metadata_partial_context() {
        let game_metadata = GameMetadata {
            contract_address: contract_address_const::<
                0x1111111111111111111111111111111111111111,
            >(),
            name: "Context Game",
            description: "Game with partial context",
            developer: "Context Dev",
            publisher: "Context Publisher",
            genre: "Strategy",
            image: "https://example.com/context-game.png",
            color: "#00ff00",
            client_url: "https://example.com/context",
            renderer_address: contract_address_const::<
                0x2222222222222222222222222222222222222222,
            >(),
        };

        let settings_details = GameSettingDetails {
            name: "Basic Settings",
            description: "Simple game settings",
            settings: array![GameSetting { name: "Mode", value: "Single Player" }].span(),
        };

        // Context with name but no ID
        let context_details = GameContextDetails {
            name: "Casual Mode",
            description: "Relaxed gameplay mode",
            id: Option::None,
            context: array![GameContext { name: "Mode Type", value: "Casual" }].span(),
        };

        let token_metadata = TokenMetadata {
            game_id: 3,
            settings_id: 2,
            minted_at: 1650000000,
            minted_by: 789,
            lifecycle: Lifecycle { start: 1650000000, end: 1680000000 },
            game_over: false,
            soulbound: false,
            completed_all_objectives: false,
            has_context: true,
            objectives_count: 2,
        };

        let metadata = create_custom_metadata(
            3000000,
            game_metadata.name.clone(),
            "Game token with partial context information",
            game_metadata,
            "https://example.com/partial-context.png",
            array![GameDetail { name: "Progress", value: "50%" }].span(),
            settings_details,
            context_details,
            token_metadata,
            7500,
            contract_address_const::<
                0x065d2AB17338b5AffdEbAF95E2D79834B5f30Bac596fF55563c62C3c98700150,
            >(),
            'CasualPlayer',
            array![10, 20].span(),
        );

        println!("Partial context metadata: {}", metadata);
    }

    #[test]
    fn test_custom_metadata_single_objective() {
        let game_metadata = GameMetadata {
            contract_address: contract_address_const::<
                0x3333333333333333333333333333333333333333,
            >(),
            name: "Single Objective Game",
            description: "Game with one objective",
            developer: "Solo Dev",
            publisher: "Indie Games",
            genre: "Adventure",
            image: "https://example.com/adventure.png",
            color: "#ff6600",
            client_url: "https://example.com/adventure",
            renderer_address: contract_address_const::<
                0x4444444444444444444444444444444444444444,
            >(),
        };

        let settings_details = GameSettingDetails {
            name: "Adventure Settings",
            description: "Configuration for adventure mode",
            settings: array![
                GameSetting { name: "Difficulty", value: "Medium" },
                GameSetting { name: "Hints", value: "Enabled" },
            ]
                .span(),
        };

        let context_details = GameContextDetails {
            name: "Adventure Quest",
            description: "Epic adventure questline",
            id: Option::Some(1),
            context: array![
                GameContext { name: "Chapter", value: "The Beginning" },
                GameContext { name: "Location", value: "Mystical Forest" },
            ]
                .span(),
        };

        let token_metadata = TokenMetadata {
            game_id: 4,
            settings_id: 3,
            minted_at: 1660000000,
            minted_by: 101,
            lifecycle: Lifecycle { start: 1660000000, end: 1690000000 },
            game_over: false,
            soulbound: true,
            completed_all_objectives: true,
            has_context: true,
            objectives_count: 1,
        };

        let metadata = create_custom_metadata(
            4000000,
            game_metadata.name.clone(),
            "Adventure game token with single objective",
            game_metadata,
            "https://example.com/quest-token.png",
            array![
                GameDetail { name: "Quest Status", value: "In Progress" },
                GameDetail { name: "Items Collected", value: "5/10" },
                GameDetail { name: "Experience", value: "2500 XP" },
            ]
                .span(),
            settings_details,
            context_details,
            token_metadata,
            85000,
            contract_address_const::<
                0x065d2AB17338b5AffdEbAF95E2D79834B5f30Bac596fF55563c62C3c98700150,
            >(),
            'AdventureSeeker',
            array![100].span() // Single objective
        );

        println!("Single objective metadata: {}", metadata);
    }

    #[test]
    fn test_custom_metadata_edge_cases() {
        let game_metadata = GameMetadata {
            contract_address: contract_address_const::<
                0x5555555555555555555555555555555555555555,
            >(),
            name: "Edge Case Game",
            description: "Testing edge cases",
            developer: "Test Dev",
            publisher: "Test Publisher",
            genre: "Test",
            image: "https://example.com/test.png",
            color: "#000000",
            client_url: "https://example.com/test",
            renderer_address: contract_address_const::<
                0x6666666666666666666666666666666666666666,
            >(),
        };

        let settings_details = GameSettingDetails {
            name: "Test Settings",
            description: "Edge case testing",
            settings: array![
                GameSetting { name: "Edge Case 1", value: "" }, // Empty value
                GameSetting { name: "", value: "Edge Case 2" }, // Empty name
                GameSetting { name: "Normal", value: "Value" },
            ]
                .span(),
        };

        let context_details = GameContextDetails {
            name: "Test Context",
            description: "Edge case context",
            id: Option::Some(999999), // Large ID
            context: array![
                GameContext { name: "Max Value", value: "999999999" },
                GameContext { name: "Special Chars", value: "!@#$%^&*()" },
                GameContext { name: "ASCII Only", value: "Game Trophy Winner" },
            ]
                .span(),
        };

        let token_metadata = TokenMetadata {
            game_id: 999,
            settings_id: 999,
            minted_at: 0, // Minimum timestamp
            minted_by: 0, // Minimum minter ID
            lifecycle: Lifecycle { start: 0, end: 4294967295 }, // Max u32
            game_over: true,
            soulbound: true,
            completed_all_objectives: true,
            has_context: true,
            objectives_count: 4,
        };

        let metadata = create_custom_metadata(
            18446744073709551615, // Max u64
            game_metadata.name.clone(),
            "Edge case testing with extreme values and special characters !@#$%^&*()",
            game_metadata,
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==",
            array![
                GameDetail { name: "Zero Score", value: "0" },
                GameDetail { name: "Max Score", value: "4294967295" },
                GameDetail { name: "Negative-like", value: "-1" },
                GameDetail { name: "Float-like", value: "3.14159" },
                GameDetail { name: "Boolean-like", value: "true" },
                GameDetail { name: "Special Chars", value: "!@#$%^&*()" },
            ]
                .span(),
            settings_details,
            context_details,
            token_metadata,
            4294967295, // Max u32 score
            contract_address_const::<0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF>(), // Max address
            'MAX_FELT_VALUE_TEST',
            array![1, 4294967295, 2147483647, 0].span() // Mix of values including max/min
        );

        println!("Edge cases metadata: {}", metadata);
    }
}
