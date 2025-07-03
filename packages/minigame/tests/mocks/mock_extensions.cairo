use starknet::ContractAddress;
use game_components_minigame::extensions::objectives::structs::GameObjective;
use game_components_minigame::extensions::settings::structs::{GameSettingDetails, GameSetting};

// Mock Settings Contract
#[starknet::contract]
pub mod MockSettings {
    use super::{GameSettingDetails, GameSetting};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use game_components_minigame::extensions::settings::interface::IMinigameSettings;
    
    #[storage]
    struct Storage {
        settings_exists: Map<u32, bool>,
        settings_names: Map<u32, ByteArray>,
        settings_descriptions: Map<u32, ByteArray>,
    }
    
    #[abi(embed_v0)]
    impl MinigameSettingsImpl of IMinigameSettings<ContractState> {
        fn settings_exist(self: @ContractState, settings_id: u32) -> bool {
            self.settings_exists.read(settings_id)
        }
        
        fn settings(self: @ContractState, settings_id: u32) -> GameSettingDetails {
            assert(self.settings_exists.read(settings_id), 'Settings not found');
            GameSettingDetails {
                name: self.settings_names.read(settings_id),
                description: self.settings_descriptions.read(settings_id),
                settings: array![
                    GameSetting { name: "difficulty", value: "normal" },
                    GameSetting { name: "lives", value: "3" }
                ].span()
            }
        }
    }
    
    // Mock helper to set up test data
    #[generate_trait]
    impl MockHelpers of MockHelpersTrait {
        fn add_settings(ref self: ContractState, settings_id: u32, name: ByteArray, description: ByteArray) {
            self.settings_exists.write(settings_id, true);
            self.settings_names.write(settings_id, name);
            self.settings_descriptions.write(settings_id, description);
        }
    }
}

// Mock Objectives Contract
#[starknet::contract]
pub mod MockObjectives {
    use super::{GameObjective};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use game_components_minigame::extensions::objectives::interface::IMinigameObjectives;
    
    #[storage]
    struct Storage {
        objective_exists: Map<u32, bool>,
        objective_names: Map<u32, ByteArray>,
        objective_values: Map<u32, ByteArray>,
        // Map from (token_id, objective_id) to completion status
        completed_objectives: Map<(u64, u32), bool>,
        // Store objective count per token instead of array
        token_objective_count: Map<u64, u32>,
        // Map from (token_id, index) to objective_id
        token_objective_at: Map<(u64, u32), u32>,
    }
    
    #[abi(embed_v0)]
    impl MinigameObjectivesImpl of IMinigameObjectives<ContractState> {
        fn objective_exists(self: @ContractState, objective_id: u32) -> bool {
            self.objective_exists.read(objective_id)
        }
        
        fn completed_objective(self: @ContractState, token_id: u64, objective_id: u32) -> bool {
            self.completed_objectives.read((token_id, objective_id))
        }
        
        fn objectives(self: @ContractState, token_id: u64) -> Span<GameObjective> {
            let count = self.token_objective_count.read(token_id);
            let mut result = array![];
            
            let mut i = 0;
            loop {
                if i >= count {
                    break;
                }
                let obj_id = self.token_objective_at.read((token_id, i));
                if self.objective_exists.read(obj_id) {
                    result.append(GameObjective {
                        name: self.objective_names.read(obj_id),
                        value: self.objective_values.read(obj_id),
                    });
                }
                i += 1;
            };
            
            result.span()
        }
    }
    
    // Mock helpers to set up test data
    #[generate_trait]
    impl MockHelpers of MockHelpersTrait {
        fn add_objective(ref self: ContractState, objective_id: u32, name: ByteArray, value: ByteArray) {
            self.objective_exists.write(objective_id, true);
            self.objective_names.write(objective_id, name);
            self.objective_values.write(objective_id, value);
        }
        
        fn set_token_objectives(ref self: ContractState, token_id: u64, objective_ids: Span<u32>) {
            let count = objective_ids.len();
            self.token_objective_count.write(token_id, count);
            
            let mut i = 0;
            loop {
                if i >= count {
                    break;
                }
                self.token_objective_at.write((token_id, i), *objective_ids.at(i));
                i += 1;
            };
        }
        
        fn complete_objective(ref self: ContractState, token_id: u64, objective_id: u32) {
            self.completed_objectives.write((token_id, objective_id), true);
        }
    }
}

// Mock Minigame Contract that includes the MinigameComponent
#[starknet::contract]
pub mod MockMinigame {
    use super::ContractAddress;
    use game_components_minigame::minigame::MinigameComponent;
    use game_components_minigame::interface::IMinigameTokenData;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    
    component!(path: MinigameComponent, storage: minigame, event: MinigameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    
    #[abi(embed_v0)]
    impl MinigameImpl = MinigameComponent::MinigameImpl<ContractState>;
    
    impl MinigameInternalImpl = MinigameComponent::InternalImpl<ContractState>;
    
    #[storage]
    struct Storage {
        #[substorage(v0)]
        minigame: MinigameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Mock storage for IMinigameTokenData
        scores: Map<u64, u32>,
        game_overs: Map<u64, bool>,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MinigameEvent: MinigameComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }
    
    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        settings_address: ContractAddress,
        objectives_address: ContractAddress,
    ) {
        let creator = starknet::get_contract_address();
        self.minigame.initializer(
            creator,                      // creator_address
            "MockMinigame",               // name
            "A mock minigame for testing", // description
            "Test Developer",             // developer
            "Test Publisher",             // publisher
            "Testing",                    // genre
            "https://example.com/image",  // image
            Option::None,                 // color
            Option::None,                 // client_url
            Option::None,                 // renderer_address
            settings_address,             // settings_address
            objectives_address,           // objectives_address
            token_address,                // token_address
        );
    }
    
    // Implement required IMinigameTokenData
    impl MinigameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: u64) -> u32 {
            self.scores.read(token_id)
        }
        
        fn game_over(self: @ContractState, token_id: u64) -> bool {
            self.game_overs.read(token_id)
        }
    }
    
    // Mock helpers
    #[generate_trait]
    impl MockHelpers of MockHelpersTrait {
        fn set_score(ref self: ContractState, token_id: u64, score: u32) {
            self.scores.write(token_id, score);
        }
        
        fn set_game_over(ref self: ContractState, token_id: u64, game_over: bool) {
            self.game_overs.write(token_id, game_over);
        }
    }
}