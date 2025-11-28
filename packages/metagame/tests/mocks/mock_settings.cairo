use game_components_minigame::extensions::settings::interface::{
    IMinigameSettings, IMinigameSettingsSVG, IMINIGAME_SETTINGS_ID,
};
use game_components_minigame::extensions::settings::structs::{GameSettingDetails, GameSetting};
use openzeppelin_interfaces::introspection::ISRC5;

#[starknet::contract]
pub mod MockSettings {
    use super::*;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    #[storage]
    struct Storage {
        settings_exists: Map<u32, bool>,
        supports_settings: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState, supports_settings: bool) {
        self.supports_settings.write(supports_settings);
    }

    #[abi(embed_v0)]
    impl MinigameSettingsImpl of IMinigameSettings<ContractState> {
        fn settings_exist(self: @ContractState, settings_id: u32) -> bool {
            self.settings_exists.read(settings_id)
        }

        fn settings(self: @ContractState, settings_id: u32) -> GameSettingDetails {
            if !self.settings_exists.read(settings_id) {
                panic!("Settings not found");
            }
            // Return a mock settings object
            GameSettingDetails {
                name: "Mock Settings",
                description: "Mock Description",
                settings: array![
                    GameSetting { name: "difficulty", value: "easy" },
                    GameSetting { name: "mode", value: "classic" },
                ]
                    .span(),
            }
        }
    }

    #[abi(embed_v0)]
    impl MinigameSettingsSVGImpl of IMinigameSettingsSVG<ContractState> {
        fn settings_svg(self: @ContractState, settings_id: u32) -> ByteArray {
            if !self.settings_exists.read(settings_id) {
                panic!("Settings not found");
            }
            "<svg>Test Settings SVG</svg>"
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            if self.supports_settings.read() {
                interface_id == IMINIGAME_SETTINGS_ID
                    || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
            } else {
                interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
            }
        }
    }

    // Helper functions for testing
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn add_settings(ref self: ContractState, settings_id: u32) {
            self.settings_exists.write(settings_id, true);
        }
    }
}
