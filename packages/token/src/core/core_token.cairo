#[starknet::component]
pub mod CoreTokenComponent {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    
    use crate::core::interface::IMinigameToken;
    use crate::examples::multi_game_contract::{IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait, GameMetadata, IMINIGAME_REGISTRY_ID};
    use crate::extensions::settings::interface::IMINIGAME_TOKEN_SETTINGS_ID;
    use crate::core::traits::{
        OptionalMinter, OptionalContext, OptionalObjectives,
        OptionalSoulbound, OptionalRenderer, OptionalSettings
    };
    use crate::structs::{TokenMetadata, Lifecycle};
    use crate::libs::LifecycleTrait;

    use game_components_metagame::extensions::context::structs::GameContextDetails;
    
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::InternalTrait as ERC721InternalTrait;
    use openzeppelin_token::erc721::ERC721Component::ERC721Impl;
    
    use game_components_minigame::interface::{
        IMINIGAME_ID, IMinigameDispatcher, IMinigameDispatcherTrait, IMinigameTokenDataDispatcher,
        IMinigameTokenDataDispatcherTrait,
    };
    use game_components_minigame::extensions::objectives::interface::{
        IMINIGAME_OBJECTIVES_ID, IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait,
    };
    use game_components_minigame::extensions::settings::interface::{
        IMINIGAME_SETTINGS_ID, IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait,
    };

