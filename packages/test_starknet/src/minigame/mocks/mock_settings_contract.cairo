use game_components_minigame::extensions::settings::structs::{GameSettingDetails};

#[starknet::interface]
pub trait ISettingsSetter<TContractState> {
    fn create_test_settings(
        ref self: TContractState, settings_id: u32, settings: GameSettingDetails,
    );
}

#[starknet::contract]
pub mod MockSettingsContract {
    use game_components_minigame::extensions::settings::interface::{
        IMinigameSettings, IMinigameSettingsDetails, IMinigameSettingsSVG, IMINIGAME_SETTINGS_ID,
    };
    use game_components_minigame::extensions::settings::structs::{GameSettingDetails, GameSetting};
    use openzeppelin_introspection::src5::SRC5Component;
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
        settings_name: Map<u32, ByteArray>,
        settings_description: Map<u32, ByteArray>,
        // Store settings count for each settings_id
        settings_count: Map<u32, u32>,
        // Store settings as nested maps - (settings_id, index) -> key/value
        settings_keys: Map<(u32, u32), ByteArray>,
        settings_values: Map<(u32, u32), ByteArray>,
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
        self.settings_name.write(1, "Easy Mode");
        self.settings_description.write(1, "Beginner friendly settings");
        self.settings_count.write(1, 2);
        self.settings_keys.write((1, 0), "difficulty");
        self.settings_values.write((1, 0), "easy");
        self.settings_keys.write((1, 1), "lives");
        self.settings_values.write((1, 1), "5");

        self.settings_exist.write(2, true);
        self.settings_name.write(2, "Hard Mode");
        self.settings_description.write(2, "Expert settings");
        self.settings_count.write(2, 2);
        self.settings_keys.write((2, 0), "difficulty");
        self.settings_values.write((2, 0), "hard");
        self.settings_keys.write((2, 1), "lives");
        self.settings_values.write((2, 1), "1");
    }

    // Settings implementation
    #[abi(embed_v0)]
    impl SettingsImpl of IMinigameSettings<ContractState> {
        fn settings_exist(self: @ContractState, settings_id: u32) -> bool {
            self.settings_exist.read(settings_id)
        }
    }

    #[abi(embed_v0)]
    impl SettingsDetailsImpl of IMinigameSettingsDetails<ContractState> {
        fn settings_details(self: @ContractState, settings_id: u32) -> GameSettingDetails {
            assert!(self.settings_exist(settings_id), "Settings not found");

            let name = self.settings_name.read(settings_id);
            let description = self.settings_description.read(settings_id);

            // Build settings array from storage
            let mut settings_array = array![];
            let count = self.settings_count.read(settings_id);

            let mut i: u32 = 0;
            loop {
                if i >= count {
                    break;
                }

                let key = self.settings_keys.read((settings_id, i));
                let value = self.settings_values.read((settings_id, i));
                settings_array.append(GameSetting { name: key, value: value });

                i += 1;
            };

            GameSettingDetails { name, description, settings: settings_array.span() }
        }
    }

    #[abi(embed_v0)]
    impl SettingsSVGImpl of IMinigameSettingsSVG<ContractState> {
        fn settings_svg(self: @ContractState, settings_id: u32) -> ByteArray {
            let settings = self.settings_details(settings_id);
            // Return mock SVG
            "<svg><text>" + settings.name + "</text></svg>"
        }
    }

    // Helper function for testing
    #[abi(embed_v0)]
    impl SettingsSetterImpl of super::ISettingsSetter<ContractState> {
        fn create_test_settings(
            ref self: ContractState, settings_id: u32, settings: GameSettingDetails,
        ) {
            self.settings_exist.write(settings_id, true);
            self.settings_name.write(settings_id, settings.name.clone());
            self.settings_description.write(settings_id, settings.description.clone());

            // Store all settings
            let settings_len = settings.settings.len();
            self.settings_count.write(settings_id, settings_len);

            let mut i: u32 = 0;
            loop {
                if i >= settings_len {
                    break;
                }

                let setting = settings.settings.at(i);
                self.settings_keys.write((settings_id, i), setting.name.clone());
                self.settings_values.write((settings_id, i), setting.value.clone());

                i += 1;
            };

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
}
