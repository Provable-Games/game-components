#[starknet::contract]
pub mod MockSettings {
    use game_components_minigame::extensions::settings::interface::{IMinigameSettings, IMINIGAME_SETTINGS_ID};
    use game_components_minigame::extensions::settings::structs::Settings;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use openzeppelin_introspection::src5::{SRC5Component, SRC5Component::InternalTrait};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        settings: Map<u32, Settings>,
        settings_count: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.src5.register_interface(IMINIGAME_SETTINGS_ID);
        // Pre-populate some test settings
        self.settings.write(1, Settings { 
            is_valid: true, 
            difficulty: 1, 
            mode: 1, 
            option: 0 
        });
        self.settings.write(2, Settings { 
            is_valid: true, 
            difficulty: 2, 
            mode: 2, 
            option: 1 
        });
        self.settings_count.write(2);
    }

    #[abi(embed_v0)]
    impl MinigameSettingsImpl of IMinigameSettings<ContractState> {
        fn settings(self: @ContractState, id: u32) -> Settings {
            self.settings.read(id)
        }

        fn count(self: @ContractState) -> u32 {
            self.settings_count.read()
        }
    }

    #[external(v0)]
    fn add_settings(ref self: ContractState, id: u32, settings: Settings) {
        self.settings.write(id, settings);
        if id > self.settings_count.read() {
            self.settings_count.write(id);
        }
    }
}