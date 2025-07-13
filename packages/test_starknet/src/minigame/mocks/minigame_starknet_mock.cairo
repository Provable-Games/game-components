use starknet::ContractAddress;

#[starknet::interface]
pub trait IMinigameStarknetMock<TContractState> {
    fn mint(
        ref self: TContractState,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start_time: Option<u64>,
        end_time: Option<u64>,
        objective_ids: Option<Span<u32>>,
        context: Option<ByteArray>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        player_address: ContractAddress,
        soulbound: bool,
    ) -> u64;
    fn start_game(ref self: TContractState, token_id: u64);
    fn end_game(ref self: TContractState, token_id: u64, score: u32);
    fn create_objective_score(ref self: TContractState, score: u32);
    fn create_settings_difficulty(
        ref self: TContractState, name: ByteArray, description: ByteArray, difficulty: u8,
    );
}

#[starknet::interface]
pub trait IMinigameStarknetMockInit<TContractState> {
    fn initializer(
        ref self: TContractState,
        game_creator: ContractAddress,
        game_name: ByteArray,
        game_description: ByteArray,
        game_developer: ByteArray,
        game_publisher: ByteArray,
        game_genre: ByteArray,
        game_image: ByteArray,
        game_color: Option<ByteArray>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        settings_address: Option<ContractAddress>,
        objectives_address: Option<ContractAddress>,
        minigame_token_address: ContractAddress,
    );
}

#[starknet::contract]
pub mod minigame_starknet_mock {
    use game_components_minigame::interface::{IMinigameTokenData, IMinigameDetails};
    use game_components_minigame::extensions::objectives::interface::{
        IMinigameObjectives, IMINIGAME_OBJECTIVES_ID,
    };
    use game_components_minigame::extensions::settings::interface::{
        IMinigameSettings, IMINIGAME_SETTINGS_ID,
    };
    use game_components_minigame::minigame::MinigameComponent;
    use game_components_minigame::extensions::objectives::objectives::objectives_component;
    use game_components_minigame::extensions::settings::settings::settings_component;
    use game_components_minigame::structs::GameDetail;
    use game_components_minigame::extensions::settings::structs::{GameSetting, GameSettingDetails};
    use game_components_minigame::extensions::objectives::structs::GameObjective;
    use openzeppelin_introspection::src5::SRC5Component;

