use core::num::traits::Zero;
use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
use game_components_embeddable_game_standard::minigame::extensions::settings::structs::GameSettingDetails;
use game_components_embeddable_game_standard::minigame::structs::GameDetail;
use game_components_embeddable_game_standard::registry::interface::GameMetadata;
use game_components_embeddable_game_standard::token::structs::TokenMetadata;
use graffiti::json::JsonImpl;
use starknet::{ContractAddress, get_block_timestamp};
use crate::utils::encoding::{bytes_base64_encode, felt252_to_byte_array};

fn create_trait(name: ByteArray, value: ByteArray) -> ByteArray {
    JsonImpl::new().add("trait", name).add("value", value).build()
}

fn bool_to_str(val: bool) -> ByteArray {
    if val {
        "True"
    } else {
        "False"
    }
}

pub fn create_custom_metadata(
    token_id: felt252,
    token_name: ByteArray,
    token_description: ByteArray,
    game_metadata: GameMetadata,
    game_details_image: ByteArray,
    game_details: Span<GameDetail>,
    settings_details: GameSettingDetails,
    context_details: GameContextDetails,
    token_metadata: TokenMetadata,
    score: u64,
    minted_by: ContractAddress,
    player_name: felt252,
    objective_name: ByteArray,
) -> ByteArray {
    let _token_id = format!("0x{:x}", token_id);
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
        create_trait("Game ID", _game_id), create_trait("Game Name", game_metadata.name),
        create_trait("Game Developer", game_metadata.developer),
        create_trait("Publisher", game_metadata.publisher),
        create_trait("Genre", game_metadata.genre), create_trait("Minted By", _minted_by),
        create_trait("Score", _score), create_trait("Minted Time", _minted_at),
        create_trait("Start Time", _start), create_trait("End Time", _end),
        create_trait("Expired", bool_to_str(_expired)),
        create_trait("Game Over", bool_to_str(token_metadata.game_over)),
        create_trait("Soulbound", bool_to_str(token_metadata.soulbound)),
        create_trait("Paymaster", bool_to_str(token_metadata.paymaster)),
        create_trait("Metadata", format!("{}", Into::<u16, u32>::into(token_metadata.metadata))),
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
        let mut ctx_span = context_details.context;
        while let Option::Some(ctx) = ctx_span.pop_front() {
            attributes
                .append(
                    create_trait(
                        "Context: " + felt252_to_byte_array(*ctx.name),
                        felt252_to_byte_array(*ctx.value),
                    ),
                );
        };
    }

    // Optional objectives traits
    if token_metadata.objective_id != 0 {
        attributes.append(create_trait("Objective ID", format!("{}", token_metadata.objective_id)));
        attributes
            .append(
                create_trait(
                    "Objectives Completed", bool_to_str(token_metadata.completed_objective),
                ),
            );
        if token_metadata.completed_at > 0 {
            attributes
                .append(create_trait("Completed At", format!("{}", token_metadata.completed_at)));
        }
        if objective_name.len() > 0 {
            attributes.append(create_trait("Objective Name", objective_name));
        }
    }

    // Optional player name trait
    if !player_name.is_zero() {
        attributes.append(create_trait("Player Name", felt252_to_byte_array(player_name)));
    }

    // Game-level metadata traits
    if game_metadata.client_url.len() > 0 {
        attributes.append(create_trait("Client URL", game_metadata.client_url));
    }
    let renderer_felt: felt252 = game_metadata.renderer_address.into();
    if !renderer_felt.is_zero() {
        attributes.append(create_trait("Renderer", format!("0x{:x}", renderer_felt)));
    }
    let skills_felt: felt252 = game_metadata.skills_address.into();
    if !skills_felt.is_zero() {
        attributes.append(create_trait("Skills", format!("0x{:x}", skills_felt)));
    }

    // Add dynamic game details as traits
    let mut game_details_index = 0;
    loop {
        if game_details_index == game_details.len() {
            break;
        }

        let game_detail = game_details.at(game_details_index);
        attributes
            .append(
                create_trait(
                    felt252_to_byte_array(*game_detail.name),
                    felt252_to_byte_array(*game_detail.value),
                ),
            );

        game_details_index += 1;
    }

    let metadata = metadata.add_array("attributes", attributes.span()).build();

    format!("data:application/json;base64,{}", bytes_base64_encode(metadata))
}