    #[storage]
    pub struct Storage {
        token_metadata: Map<u64, TokenMetadata>,
        token_player_names: Map<u64, ByteArray>,
        token_counter: u64,
        game_address: ContractAddress,
        game_registry_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenMinted: TokenMinted,
        GameUpdated: GameUpdated,
        ScoreUpdate: ScoreUpdate,
        MetadataUpdate: MetadataUpdate,
        Owners: Owners,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenMinted {
        #[key]
        pub token_id: u64,
        #[key]
        pub to: ContractAddress,
        #[key]
        pub game_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameUpdated {
        #[key]
        pub token_id: u64,
        #[key]
        pub old_game_address: ContractAddress,
        #[key]
        pub new_game_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ScoreUpdate {
        #[key]
        pub token_id: u64,
        pub score: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MetadataUpdate {
        #[key]
        pub token_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Owners {
        #[key]
        pub token_id: u64,
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub auth: ContractAddress,
    }

    #[embeddable_as(CoreTokenImpl)]
    pub impl CoreToken<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl MinterOpt: OptionalMinter<TContractState>,
        impl ContextOpt: OptionalContext<TContractState>,
        impl ObjectivesOpt: OptionalObjectives<TContractState>,
        impl SettingsOpt: OptionalSettings<TContractState>,
        impl RendererOpt: OptionalRenderer<TContractState>,
        +Drop<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
    > of IMinigameToken<ComponentState<TContractState>> {
        
        fn token_metadata(self: @ComponentState<TContractState>, token_id: u64) -> TokenMetadata {
            self.token_metadata.entry(token_id).read()
        }

        fn is_playable(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let metadata = self.token_metadata.entry(token_id).read();
            let current_time = get_block_timestamp();
            metadata.lifecycle.is_playable(current_time) && !metadata.game_over && !metadata.completed_all_objectives
        }

        fn settings_id(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.settings_id
        }

        fn player_name(self: @ComponentState<TContractState>, token_id: u64) -> ByteArray {
            self.token_player_names.entry(token_id).read()
        }

        fn objectives_count(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.objectives_count.into()
        }

        fn minted_by(self: @ComponentState<TContractState>, token_id: u64) -> u64 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.minted_by
        }

        fn game_address(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            let metadata = self.token_metadata.entry(token_id).read();
            if metadata.game_id == 0 {
                // Single game token - use component's game address
                self.game_address.read()
            } else {
                // Multi-game token - resolve from game registry
                let game_registry_dispatcher = IMinigameRegistryDispatcher { contract_address: self.game_registry_address.read() };
                let game_address = game_registry_dispatcher.game_address_from_id(metadata.game_id);
                game_address
            }
        }

        fn game_registry_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.game_registry_address.read()
        }

        fn is_soulbound(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.soulbound
        }

        fn renderer_address(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            let contract_self = self.get_contract();
            let renderer = RendererOpt::get_token_renderer(contract_self, token_id);
            match renderer {
                Option::Some(addr) => addr,
                Option::None => starknet::contract_address_const::<0>(),
            }
        }

        fn mint(
            ref self: ComponentState<TContractState>,
            game_address: Option<ContractAddress>,
            player_name: Option<ByteArray>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_ids: Option<Span<u32>>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            let caller = get_caller_address();
            
            // Validate and process game address
            // if this returns a zero game address, the token is blank and we don't need to validate settings or objectives
            // TODO: if you have a game registry address then run
            let (final_game_address, game_id) = self.validate_and_process_game_address(game_address);
            
            let mut contract = self.get_contract();
            // Validate settings if provided
            let validated_settings_id = SettingsOpt::validate_settings(contract, final_game_address, settings_id);
            
            // Validate and process objectives if provided
            let (objectives_count, validated_objective_ids) = ObjectivesOpt::validate_objectives(contract, final_game_address, objective_ids);
            
            // Handle minter tracking if enabled
            let mut contract_self = self.get_contract_mut();
            let minted_by = MinterOpt::add_minter(ref contract_self, caller);

            let token_id = self.token_counter.read() + 1;
            
            // Handle objectives if provided
            ObjectivesOpt::set_token_objectives(ref contract_self, token_id, objective_ids);

            // Handle context if provided
            let has_context = ContextOpt::emit_context(ref contract_self, caller, token_id, context);
            
            // Handle renderer if provided
            RendererOpt::set_token_renderer(ref contract_self, token_id, renderer_address);
            
            // Create token metadata
            let metadata = TokenMetadata {
                game_id,
                minted_at: get_block_timestamp(),
                settings_id: validated_settings_id,
                lifecycle: Lifecycle {
                    start: start.unwrap_or(0),
                    end: end.unwrap_or(0),
                },
                minted_by,
                soulbound,
                game_over: false,
                completed_all_objectives: false,
                has_context: has_context,
                objectives_count: objectives_count.try_into().unwrap(),
            };
            
            self.token_metadata.entry(token_id).write(metadata);

            self.token_counter.write(token_id);
            
            // Set player name if provided
            match player_name {
                Option::Some(name) => {
                    self.token_player_names.entry(token_id).write(name);
                },
                Option::None => {}
            }
            
            // Mint the ERC721 token
            let mut contract = self.get_contract_mut();
            let mut erc721_component = ERC721::get_component_mut(ref contract);
            erc721_component.mint(to, token_id.into());
            
            // Emit events
            self.emit(TokenMinted {
                token_id,
                to,
                game_address: final_game_address,
            });
            
            token_id
        }

        fn update_game(ref self: ComponentState<TContractState>, token_id: u64) {
            // Validate token exists
            let mut contract = self.get_contract_mut();
            let mut erc721_component = ERC721::get_component_mut(ref contract);
            assert!(
                erc721_component.exists(token_id.into()),
                "CoreToken: Token {} does not exist",
                token_id
            );
            
            let token_metadata = self.token_metadata.entry(token_id).read();
            let game_address = self.resolve_game_address(token_metadata.game_id);
            
            // Validate game address supports required interfaces
            let game_src5_dispatcher = ISRC5Dispatcher { contract_address: game_address };
            assert!(
                game_src5_dispatcher.supports_interface(IMINIGAME_ID),
                "CoreToken: Game does not support IMinigame interface"
            );
            
            // Check objectives completion if token has objectives
            let mut completed_all_objectives = token_metadata.completed_all_objectives;
            if !completed_all_objectives && token_metadata.objectives_count > 0 {
                completed_all_objectives = ObjectivesOpt::update_objectives(ref contract, token_id, game_address, token_metadata.objectives_count.into());
            }
            
            // Get current game state
            let minigame_token_data_dispatcher = IMinigameTokenDataDispatcher {
                contract_address: game_address,
            };
            
            let game_over = minigame_token_data_dispatcher.game_over(token_id);
            let score = minigame_token_data_dispatcher.score(token_id);
            
            // Update metadata if game state changed
            if completed_all_objectives != token_metadata.completed_all_objectives || game_over != token_metadata.game_over {
                let updated_metadata = TokenMetadata {
                    game_id: token_metadata.game_id,
                    minted_at: token_metadata.minted_at,
                    settings_id: token_metadata.settings_id,
                    lifecycle: token_metadata.lifecycle,
                    minted_by: token_metadata.minted_by,
                    soulbound: token_metadata.soulbound,
                    game_over,
                    completed_all_objectives,
                    has_context: token_metadata.has_context,
                    objectives_count: token_metadata.objectives_count,
                };
                
                self.token_metadata.entry(token_id).write(updated_metadata);
                self.emit_metadata_update(token_id);
            }
            
            // Always emit score update
            self.emit_score_update(token_id, score.into());
            
            // Emit game updated event
            self.emit(GameUpdated {
                token_id,
                old_game_address: game_address,
                new_game_address: game_address,
            });
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl MinterOpt: OptionalMinter<TContractState>,
        impl ContextOpt: OptionalContext<TContractState>,
        impl ObjectivesOpt: OptionalObjectives<TContractState>,
        impl SettingsOpt: OptionalSettings<TContractState>,
        impl RendererOpt: OptionalRenderer<TContractState>,
        +Drop<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
    > of InternalTrait<TContractState> {
        
        fn initializer(
            ref self: ComponentState<TContractState>, 
            game_address: Option<ContractAddress>,
            game_registry_address: Option<ContractAddress>
        ) {
            // Register token interface
            let mut contract = self.get_contract_mut();
            let mut src5_component = SRC5::get_component_mut(ref contract);
            src5_component.register_interface(crate::interface::IMINIGAME_TOKEN_ID);
            
            // Set game address if provided
            if let Option::Some(game_address) = game_address {
                self.game_address.write(game_address);
            }

            if let Option::Some(game_registry_address) = game_registry_address {
                self.game_registry_address.write(game_registry_address);
            }
        }

        fn token_counter(self: @ComponentState<TContractState>) -> u64 {
            self.token_counter.read()
        }
        
        fn validate_and_process_game_address(
            self: @ComponentState<TContractState>,
            game_address: Option<ContractAddress>
        ) -> (ContractAddress, u64) {
            match game_address {
                Option::Some(game_address) => {
                    // Validate game address supports IMinigame interface
                    let game_src5_dispatcher = ISRC5Dispatcher { contract_address: game_address };
                    assert!(
                        game_src5_dispatcher.supports_interface(IMINIGAME_ID),
                        "CoreToken: Game address does not support IMinigame interface"
                    );
                    
                    // Check if this has a game registry address
                    let game_registry_address = self.game_registry_address.read();
                    if !game_registry_address.is_zero() {
                        // Multi-game token - get game ID
                        let game_registry_dispatcher = IMinigameRegistryDispatcher { contract_address: game_registry_address };
                        let game_id = game_registry_dispatcher.game_id_from_address(game_address);     
                        let game_address_display: felt252 = game_address.into();
                        assert!(
                            game_id != 0,
                            "MinigameToken: Game address {} not registered",
                            game_address_display,
                        );
                        (game_address, game_id)
                    } else {
                        // Single game token - verify against component's game address
                        let component_game_address = self.game_address.read();
                        assert!(
                            game_address == component_game_address,
                            "CoreToken: Game address does not match component's game address"
                        );
                        (game_address, 0)
                    }
                },
                Option::None => {
                    // Handle blank token
                    let component_game_address = self.game_address.read();
                    assert!(
                        !component_game_address.is_zero(),
                        "CoreToken: No game address provided and component has no default"
                    );
                    (component_game_address, 0)
                }
            }
        }
        
        fn resolve_game_address(self: @ComponentState<TContractState>, game_id: u64) -> ContractAddress {
            if game_id == 0 {
                // Single game token
                self.game_address.read()
            } else {
                // Multi-game token - resolve from game registry
                let game_registry_address = self.game_registry_address.read();
                let game_registry_dispatcher = IMinigameRegistryDispatcher { contract_address: game_registry_address };
                let game_address = game_registry_dispatcher.game_address_from_id(game_id);
                game_address
            }
        }
        
        fn assert_token_ownership(self: @ComponentState<TContractState>, token_id: u64) {
            let contract = self.get_contract();
            let erc721_component = ERC721::get_component(contract);
            let token_owner = erc721_component._owner_of(token_id.into());
            let caller = get_caller_address();
            assert!(
                token_owner == caller,
                "CoreToken: Caller is not owner of token"
            );
        }
        
        fn assert_playable(self: @ComponentState<TContractState>, token_id: u64) {
            let metadata = self.token_metadata.entry(token_id).read();
            let current_time = get_block_timestamp();
            let is_active = metadata.lifecycle.is_playable(current_time);
            assert!(
                is_active && !metadata.completed_all_objectives && !metadata.game_over,
                "CoreToken: Token is not playable"
            );
        }
        
        fn emit_score_update(ref self: ComponentState<TContractState>, token_id: u64, score: u64) {
            self.emit(ScoreUpdate { token_id, score });
        }
        
        fn emit_metadata_update(ref self: ComponentState<TContractState>, token_id: u64) {
            self.emit(MetadataUpdate { token_id });
        }
        
        fn get_token_metadata(self: @ComponentState<TContractState>, token_id: u64) -> TokenMetadata {
            self.token_metadata.entry(token_id).read()
        }
    }
}