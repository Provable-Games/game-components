#[starknet::component]
pub mod TokenComponent {
    use core::num::traits::Zero;
    use crate::interface::{IMinigameToken, IMINIGAME_TOKEN_ID};
    use crate::structs::{TokenMetadata, Lifecycle};
    use crate::libs::lifecycle::LifecycleTrait;
    use crate::extensions::multi_game::multi_game::MultiGameComponent;
    use crate::extensions::multi_game::multi_game::MultiGameComponent::InternalTrait as MultiGameInternalTrait;
    use crate::extensions::multi_game::interface::IMINIGAME_TOKEN_MULTIGAME_ID;
    use crate::extensions::multi_game::structs::GameMetadata;
    use crate::extensions::objectives::interface::IMINIGAME_TOKEN_OBJECTIVES_ID;
    use crate::extensions::objectives::objectives::TokenObjectivesComponent;
    use crate::extensions::objectives::objectives::TokenObjectivesComponent::InternalTrait as TokenObjectivesInternalTrait;
    use crate::extensions::objectives::structs::TokenObjective;
    use crate::extensions::settings::interface::IMINIGAME_TOKEN_SETTINGS_ID;
    use crate::extensions::minter::interface::IMINIGAME_TOKEN_MINTER_ID;
    use crate::extensions::minter::minter::MinterComponent;
    use crate::extensions::minter::minter::MinterComponent::InternalTrait as MinterInternalTrait;

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
    use game_components_metagame::extensions::context::structs::GameContextDetails;


    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_token::erc721::{
        ERC721Component, ERC721Component::{InternalImpl as ERC721InternalImpl},
    };

