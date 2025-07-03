use alexandria_encoding::base64::Base64Encoder;
use core::array::{SpanTrait};
use core::clone::Clone;
use core::traits::Into;
use core::num::traits::Zero;
use crate::encoding::{U256BytesUsedTraitImpl, bytes_base64_encode};
use graffiti::json::JsonImpl;

fn logo(image: ByteArray) -> ByteArray {
    format!(
        "<defs><clipPath id='circle'><circle cx='70' cy='75' r='50'/></clipPath></defs><image x='20' y='25' width='100' height='100' href='{}' clip-path='url(#circle)'/>",
        image,
    )
}

fn game_state(state: u8) -> ByteArray {
    match state {
        0 => "Not Started",
        1 => "Active",
        2 => "Expired",
        3 => "Game Over",
        4 => "Objectives Complete",
        _ => "Unknown",
    }
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

pub fn create_metadata(
    token_id: u64,
    game_name: felt252,
    game_developer: felt252,
    game_image: ByteArray,
    game_color: ByteArray,
    score: u16,
    state: u8,
    player_name: felt252,
) -> ByteArray {
    let rect = create_rect(game_color.clone());
    let logo_element = logo(game_image);
    let mut _game_name = Default::default();
    let mut _player_name = Default::default();
    let mut _game_developer = Default::default();

    _game_name.append_word(game_name, U256BytesUsedTraitImpl::bytes_used(game_name.into()).into());
    _game_developer
        .append_word(
            game_developer, U256BytesUsedTraitImpl::bytes_used(game_developer.into()).into(),
        );
    let _score = format!("{}", score);

    if player_name.is_non_zero() {
        _player_name
            .append_word(
                player_name, U256BytesUsedTraitImpl::bytes_used(player_name.into()).into(),
            );
    }

    let _game_id = format!("{}", token_id);

    let mut elements = array![
        rect,
        logo_element,
        // Header section - Game ID and State
        create_text("#" + _game_id.clone(), "140", "50", "24", "middle", "left"),
        create_text(game_state(state).clone(), "140", "75", "14", "middle", "left"),
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
    let image = create_svg(game_color.clone(), combine_elements(ref elements));

    let base64_image = format!("data:image/svg+xml;base64,{}", bytes_base64_encode(image));

    let mut metadata = JsonImpl::new()
        .add("name", "Game" + " #" + _game_id)
        .add("description", "An NFT representing ownership of an embeddable game.")
        .add("image", base64_image);

    let name: ByteArray = JsonImpl::new().add("trait", "Game").add("value", _game_name).build();
    let developer: ByteArray = JsonImpl::new()
        .add("trait", "Developer")
        .add("value", _game_developer)
        .build();
    let score: ByteArray = JsonImpl::new().add("trait", "Score").add("value", _score).build();
    let state: ByteArray = JsonImpl::new()
        .add("trait", "State")
        .add("value", game_state(state))
        .build();

    let attributes = array![name, developer, score, state].span();

    let metadata = metadata.add_array("attributes", attributes).build();

    format!("data:application/json;base64,{}", bytes_base64_encode(metadata))
}


pub fn test_create_svg_wrapper(color: ByteArray, internals: ByteArray) -> ByteArray {
    create_svg(color, internals)
}

pub fn test_create_rect_wrapper(color: ByteArray) -> ByteArray {
    create_rect(color)
}

pub fn test_logo_wrapper(image: ByteArray) -> ByteArray {
    logo(image)
}

#[cfg(test)]
mod tests {
    use super::create_metadata;

    #[test]
    fn test_metadata() {
        let _current_1 = create_metadata(
            1000000,
            'zKube',
            'zKorp',
            "https://zkube.vercel.app/assets/pwa-512x512.png",
            "white",
            100,
            1,
            'test Player',
        );

        println!("{}", _current_1);
    }
}