    use starknet::ContractAddress;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry,
    };

    component!(path: MinigameComponent, storage: minigame, event: MinigameEvent);
    component!(path: objectives_component, storage: objectives, event: ObjectivesEvent);
    component!(path: settings_component, storage: settings, event: SettingsEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl MinigameImpl = MinigameComponent::MinigameImpl<ContractState>;
    impl MinigameInternalImpl = MinigameComponent::InternalImpl<ContractState>;
    impl ObjectivesInternalImpl = objectives_component::InternalImpl<ContractState>;
    impl SettingsInternalImpl = settings_component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        minigame: MinigameComponent::Storage,
        #[substorage(v0)]
        objectives: objectives_component::Storage,
        #[substorage(v0)]
        settings: settings_component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Token data storage
        scores: Map<u64, u32>, // token_id -> score
        game_over: Map<u64, bool>, // token_id -> game_over
        // Settings storage
        settings_count: u32,
        settings_difficulty: Map<u32, u8>, // settings_id -> difficulty
        settings_details: Map<
            u32, (ByteArray, ByteArray, bool),
        >, // settings_id -> (name, description, exists)
        // Objectives storage
        objective_count: u32,
        objective_scores: Map<u32, (u32, bool)>, // objective_id -> (target_score, exists)
        // Token objective mappings - using a simpler storage pattern
        token_objective_count: Map<u64, u32>, // token_id -> count of objectives
        token_objective_at_index: Map<(u64, u32), u32>, // (token_id, index) -> objective_id
        // Token counter for minting
        token_counter: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MinigameEvent: MinigameComponent::Event,
        #[flat]
        ObjectivesEvent: objectives_component::Event,
        #[flat]
        SettingsEvent: settings_component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[abi(embed_v0)]
    impl GameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: u64) -> u32 {
            self.scores.entry(token_id).read()
        }

        fn game_over(self: @ContractState, token_id: u64) -> bool {
            self.game_over.entry(token_id).read()
        }
    }

    #[abi(embed_v0)]
    impl GameDetailsImpl of IMinigameDetails<ContractState> {
        fn token_description(self: @ContractState, token_id: u64) -> ByteArray {
            format!("Test Token Description for token {}", token_id)
        }

        fn game_details(self: @ContractState, token_id: u64) -> Span<GameDetail> {
            array![
                GameDetail {
                    name: "Test Game Detail", value: format!("Test Value for token {}", token_id),
                },
            ]
                .span()
        }
    }

    #[abi(embed_v0)]
    impl SettingsImpl of IMinigameSettings<ContractState> {
        fn settings_exist(self: @ContractState, settings_id: u32) -> bool {
            let (_, _, exists) = self.settings_details.entry(settings_id).read();
            exists
        }

        fn settings(self: @ContractState, settings_id: u32) -> GameSettingDetails {
            let (name, description, _) = self.settings_details.entry(settings_id).read();
            let difficulty = self.settings_difficulty.entry(settings_id).read();

            GameSettingDetails {
                name,
                description,
                settings: array![
                    GameSetting { name: "Difficulty", value: format!("{}", difficulty) },
                ]
                    .span(),
            }
        }
    }

    #[abi(embed_v0)]
    impl ObjectivesImpl of IMinigameObjectives<ContractState> {
        fn objective_exists(self: @ContractState, objective_id: u32) -> bool {
            let (_, exists) = self.objective_scores.entry(objective_id).read();
            exists
        }

        fn completed_objective(self: @ContractState, token_id: u64, objective_id: u32) -> bool {
            let (target_score, _) = self.objective_scores.entry(objective_id).read();
            let player_score = self.scores.entry(token_id).read();
            player_score >= target_score
        }

        fn objectives(self: @ContractState, token_id: u64) -> Span<GameObjective> {
            let objective_count = self.token_objective_count.entry(token_id).read();
            let mut objectives = array![];

            let mut i = 0;
            while i < objective_count {
                let objective_id = self.token_objective_at_index.entry((token_id, i)).read();
                let (target_score, _) = self.objective_scores.entry(objective_id).read();

                objectives
                    .append(
                        GameObjective {
                            name: "Score Target", value: format!("Score Above {}", target_score),
                        },
                    );
                i += 1;
            };

            objectives.span()
        }
    }

    #[abi(embed_v0)]
    impl GameMockImpl of super::IMinigameStarknetMock<ContractState> {
        fn mint(
            ref self: ContractState,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start_time: Option<u64>,
            end_time: Option<u64>,
            objective_ids: Option<Span<u32>>,
            context: Option<ByteArray>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            player_address: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            // Check if settings are supported when settings_id is provided
            if settings_id.is_some() {
                let supports_settings = self.src5.supports_interface(IMINIGAME_SETTINGS_ID);
                assert!(supports_settings, "Settings not supported");
            }

            // Check if objectives are supported when objective_ids are provided
            if objective_ids.is_some() {
                let supports_objectives = self.src5.supports_interface(IMINIGAME_OBJECTIVES_ID);
                assert!(supports_objectives, "Objectives not supported");
            }

            // Generate a simple token ID
            let current_counter = self.token_counter.read();
            let token_id = current_counter + 1;
            self.token_counter.write(token_id);

            // Store objectives if provided
            if let Option::Some(obj_ids) = objective_ids {
                self.store_token_objectives(token_id, obj_ids);
            }

            token_id
        }

        fn start_game(ref self: ContractState, token_id: u64) {
            self.scores.entry(token_id).write(0);
        }

        fn end_game(ref self: ContractState, token_id: u64, score: u32) {
            self.scores.entry(token_id).write(score);
            self.game_over.entry(token_id).write(true);
        }

        fn create_objective_score(ref self: ContractState, score: u32) {
            let objective_count = self.objective_count.read();
            let new_objective_id = objective_count + 1;

            self.objective_scores.entry(new_objective_id).write((score, true));
            self.objective_count.write(new_objective_id);

            self
                .objectives
                .create_objective(
                    new_objective_id,
                    "Score Target",
                    format!("Score Above {}", score),
                    self.minigame.token_address(),
                );
        }

        fn create_settings_difficulty(
            ref self: ContractState, name: ByteArray, description: ByteArray, difficulty: u8,
        ) {
            let settings_count = self.settings_count.read();
            let new_settings_id = settings_count + 1;

            self.settings_difficulty.entry(new_settings_id).write(difficulty);
            self
                .settings_details
                .entry(new_settings_id)
                .write((name.clone(), description.clone(), true));
            self.settings_count.write(new_settings_id);

            let settings = array![
                GameSetting { name: "Difficulty", value: format!("{}", difficulty) },
            ];

            self
                .settings
                .create_settings(
                    new_settings_id,
                    name,
                    description,
                    settings.span(),
                    self.minigame.token_address(),
                );
        }
    }

    #[abi(embed_v0)]
    impl GameInitializerImpl of super::IMinigameStarknetMockInit<ContractState> {
        fn initializer(
            ref self: ContractState,
            game_creator: ContractAddress,
            game_name: ByteArray,
            game_description: ByteArray,
            game_developer: ByteArray,
            game_publisher: ByteArray,
            game_genre: ByteArray,
            game_image: ByteArray,
            game_color: Option<ByteArray>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            settings_address: Option<ContractAddress>,
            objectives_address: Option<ContractAddress>,
            minigame_token_address: ContractAddress,
        ) {
            // Initialize storage counters
            self.settings_count.write(0);
            self.objective_count.write(0);

            // Initialize the base minigame component
            self
                .minigame
                .initializer(
                    game_creator,
                    game_name,
                    game_description,
                    game_developer,
                    game_publisher,
                    game_genre,
                    game_image,
                    game_color,
                    client_url,
                    renderer_address,
                    settings_address,
                    objectives_address,
                    minigame_token_address,
                );

            // Initialize optional features - these will only compile if the contract implements the
            // required traits
            match settings_address {
                Option::Some(_) => self.settings.initializer(),
                Option::None => {},
            }
            match objectives_address {
                Option::Some(_) => self.objectives.initializer(),
                Option::None => {},
            }
        }
    }

    // Helper function to store token objectives (called during mint)
    #[generate_trait]
    impl HelperImpl of HelperTrait {
        fn store_token_objectives(
            ref self: ContractState, token_id: u64, objective_ids: Span<u32>,
        ) {
            let len: u32 = objective_ids.len().try_into().unwrap();
            self.token_objective_count.entry(token_id).write(len);

            let mut i = 0;
            while i < len {
                let objective_id: u32 = *objective_ids.at(i.into());
                self.token_objective_at_index.entry((token_id, i)).write(objective_id);
                i += 1;
            };
        }
    }
}
