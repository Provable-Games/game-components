use game_components_minigame::extensions::settings::structs::GameSetting;
use game_components_minigame::extensions::objectives::structs::GameObjective;
use game_components_metagame::extensions::context::structs::GameContext;
use graffiti::json::JsonImpl;

pub fn create_settings_json(
    name: ByteArray, description: ByteArray, settings: Span<GameSetting>,
) -> ByteArray {
    let mut settings_json = JsonImpl::new();
    let mut settings_index = 0;
    loop {
        if settings_index == settings.len() {
            break;
        }
        let setting = settings.at(settings_index);
        settings_json = settings_json.add(setting.name.clone(), setting.value.clone());
        settings_index += 1;
    };
    let settings_json = settings_json.build();

    let metadata = JsonImpl::new()
        .add("Name", name)
        .add("Description", description)
        .add("Settings", settings_json)
        .build();

    metadata
}

pub fn create_objectives_json(objectives: Span<GameObjective>) -> ByteArray {
    let mut metadata = JsonImpl::new();
    let mut objective_index = 0;
    loop {
        if objective_index == objectives.len() {
            break;
        }
        let objective = objectives.at(objective_index);
        metadata = metadata.add(objective.name.clone(), objective.value.clone());
        objective_index += 1;
    };
    metadata.build()
}

pub fn create_context_json(
    name: ByteArray, description: ByteArray, context_id: Option<u32>, contexts: Span<GameContext>,
) -> ByteArray {
    let mut contexts_json = JsonImpl::new();
    let mut contexts_index = 0;
    loop {
        if contexts_index == contexts.len() {
            break;
        }
        let context = contexts.at(contexts_index);
        contexts_json = contexts_json.add(context.name.clone(), context.value.clone());
        contexts_index += 1;
    };
    let contexts_json = contexts_json.build();

    let mut metadata = JsonImpl::new().add("Name", name).add("Description", description);

    // Conditionally add Context Id if it exists
    match context_id {
        Option::Some(id) => { metadata = metadata.add("Context Id", format!("{}", id)); },
        Option::None => {},
    };

    // Add Contexts last
    let metadata = metadata.add("Contexts", contexts_json).build();

    metadata
}

pub fn create_json_array(values: Span<ByteArray>) -> ByteArray {
    if values.len() == 0 {
        return "[]";
    }

    let mut result = "[";
    let mut index = 0;
    loop {
        if index == values.len() {
            break;
        }
        let value = values.at(index);
        result += "\"" + value.clone() + "\"";

        // Add comma if not the last element
        if index < values.len() - 1 {
            result += ",";
        }
        index += 1;
    };
    result += "]";
    result
}

#[cfg(test)]
mod tests {
    use super::create_settings_json;
    use super::create_objectives_json;
    use super::create_context_json;
    use super::create_json_array;

    use game_components_minigame::extensions::settings::structs::GameSetting;
    use game_components_minigame::extensions::objectives::structs::GameObjective;
    use game_components_metagame::extensions::context::structs::GameContext;

    #[test]
    fn test_settings_json() {
        let settings = array![
            GameSetting { name: "Test Setting 1", value: "Test Setting 1 Value" },
            GameSetting { name: "Test Setting 2", value: "Test Setting 2 Value" },
        ]
            .span();
        let _current_1 = create_settings_json(
            "Test Settings", "Test Settings Description", settings,
        );

        println!("{}", _current_1);
    }

    #[test]
    fn test_objectives_json() {
        let objectives = array![
            GameObjective { name: "Score 100 points", value: "100 points" },
            GameObjective { name: "Kill 10 enemies", value: "10 enemies" },
        ]
            .span();
        let _current_1 = create_objectives_json(objectives);
        println!("{}", _current_1);
    }

    #[test]
    fn test_contexts_json() {
        let contexts = array![
            GameContext { name: "Test Context 1", value: "Test Context 1 Value" },
            GameContext { name: "Test Context 2", value: "Test Context 2 Value" },
        ]
            .span();
        let _current_1 = create_context_json(
            "Test App", "Test App Description", Option::Some(1), contexts,
        );
        println!("{}", _current_1);
    }

    #[test]
    fn test_json_array() {
        let values = array!["Test Value 1", "Test Value 2"].span();
        let _current_1 = create_json_array(values);
        println!("{}", _current_1);
    }

    #[test]
    fn test_budokan_context_json() {
        let tournament_id: u64 = 12345;
        let context = array![
            GameContext { name: "Tournament Id", value: format!("{}", tournament_id) },
        ]
            .span();
        let context_json = create_context_json(
            "Budokan", "The onchain tournament system", Option::Some(1), context,
        );
        println!("Budokan context: {}", context_json);
    }

    #[test]
    fn test_eternum_context_json() {
        let quest_id: u64 = 67890;
        let context = array![
            GameContext { name: "Quest Id", value: format!("{}", quest_id) },
            GameContext { name: "Reward", value: "1000 Stone" },
        ]
            .span();
        let context_json = create_context_json(
            "Eternum",
            "Multiplayer Civilization with a real economy that never sleeps",
            Option::Some(1),
            context,
        );
        println!("Eternum context: {}", context_json);
    }
}