    #[storage]
    pub struct Storage {
        token_counter: u64,
        token_metadata: Map<u64, TokenMetadata>,
        token_player_names: Map<u64, ByteArray>,
        game_address: ContractAddress // this is set if the token is not a multi game token
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ScoreUpdate: ScoreUpdate,
        MetadataUpdate: MetadataUpdate,
        Owners: Owners,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ScoreUpdate {
        token_id: u64,
        score: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MetadataUpdate {
        token_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Owners {
        token_id: u64,
        owner: ContractAddress,
        auth: ContractAddress,
    }

    // NOTE: ERC721 hooks should be implemented at the contract level, not in components
    // This is an example of how a contract would implement hooks using component logic
    //
    // In your actual contract, you would implement this like:
    //
    // impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
    //     fn before_update(ref self: ERC721Component::ComponentState<ContractState>, ...) {
    //         // Access your soulbound component
    //         let contract = self.get_contract();
    //         let soulbound_component = get_dep_component!(ref contract, SoulboundComponent);
    //
    //         // Use the component's validation logic
    //         soulbound_component.validate_transfer(token_id, to, auth);
    //     }
    //     fn after_update(...) { /* emit events, etc. */ }
    // }

    #[embeddable_as(TokenImpl)]
    impl Token<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl MultiGame: MultiGameComponent::HasComponent<TContractState>,
        impl Minter: MinterComponent::HasComponent<TContractState>,
        impl TokenObjectives: TokenObjectivesComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameToken<ComponentState<TContractState>> {
        fn settings_id(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.settings_id
        }

        fn token_metadata(self: @ComponentState<TContractState>, token_id: u64) -> TokenMetadata {
            self.get_token_metadata(token_id)
        }

        fn is_playable(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let token_metadata = self.get_token_metadata(token_id);
            let active = token_metadata.lifecycle.is_playable(starknet::get_block_timestamp());
            active && !token_metadata.completed_all_objectives && !token_metadata.game_over
        }

        fn player_name(self: @ComponentState<TContractState>, token_id: u64) -> ByteArray {
            self.token_player_names.entry(token_id).read()
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
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            // TODO: Seperate logic within if checks to seperate internals
            let (game_id, settings_id, objectives_count) = match game_address {
                Option::Some(game_address) => {
                    // Check the game address supports IMinigame
                    let game_src5_dispatcher = ISRC5Dispatcher { contract_address: game_address };
                    assert!(
                        game_src5_dispatcher.supports_interface(IMINIGAME_ID),
                        "MinigameToken: Game does not support IMinigame",
                    );

                    // Check if the token contract supports multi-game
                    let mut game_id = 0;
                    let supports_multi_game_token = src5_component
                        .supports_interface(IMINIGAME_TOKEN_MULTIGAME_ID);
                    if supports_multi_game_token {
                        // TODO: Move this to multigame internal
                        let mut multi_game_component = get_dep_component_mut!(ref self, MultiGame);
                        game_id = multi_game_component.get_game_id_from_address(game_address);
                        let game_metadata: GameMetadata = multi_game_component
                            .get_game_metadata(game_id);
                        let game_address_display: felt252 = game_address.into();
                        assert!(
                            !game_metadata.contract_address.is_zero(),
                            "MinigameToken: Game address {} not registered",
                            game_address_display,
                        );
                    } else {
                        // If not a multi-game token, then we need to check game address is same as
                        // initialized game address
                        assert!(
                            game_address == self.game_address.read(),
                            "MinigameToken: Selected game address does not match initialized game address",
                        );
                    }
                    let settings_id = match settings_id {
                        Option::Some(settings_id) => {
                            // Check the token contract supports settings
                            let supports_settings = src5_component
                                .supports_interface(IMINIGAME_TOKEN_SETTINGS_ID);
                            assert!(supports_settings, "MinigameToken: Contract does not settings");
                            // TODO: Move this to settings component internal
                            let minigame_dispatcher = IMinigameDispatcher {
                                contract_address: game_address,
                            };
                            let settings_address = minigame_dispatcher.settings_address();
                            let settings_src5_dispatcher = ISRC5Dispatcher {
                                contract_address: settings_address,
                            };
                            assert!(
                                settings_src5_dispatcher.supports_interface(IMINIGAME_SETTINGS_ID),
                                "MinigameToken: Settings contract does not support IMinigameSettings",
                            );
                            let settings_dispatcher = IMinigameSettingsDispatcher {
                                contract_address: settings_address,
                            };
                            assert!(
                                settings_dispatcher.settings_exist(settings_id),
                                "MinigameToken: Settings id {} not registered",
                                settings_id,
                            );
                            settings_id
                        },
                        Option::None => { 0 },
                    };

                    let objectives_count = match objective_ids {
                        Option::Some(objective_ids) => {
                            // Check the token contract supports objectives
                            let supports_objectives = src5_component
                                .supports_interface(IMINIGAME_TOKEN_OBJECTIVES_ID);
                            assert!(
                                supports_objectives, "MinigameToken: Contract does not objectives",
                            );

                            let minigame_dispatcher = IMinigameDispatcher {
                                contract_address: game_address,
                            };
                            let objectives_address = minigame_dispatcher.objectives_address();
                            let objectives_src5_dispatcher = ISRC5Dispatcher {
                                contract_address: objectives_address,
                            };
                            assert!(
                                objectives_src5_dispatcher
                                    .supports_interface(IMINIGAME_OBJECTIVES_ID),
                                "MinigameToken: Objectives contract does not support IMinigameObjectives",
                            );
                            let objectives_dispatcher = IMinigameObjectivesDispatcher {
                                contract_address: objectives_address,
                            };
                            let mut objective_index: u32 = 0;
                            loop {
                                if objective_index == objective_ids.len() {
                                    break;
                                }
                                let objective_id = *objective_ids.at(objective_index);
                                assert!(
                                    objectives_dispatcher.objective_exists(objective_id),
                                    "Denshokan: Objective id {} not registered",
                                    objective_id,
                                );
                                objective_index += 1;
                            };
                            objective_index
                        },
                        Option::None => { 0 },
                    };

                    (game_id, settings_id, objectives_count)
                },
                Option::None => {
                    // TODO: Check if the token supports blank nft minting
                    assert!(
                        src5_component.supports_interface(IMINIGAME_TOKEN_SETTINGS_ID),
                        "MinigameToken: Does not support IMinigameTokenBlank",
                    );
                    (0, 0, 0)
                },
            };

            let start = match start {
                Option::Some(start) => { start },
                Option::None => { 0 },
            };

            let end = match end {
                Option::Some(end) => { end },
                Option::None => { 0 },
            };

            // if soulbound {
            //     let supports_soulbound =
            //     src5_component.supports_interface(IMINIGAME_TOKEN_SOULBOUND_ID);
            //     assert(supports_soulbound, "MinigameToken: Contract does not support soulbound")
            // }

            let caller_address = get_caller_address();

            let supports_minter = src5_component.supports_interface(IMINIGAME_TOKEN_MINTER_ID);
            let mut minted_by: u64 = 0;
            if supports_minter {
                let mut minter_component = get_dep_component_mut!(ref self, Minter);
                minted_by = minter_component.add_minter(caller_address);
            }

            // Create token metadata
            let metadata = TokenMetadata {
                game_id: game_id,
                minted_at: get_block_timestamp(),
                settings_id: settings_id,
                lifecycle: Lifecycle { start, end },
                minted_by,
                soulbound: soulbound,
                game_over: false,
                completed_all_objectives: false,
                has_context: false,
                objectives_count: objectives_count.try_into().unwrap(),
            };

            // Get next token ID
            let token_id = self.token_counter.read() + 1;
            self.token_metadata.entry(token_id).write(metadata);

            self.token_counter.write(token_id);

            // Set optional player name
            if let Option::Some(name) = player_name {
                self.token_player_names.entry(token_id).write(name);
            }
            // Mint ERC721 token
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            erc721_component.mint(to, token_id.into());

            token_id
        }

        fn update_game(ref self: ComponentState<TContractState>, token_id: u64) {
            // This function can be extended to update token state
            // For now, it's a placeholder for game-specific updates
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            assert!(
                erc721_component.exists(token_id.into()),
                "MinigameToken: Token id {} not minted",
                token_id,
            );
            let token_metadata: TokenMetadata = self.token_metadata.entry(token_id).read();
            // If the token is multigame then we need to do the game registry lookup, otherwise we
            // just take the game address itself
            let mut completed_all_objectives = false;
            let mut game_address = self.game_address.read();
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            let mut multi_game_component = get_dep_component_mut!(ref self, MultiGame);
            let supports_objectives = src5_component
                .supports_interface(IMINIGAME_TOKEN_OBJECTIVES_ID);
            if supports_objectives {
                let supports_multi_game_token = src5_component
                    .supports_interface(IMINIGAME_TOKEN_MULTIGAME_ID);
                if supports_multi_game_token {
                    game_address = multi_game_component
                        .get_game_address_from_id(token_metadata.game_id);
                }
                let src5_dispatcher = ISRC5Dispatcher { contract_address: game_address };
                assert!(
                    src5_dispatcher.supports_interface(IMINIGAME_OBJECTIVES_ID),
                    "MinigameToken: Game does not support objectives",
                );
                if token_metadata.objectives_count > 0 {
                    let supports_multi_game_token = src5_component
                        .supports_interface(IMINIGAME_TOKEN_MULTIGAME_ID);
                    let minigame_dispatcher = if supports_multi_game_token {
                        // Get game metadata to check for multi game token
                        let game_metadata: GameMetadata = multi_game_component
                            .get_game_metadata(token_metadata.game_id);
                        IMinigameDispatcher { contract_address: game_metadata.contract_address }
                    } else {
                        // Get the initialized game address for single game token
                        IMinigameDispatcher { contract_address: game_address }
                    };
                    let objectives_address = minigame_dispatcher.objectives_address();
                    let objectives_src5_dispatcher = ISRC5Dispatcher {
                        contract_address: objectives_address,
                    };
                    assert!(
                        objectives_src5_dispatcher.supports_interface(IMINIGAME_OBJECTIVES_ID),
                        "MinigameToken: Objectives contract does not support IMinigameObjectives",
                    );
                    let game_objectives_dispatcher = IMinigameObjectivesDispatcher {
                        contract_address: objectives_address,
                    };
                    let mut completed_objectives: u32 = 0;
                    let mut objective_index: u32 = 0;
                    loop {
                        if objective_index == token_metadata.objectives_count.into() {
                            break;
                        }
                        // This doesn't work as token objectives is not required
                        let mut objectives_token_component = get_dep_component_mut!(
                            ref self, TokenObjectives,
                        );
                        let token_objective: TokenObjective = objectives_token_component
                            .get_objective(token_id, objective_index);
                        let objective_id = token_objective.objective_id;
                        let is_objective_completed = game_objectives_dispatcher
                            .completed_objective(token_id, objective_id);
                        if is_objective_completed {
                            let token_objective: TokenObjective = TokenObjective {
                                objective_id, completed: true,
                            };
                            objectives_token_component
                                .set_objective(token_id, objective_index, token_objective);
                            completed_objectives += 1;
                        }
                        objective_index += 1;
                    };
                    if completed_objectives == token_metadata.objectives_count.into() {
                        completed_all_objectives = true;
                    }
                }
            }

            let minigame_token_data_dispatcher = IMinigameTokenDataDispatcher {
                contract_address: game_address,
            };

            let game_over = minigame_token_data_dispatcher.game_over(token_id);

            // only set metadata if game is over, or all objectives completed
            if completed_all_objectives || game_over {
                self
                    .token_metadata
                    .entry(token_id)
                    .write(
                        TokenMetadata {
                            game_id: token_metadata.game_id,
                            minted_by: token_metadata.minted_by,
                            minted_at: token_metadata.minted_at,
                            settings_id: token_metadata.settings_id,
                            lifecycle: token_metadata.lifecycle,
                            soulbound: token_metadata.soulbound,
                            game_over,
                            completed_all_objectives,
                            has_context: token_metadata.has_context,
                            objectives_count: token_metadata.objectives_count,
                        },
                    );
            }
            let score = minigame_token_data_dispatcher.score(token_id);
            self.emit_score_update(token_id, score.into());

            self.emit_metadata_update(token_id);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>, game_address: Option<ContractAddress>,
        ) {
            // Register token interface
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_TOKEN_ID);
            match game_address {
                Option::Some(game_address) => { self.game_address.write(game_address); },
                Option::None => {},
            }
        }

        fn get_token_metadata(
            self: @ComponentState<TContractState>, token_id: u64,
        ) -> TokenMetadata {
            self.token_metadata.entry(token_id).read()
        }

        fn assert_token_ownership(self: @ComponentState<TContractState>, token_id: u64) {
            let erc721_component = get_dep_component!(self, ERC721);
            let token_owner = erc721_component._owner_of(token_id.into());
            assert!(
                token_owner == starknet::get_caller_address(),
                "Caller is not owner of token {}",
                token_id,
            );
        }

        fn assert_playable(self: @ComponentState<TContractState>, token_id: u64) {
            let metadata = self.token_metadata.entry(token_id).read();
            let active = metadata.lifecycle.is_playable(starknet::get_block_timestamp());
            assert!(
                active && !metadata.completed_all_objectives && !metadata.game_over,
                "MinigameToken: Token {} is not playable",
                token_id,
            )
        }

        fn emit_score_update(ref self: ComponentState<TContractState>, token_id: u64, score: u64) {
            self.emit(ScoreUpdate { token_id, score });
        }

        fn emit_metadata_update(ref self: ComponentState<TContractState>, token_id: u64) {
            self.emit(MetadataUpdate { token_id });
        }
    }
}
