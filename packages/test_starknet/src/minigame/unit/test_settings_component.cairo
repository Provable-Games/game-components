use game_components_minigame::extensions::settings::interface::{
    IMinigameSettings, IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait,
    IMinigameSettingsSVG, IMinigameSettingsSVGDispatcher, IMinigameSettingsSVGDispatcherTrait,
    IMINIGAME_SETTINGS_ID,
};
use game_components_minigame::extensions::settings::structs::{GameSettingDetails, GameSetting};
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::{contract_address_const, get_caller_address};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use core::to_byte_array::FormatAsByteArray;

// Test contract that implements Settings interfaces
#[starknet::contract]
mod MockSettingsContract {
    use game_components_minigame::extensions::settings::interface::{
        IMinigameSettings, IMinigameSettingsSVG, IMINIGAME_SETTINGS_ID,
    };
    use game_components_minigame::extensions::settings::structs::{GameSettingDetails, GameSetting};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::interface::ISRC5;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Storage for testing
        settings_exist: Map<u32, bool>,
        settings_data: Map<u32, GameSettingDetails>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        SettingsCreated: SettingsCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct SettingsCreated {
        game_id: u32,
        settings_id: u32,
        name: ByteArray,
        description: ByteArray,
        settings: Span<GameSetting>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Register SRC5 interface
        self.src5.register_interface(IMINIGAME_SETTINGS_ID);

        // Pre-populate some settings for testing
        self.settings_exist.write(1, true);
        self
            .settings_data
            .write(
                1,
                GameSettingDetails {
                    name: "Easy Mode",
                    description: "Beginner friendly settings",
                    settings: array![
                        GameSetting { name: "difficulty", value: "easy" },
                        GameSetting { name: "lives", value: "5" },
                    ]
                        .span(),
                },
            );

        self.settings_exist.write(2, true);
        self
            .settings_data
            .write(
                2,
                GameSettingDetails {
                    name: "Hard Mode",
                    description: "Expert settings",
                    settings: array![
                        GameSetting { name: "difficulty", value: "hard" },
                        GameSetting { name: "lives", value: "1" },
                    ]
                        .span(),
                },
            );
    }

    // Settings implementation
    #[abi(embed_v0)]
    impl SettingsImpl of IMinigameSettings<ContractState> {
        fn settings_exist(self: @ContractState, settings_id: u32) -> bool {
            self.settings_exist.read(settings_id)
        }

        fn settings(self: @ContractState, settings_id: u32) -> GameSettingDetails {
            assert!(self.settings_exist(settings_id), "Settings not found");
            self.settings_data.read(settings_id)
        }
    }
    
    #[abi(embed_v0)]
    impl SettingsSVGImpl of IMinigameSettingsSVG<ContractState> {
        fn settings_svg(self: @ContractState, settings_id: u32) -> ByteArray {
            let settings = self.settings(settings_id);
            // Return mock SVG
            "<svg><text>" + settings.name + "</text></svg>"
        }
    }

    // Helper function for testing
    #[abi(embed_v0)]
    fn create_test_settings(
        ref self: ContractState, settings_id: u32, settings: GameSettingDetails,
    ) {
        self.settings_exist.write(settings_id, true);
        self.settings_data.write(settings_id, settings);
        // Emit event like the real implementation would
        self
            .emit(
                SettingsCreated {
                    game_id: 1, // Mock game ID
                    settings_id,
                    name: settings.name.clone(),
                    description: settings.description.clone(),
                    settings: settings.settings,
                },
            );
    }
}

// Event definition for testing is already in the contract above

// Test SET-U-01: Initialize settings component
#[test]
fn test_initialize_settings_component() {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    // Verify SRC5 interface is registered
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(
        src5_dispatcher.supports_interface(IMINIGAME_SETTINGS_ID),
        "Should support IMinigameSettings",
    );
    assert!(
        src5_dispatcher.supports_interface(openzeppelin_introspection::interface::ISRC5_ID),
        "Should support ISRC5",
    );
}

// Test SET-U-02: Check settings_exist for valid ID
#[test]
fn test_settings_exist_valid_id() {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    assert!(settings_dispatcher.settings_exist(1), "Settings ID 1 should exist");
    assert!(settings_dispatcher.settings_exist(2), "Settings ID 2 should exist");
}

// Test SET-U-03: Check settings_exist for invalid ID
#[test]
fn test_settings_exist_invalid_id() {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    assert!(!settings_dispatcher.settings_exist(999), "Settings ID 999 should not exist");
    assert!(!settings_dispatcher.settings_exist(0), "Settings ID 0 should not exist");
}

// Test SET-U-04: Get settings for valid ID
#[test]
fn test_get_settings_valid_id() {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };

    // Get settings ID 1
    let settings1 = settings_dispatcher.settings(1);
    assert!(settings1.name == "Easy Mode", "Settings 1 name mismatch");
    assert!(
        settings1.description == "Beginner friendly settings", "Settings 1 description mismatch",
    );
    assert!(settings1.settings.len() == 2, "Settings 1 should have 2 items");

    // Get settings ID 2
    let settings2 = settings_dispatcher.settings(2);
    assert!(settings2.name == "Hard Mode", "Settings 2 name mismatch");
    assert!(settings2.description == "Expert settings", "Settings 2 description mismatch");
}

// Test SET-U-05: Get settings for non-existent ID
#[test]
#[should_panic(expected: ('Settings not found',))]
fn test_get_settings_nonexistent_id() {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    settings_dispatcher.settings(999); // Should panic
}

// Test SET-U-06: Create settings with valid data
#[test]
fn test_create_settings_valid_data() {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let new_settings = GameSettingDetails {
        name: "Custom Mode",
        description: "User defined settings",
        settings: array![
            GameSetting { name: "speed", value: "fast" },
            GameSetting { name: "powerups", value: "enabled" },
            GameSetting { name: "time_limit", value: "300" },
        ]
            .span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(10, new_settings);

    // Verify settings were created
    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    assert!(settings_dispatcher.settings_exist(10), "New settings should exist");

    let retrieved = settings_dispatcher.settings(10);
    assert!(retrieved.name == "Custom Mode", "Name mismatch");
    assert!(retrieved.settings.len() == 3, "Should have 3 settings");
}

// Test SET-U-07: Create settings with empty name
#[test]
fn test_create_settings_empty_name() {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let empty_name_settings = GameSettingDetails {
        name: "", // Empty name
        description: "Settings with no name",
        settings: array![GameSetting { name: "test", value: "value" }].span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(20, empty_name_settings);

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    let retrieved = settings_dispatcher.settings(20);
    assert!(retrieved.name == "", "Name should be empty");
}

// Test SET-U-08: Create settings with 50 items (boundary test)
#[test]
fn test_create_settings_50_items() {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    // Create array with 50 settings
    let mut settings_items = array![];
    let mut i: u32 = 0;
    loop {
        if i >= 50 {
            break;
        }
        settings_items
            .append(
                GameSetting { name: format!("setting_{}", i), value: format!("value_{}", i) },
            );
        i += 1;
    };

    let large_settings = GameSettingDetails {
        name: "Large Settings",
        description: "Settings with 50 items",
        settings: settings_items.span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(30, large_settings);

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    let retrieved = settings_dispatcher.settings(30);
    assert!(retrieved.settings.len() == 50, "Should have 50 settings items");
}

// Test SET-U-09: Get_settings_id from token
// This would be tested in integration with TokenComponent

// Test SET-U-10: Settings_svg implementation
#[test]
fn test_settings_svg() {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let settings_svg_dispatcher = IMinigameSettingsSVGDispatcher { contract_address };

    // Test SVG for existing settings
    let svg1 = settings_svg_dispatcher.settings_svg(1);
    assert!(svg1 == "<svg><text>Easy Mode</text></svg>", "SVG 1 content mismatch");

    let svg2 = settings_svg_dispatcher.settings_svg(2);
    assert!(svg2 == "<svg><text>Hard Mode</text></svg>", "SVG 2 content mismatch");
}

// Helper interface for testing
#[starknet::interface]
trait ISettingsSetter<TContractState> {
    fn create_test_settings(
        ref self: TContractState, settings_id: u32, settings: GameSettingDetails,
    );
}