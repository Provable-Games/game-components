#[starknet::component]
pub mod CoreTokenComponent {
    use core::num::traits::Zero;
    use game_components_metagame::extensions::callback::interface::{
        IMETAGAME_CALLBACK_ID, IMetagameCallbackDispatcher, IMetagameCallbackDispatcherTrait,
    };
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use game_components_minigame::interface::{
        IMINIGAME_ID, IMinigameTokenDataDispatcher, IMinigameTokenDataDispatcherTrait,
    };
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::{
        ERC721Impl, InternalTrait as ERC721InternalTrait,
    };
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::core::interface::{IMINIGAME_TOKEN_ID, IMinigameToken};
    use crate::core::traits::{
        OptionalContext, OptionalMinter, OptionalObjectives, OptionalRenderer, OptionalSettings,
    };
    use crate::extensions::minter::interface::IMINIGAME_TOKEN_MINTER_ID;
    use crate::interface::{IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait};
    use crate::libs::{LifecycleTrait, token_state};
    use crate::structs::TokenMetadata;

    #[storage]
    pub struct Storage {
        token_metadata: Map<u64, TokenMetadata>,
        token_player_names: Map<u64, felt252>,
        token_client_url: Map<u64, ByteArray>,
        token_counter: u64,
        game_address: ContractAddress,
        game_registry_address: ContractAddress,
    }

    // ==========================================================================
    // NATIVE EVENTS - Optimized for indexing with proper #[key] fields
    // ==========================================================================
    // Events are emitted directly as native Starknet events for gas efficiency.
    // All indexed fields use #[key] for efficient filtering in indexers.

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        // Core token lifecycle events
        TokenMinted: TokenMinted,
        ScoreUpdate: ScoreUpdate,
        GameOver: GameOver,
        TokenMetadataUpdate: TokenMetadataUpdate,
        // Player events
        TokenPlayerNameUpdate: TokenPlayerNameUpdate,
        TokenClientUrlUpdate: TokenClientUrlUpdate,
        // ERC721 standard
        MetadataUpdate: MetadataUpdate,
    }

    /// Emitted when a new token is minted
    #[derive(Drop, starknet::Event)]
    pub struct TokenMinted {
        #[key]
        pub token_id: u256,
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub game_id: u16,
        pub minted_by: u16,
        pub settings_id: u16,
        pub minted_at: u64,
        pub soulbound: bool,
    }

    /// Emitted when a token's score is updated
    #[derive(Drop, starknet::Event)]
    pub struct ScoreUpdate {
        #[key]
        pub token_id: u256,
        #[key]
        pub game_id: u16,
        pub score: u32,
        pub block_timestamp: u64,
    }

    /// Emitted when a game ends (game_over transitions to true)
    #[derive(Drop, starknet::Event)]
    pub struct GameOver {
        #[key]
        pub token_id: u256,
        #[key]
        pub game_id: u16,
        pub final_score: u32,
        pub completed_objectives: bool,
    }

    /// Emitted when token metadata is updated
    #[derive(Drop, starknet::Event)]
    pub struct TokenMetadataUpdate {
        #[key]
        pub id: u64,
        pub game_id: u64,
        pub minted_at: u64,
        pub settings_id: u32,
        pub lifecycle_start: u64,
        pub lifecycle_end: u64,
        pub minted_by: u64,
        pub soulbound: bool,
        pub game_over: bool,
        pub completed_objective: bool,
        pub has_context: bool,
        pub objective_id: u32,
    }

    /// Emitted when player name is updated
    #[derive(Drop, starknet::Event)]
    pub struct TokenPlayerNameUpdate {
        #[key]
        pub id: u64,
        pub player_name: felt252,
    }

    /// Emitted when client URL is updated
    #[derive(Drop, starknet::Event)]
    pub struct TokenClientUrlUpdate {
        #[key]
        pub id: u64,
        pub client_url: ByteArray,
    }

    /// ERC721 standard metadata update event
    #[derive(Drop, starknet::Event)]
    pub struct MetadataUpdate {
        #[key]
        pub token_id: u256,
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
            token_state::is_token_playable(@metadata, current_time)
        }

        fn settings_id(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.settings_id
        }

        fn player_name(self: @ComponentState<TContractState>, token_id: u64) -> felt252 {
            self.token_player_names.entry(token_id).read()
        }

        fn objective_id(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.objective_id
        }

        fn minted_by(self: @ComponentState<TContractState>, token_id: u64) -> u64 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.minted_by
        }

        fn game_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.game_address.read()
        }

        fn game_registry_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.game_registry_address.read()
        }

        fn is_soulbound(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.soulbound
        }

        fn renderer_address(
            self: @ComponentState<TContractState>, token_id: u64,
        ) -> ContractAddress {
            let contract_self = self.get_contract();
            let renderer = RendererOpt::get_token_renderer(contract_self, token_id);
            match renderer {
                Option::Some(addr) => addr,
                Option::None => {
                    // If no renderer is set, check if it's a single game token
                    let token_metadata = self.token_metadata(token_id);
                    let game_registry_dispatcher = IMinigameRegistryDispatcher {
                        contract_address: self.game_registry_address.read(),
                    };
                    let game_metadata = game_registry_dispatcher
                        .game_metadata(token_metadata.game_id);
                    let game_renderer_address = game_metadata.renderer_address;
                    if !game_renderer_address.is_zero() {
                        game_renderer_address
                    } else {
                        self.token_game_address(token_id)
                    }
                },
            }
        }

        fn token_game_address(
            self: @ComponentState<TContractState>, token_id: u64,
        ) -> ContractAddress {
            let metadata = self.token_metadata.entry(token_id).read();
            if token_state::is_single_game_token(metadata.game_id) {
                // Single game token - use component's game address
                self.game_address.read()
            } else {
                // Multi-game token - resolve from game registry
                let game_registry_dispatcher = IMinigameRegistryDispatcher {
                    contract_address: self.game_registry_address.read(),
                };
                let game_address = game_registry_dispatcher.game_address_from_id(metadata.game_id);
                game_address
            }
        }

        fn mint(
            ref self: ComponentState<TContractState>,
            game_address: Option<ContractAddress>,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            self
                .mint_game(
                    game_address,
                    player_name,
                    settings_id,
                    start,
                    end,
                    objective_id,
                    context,
                    client_url,
                    renderer_address,
                    to,
                    soulbound,
                )
        }

        fn mint_batch(
            ref self: ComponentState<TContractState>,
            game_address: Option<ContractAddress>,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
            quantity: u32,
        ) {
            let mut mint_index: u32 = 0;
            loop {
                if (mint_index == quantity) {
                    break;
                }
                // For each mint, reconstruct the Option values
                let context_copy = match @context {
                    Option::Some(ctx) => Option::Some(ctx.clone()),
                    Option::None => Option::None,
                };
                let client_url_copy = match @client_url {
                    Option::Some(url) => Option::Some(url.clone()),
                    Option::None => Option::None,
                };

                self
                    .mint_game(
                        game_address,
                        player_name,
                        settings_id,
                        start,
                        end,
                        objective_id,
                        context_copy,
                        client_url_copy,
                        renderer_address,
                        to,
                        soulbound,
                    );
                mint_index += 1;
            }
        }

        fn set_token_metadata(
            ref self: ComponentState<TContractState>,
            token_id: u64,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
        ) {
            // This function only becomes relavant if we are keeping track of the minter address
            // Validate game address supports required interfaces
            let src5_component = get_dep_component!(@self, SRC5);
            let supports_minter = src5_component.supports_interface(IMINIGAME_TOKEN_MINTER_ID);
            assert!(
                supports_minter,
                "MinigameToken: Game does not support IMinigameTokenMinter interface",
            );
            let caller = get_caller_address();

            // Validate lifecycle parameters regardless of token type
            let lifecycle = token_state::create_lifecycle_with_defaults(start, end);
            lifecycle.validate();

            let mut contract_self = self.get_contract_mut();
            let mut contract = self.get_contract();
            let erc721_component = ERC721::get_component(contract);
            assert!(
                erc721_component.exists(token_id.into()),
                "MinigameToken: Token id {} not minted",
                token_id,
            );
            let token_metadata: TokenMetadata = self.get_token_metadata(token_id);
            assert!(
                token_metadata.game_id.is_zero(), "MinigameToken: Token id {} not blank", token_id,
            );
            // Get minted by address and assert it is the caller
            let minted_by = token_metadata.minted_by;
            let minter_address = MinterOpt::get_minter_address(contract, minted_by);
            let minter_address_felt: felt252 = minter_address.into();
            assert!(
                minter_address == caller,
                "MinigameToken: Token id {} minted by {} not by caller",
                token_id,
                minter_address_felt,
            );

            let (final_game_address, game_id) = self
                .validate_and_process_game_address(game_address);

            // Validate settings if provided
            let validated_settings_id = match settings_id {
                Option::Some(settings_id) => {
                    SettingsOpt::validate_settings(contract, final_game_address, settings_id);
                    settings_id
                },
                Option::None => 0,
            };

            // Validate objective if provided
            let validated_objective_id: u32 = match objective_id {
                Option::Some(obj_id) => {
                    ObjectivesOpt::validate_objective(contract, final_game_address, obj_id);
                    obj_id
                },
                Option::None => 0,
            };

            // Handle context if provided
            let has_context = match context {
                Option::Some(context) => {
                    ContextOpt::emit_context(ref contract_self, caller, token_id, context);
                    true
                },
                Option::None => false,
            };

            let token_metadata = self.get_token_metadata(token_id);
            let current_time = get_block_timestamp();

            let metadata = token_state::create_game_token_metadata(
                game_id,
                validated_settings_id,
                lifecycle,
                token_metadata.minted_by,
                token_metadata.soulbound,
                has_context,
                validated_objective_id,
                current_time,
            );

            self.token_metadata.entry(token_id).write(metadata);

            // Set player name if provided
            if let Option::Some(name) = player_name {
                self.token_player_names.entry(token_id).write(name);
                self.emit_token_player_name_update(token_id, name);
            }

            // Emit native event for metadata update
            self
                .emit_token_metadata_update(
                    token_id,
                    metadata.game_id,
                    metadata.minted_at,
                    metadata.settings_id,
                    metadata.lifecycle.start,
                    metadata.lifecycle.end,
                    metadata.minted_by,
                    metadata.soulbound,
                    metadata.game_over,
                    metadata.completed_objective,
                    metadata.has_context,
                    metadata.objective_id,
                );
        }


        fn update_game(ref self: ComponentState<TContractState>, token_id: u64) {
            // Validate token exists
            let mut contract = self.get_contract_mut();
            let mut erc721_component = ERC721::get_component_mut(ref contract);
            assert!(
                erc721_component.exists(token_id.into()),
                "MinigameToken: Token {} does not exist",
                token_id,
            );

            let token_metadata = self.token_metadata.entry(token_id).read();
            let game_address = self.resolve_game_address(token_metadata.game_id);

            // Validate game address supports required interfaces
            let game_src5_dispatcher = ISRC5Dispatcher { contract_address: game_address };
            assert!(
                game_src5_dispatcher.supports_interface(IMINIGAME_ID),
                "MinigameToken: Game does not support IMinigame interface",
            );

            // Note: Objectives completion is tracked by the metadata's completed_objective field
            // which can be updated externally. The objective_id indicates which objective is set.
            let completed_objective = token_metadata.completed_objective;

            // Get current game state
            let minigame_token_data_dispatcher = IMinigameTokenDataDispatcher {
                contract_address: game_address,
            };

            let game_over = minigame_token_data_dispatcher.game_over(token_id);
            let score = minigame_token_data_dispatcher.score(token_id);

            // Ensure game_over and completed_objective can only transition from false to true
            let final_game_over = token_state::ensure_game_over_transition(
                token_metadata.game_over, game_over,
            );
            let final_completed_objective = token_state::ensure_objectives_completion_transition(
                token_metadata.completed_objective, completed_objective,
            );

            // Track state transitions for callbacks
            let game_over_transition = final_game_over && !token_metadata.game_over;
            let objective_complete_transition = final_completed_objective
                && !token_metadata.completed_objective;

            // Update metadata if game state changed
            if final_completed_objective != token_metadata.completed_objective
                || final_game_over != token_metadata.game_over {
                // Create updated metadata preserving original values
                let updated_metadata = TokenMetadata {
                    game_id: token_metadata.game_id,
                    minted_at: token_metadata.minted_at,
                    settings_id: token_metadata.settings_id,
                    lifecycle: token_metadata.lifecycle,
                    minted_by: token_metadata.minted_by,
                    soulbound: token_metadata.soulbound,
                    game_over: final_game_over,
                    completed_objective: final_completed_objective,
                    has_context: token_metadata.has_context,
                    objective_id: token_metadata.objective_id,
                };

                self.token_metadata.entry(token_id).write(updated_metadata);
                self
                    .emit_token_metadata_update(
                        token_id,
                        updated_metadata.game_id,
                        updated_metadata.minted_at,
                        updated_metadata.settings_id,
                        updated_metadata.lifecycle.start,
                        updated_metadata.lifecycle.end,
                        updated_metadata.minted_by,
                        updated_metadata.soulbound,
                        final_game_over,
                        final_completed_objective,
                        updated_metadata.has_context,
                        updated_metadata.objective_id,
                    );
            }

            // Emit native score update event (always)
            let current_time = get_block_timestamp();
            self
                .emit(
                    ScoreUpdate {
                        token_id: token_id.into(),
                        game_id: token_metadata.game_id.try_into().unwrap_or(0),
                        score,
                        block_timestamp: current_time,
                    },
                );

            // Emit GameOver event if game just ended
            if game_over_transition {
                self
                    .emit(
                        GameOver {
                            token_id: token_id.into(),
                            game_id: token_metadata.game_id.try_into().unwrap_or(0),
                            final_score: score,
                            completed_objectives: final_completed_objective,
                        },
                    );
            }

            // Always emit metadata update
            self.emit_metadata_update(token_id.into());

            // =================================================================
            // METAGAME CALLBACKS - Notify minter contract of state changes
            // =================================================================
            // If the minter (metagame contract) implements IMetagameCallback,
            // invoke callbacks to enable automatic score aggregation.
            // Safe SRC5 check handles contracts that don't implement SRC5.

            let contract_ref = self.get_contract();
            let minter_address = MinterOpt::get_minter_address(
                contract_ref, token_metadata.minted_by,
            );

            if !minter_address.is_zero() {
                // Safe SRC5 check using call_contract_syscall to handle contracts
                // that don't implement SRC5 (will return Err instead of panicking)
                let supports_interface_selector = selector!("supports_interface");
                let mut calldata = array![];
                calldata.append(IMETAGAME_CALLBACK_ID);

                let supports_callback =
                    match call_contract_syscall(
                        minter_address, supports_interface_selector, calldata.span(),
                    ) {
                    Result::Ok(result) => {
                        let mut result_span = result;
                        match Serde::<bool>::deserialize(ref result_span) {
                            Option::Some(val) => val,
                            Option::None => false,
                        }
                    },
                    Result::Err(_) => false,
                };

                if supports_callback {
                    let callback = IMetagameCallbackDispatcher { contract_address: minter_address };

                    // Always notify score update (callback can filter if needed)
                    callback.on_score_update(token_id.into(), score);

                    // Notify game over if transitioned
                    if game_over_transition {
                        callback.on_game_over(token_id.into(), score);
                    }

                    // Notify objective complete if transitioned
                    if objective_complete_transition {
                        callback.on_objective_complete(token_id.into());
                    }
                }
            }
        }

        fn update_player_name(
            ref self: ComponentState<TContractState>, token_id: u64, name: felt252,
        ) {
            assert!(!name.is_zero(), "MinigameToken: Player name is empty");
            let mut contract = self.get_contract();
            let erc721_component = ERC721::get_component(contract);
            assert!(
                erc721_component.exists(token_id.into()),
                "MinigameToken: Token id {} not minted",
                token_id,
            );
            self.assert_token_ownership(token_id);
            self.token_player_names.entry(token_id).write(name);
            self.emit_token_player_name_update(token_id, name);
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
            creator_address: Option<ContractAddress>,
            game_registry_address: Option<ContractAddress>,
        ) {
            // Register token interface
            let mut contract = self.get_contract_mut();
            let mut src5_component = SRC5::get_component_mut(ref contract);
            src5_component.register_interface(IMINIGAME_TOKEN_ID);

            // Set game address if provided
            if let Option::Some(game_address) = game_address {
                assert!(!game_address.is_zero(), "MinigameToken: Game address is zero");
                self.game_address.write(game_address);
            }

            if let Option::Some(game_registry_address) = game_registry_address {
                assert!(
                    !game_registry_address.is_zero(),
                    "MinigameToken: Game registry address is zero",
                );
                self.game_registry_address.write(game_registry_address);
            } else {
                // If no game registry provided, then we know this is a single game token,
                // so mint token 0 to the creator.
                assert!(
                    game_address.is_some(),
                    "MinigameToken: Game address must be provided for single game token",
                );
                assert!(
                    creator_address.is_some(),
                    "MinigameToken: Creator address must be provided for single game token",
                );
                let mut contract = self.get_contract_mut();
                let mut erc721_component = ERC721::get_component_mut(ref contract);
                erc721_component.mint(creator_address.unwrap(), 0);
            }

            // Ensure at least one game address is set
            if game_address.is_none() && game_registry_address.is_none() {
                panic!(
                    "MinigameToken: Either game_address or game_registry_address must be provided",
                );
            }
        }

        fn token_counter(self: @ComponentState<TContractState>) -> u64 {
            self.token_counter.read()
        }

        fn mint_game(
            ref self: ComponentState<TContractState>,
            game_address: Option<ContractAddress>,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            let caller = get_caller_address();
            let token_id = self.token_counter.read() + 1;

            // Validate lifecycle parameters regardless of token type
            let lifecycle = token_state::create_lifecycle_with_defaults(start, end);
            lifecycle.validate();

            match game_address {
                Option::Some(provided_game_address) => {
                    // Full game token with validation and setup
                    let (final_game_address, game_id) = self
                        .validate_and_process_game_address(provided_game_address);

                    let mut contract = self.get_contract();
                    let mut contract_self = self.get_contract_mut();
                    // Validate settings if provided
                    let validated_settings_id = match settings_id {
                        Option::Some(settings_id) => {
                            SettingsOpt::validate_settings(
                                contract, final_game_address, settings_id,
                            );
                            settings_id
                        },
                        Option::None => 0,
                    };

                    // Validate objective if provided
                    let validated_objective_id: u32 = match objective_id {
                        Option::Some(obj_id) => {
                            ObjectivesOpt::validate_objective(contract, final_game_address, obj_id);
                            obj_id
                        },
                        Option::None => 0,
                    };

                    // Handle context if provided
                    let has_context = match context {
                        Option::Some(context) => {
                            ContextOpt::emit_context(ref contract_self, caller, token_id, context);
                            true
                        },
                        Option::None => false,
                    };

                    // Handle minter tracking if enabled
                    let minted_by = MinterOpt::add_minter(ref contract_self, caller);

                    // Handle renderer if provided
                    match renderer_address {
                        Option::Some(renderer_address) => {
                            RendererOpt::set_token_renderer(
                                ref contract_self, token_id, renderer_address,
                            );
                        },
                        Option::None => {},
                    }

                    // Create token metadata
                    let current_time = get_block_timestamp();
                    let metadata = token_state::create_game_token_metadata(
                        game_id,
                        validated_settings_id,
                        lifecycle,
                        minted_by,
                        soulbound,
                        has_context,
                        validated_objective_id,
                        current_time,
                    );

                    self.token_metadata.entry(token_id).write(metadata);
                    self.token_counter.write(token_id);

                    // Set player name if provided
                    if let Option::Some(name) = player_name {
                        self.token_player_names.entry(token_id).write(name);
                        self.emit_token_player_name_update(token_id, name);
                    }

                    // Set client url if provided
                    if let Option::Some(url) = client_url {
                        self.token_client_url.entry(token_id).write(url.clone());
                        self.emit_token_client_url_update(token_id, url);
                    }

                    // Emit native events for token metadata
                    self
                        .emit_token_metadata_update(
                            token_id,
                            metadata.game_id,
                            metadata.minted_at,
                            metadata.settings_id,
                            metadata.lifecycle.start,
                            metadata.lifecycle.end,
                            metadata.minted_by,
                            metadata.soulbound,
                            metadata.game_over,
                            metadata.completed_objective,
                            metadata.has_context,
                            metadata.objective_id,
                        );

                    // Mint the ERC721 token
                    let mut contract = self.get_contract_mut();
                    let mut erc721_component = ERC721::get_component_mut(ref contract);
                    erc721_component.mint(to, token_id.into());

                    // Emit native TokenMinted event
                    self
                        .emit_token_minted(
                            token_id.into(),
                            to,
                            game_id.try_into().unwrap_or(0),
                            minted_by.try_into().unwrap_or(0),
                            validated_settings_id.try_into().unwrap_or(0),
                            current_time,
                            soulbound,
                        );

                    token_id
                },
                Option::None => {
                    let src5_component = get_dep_component!(@self, SRC5);
                    let supports_minter = src5_component
                        .supports_interface(IMINIGAME_TOKEN_MINTER_ID);
                    assert!(
                        supports_minter,
                        "MinigameToken: Game does not support IMinigameTokenMinter interface",
                    );
                    // Blank token - minimal processing with default values
                    let mut contract_self = self.get_contract_mut();

                    // Only handle minter tracking for blank tokens
                    let minted_by = MinterOpt::add_minter(ref contract_self, caller);

                    // Handle renderer if provided
                    match renderer_address {
                        Option::Some(renderer_address) => {
                            RendererOpt::set_token_renderer(
                                ref contract_self, token_id, renderer_address,
                            );
                        },
                        Option::None => {},
                    }

                    // Create minimal token metadata with empty/default values
                    let current_time = get_block_timestamp();
                    let metadata = token_state::create_blank_token_metadata(
                        lifecycle, minted_by, soulbound, current_time,
                    );

                    self.token_metadata.entry(token_id).write(metadata);
                    self.token_counter.write(token_id);

                    // Set player name if provided
                    if let Option::Some(name) = player_name {
                        self.token_player_names.entry(token_id).write(name.clone());
                        self.emit_token_player_name_update(token_id, name);
                    }

                    // Emit native events for metadata
                    self
                        .emit_token_metadata_update(
                            token_id,
                            metadata.game_id,
                            metadata.minted_at,
                            metadata.settings_id,
                            metadata.lifecycle.start,
                            metadata.lifecycle.end,
                            metadata.minted_by,
                            metadata.soulbound,
                            metadata.game_over,
                            metadata.completed_objective,
                            metadata.has_context,
                            metadata.objective_id,
                        );

                    // Mint the ERC721 token
                    let mut erc721_component = ERC721::get_component_mut(ref contract_self);
                    erc721_component.mint(to, token_id.into());

                    // Emit native TokenMinted event for blank token (game_id = 0)
                    self
                        .emit_token_minted(
                            token_id.into(),
                            to,
                            0, // game_id is 0 for blank tokens
                            minted_by.try_into().unwrap_or(0),
                            0, // settings_id is 0 for blank tokens
                            current_time,
                            soulbound,
                        );

                    token_id
                },
            }
        }

        fn validate_and_process_game_address(
            self: @ComponentState<TContractState>, game_address: ContractAddress,
        ) -> (ContractAddress, u64) {
            assert!(!game_address.is_zero(), "MinigameToken: Game address is zero");
            // Validate game address supports IMinigame interface
            let game_src5_dispatcher = ISRC5Dispatcher { contract_address: game_address };
            assert!(
                game_src5_dispatcher.supports_interface(IMINIGAME_ID),
                "MinigameToken: Game does not support IMinigame interface",
            );

            // Check if this has a game registry address
            let game_registry_address = self.game_registry_address.read();
            if !game_registry_address.is_zero() {
                // Multi-game token - get game ID
                let game_registry_dispatcher = IMinigameRegistryDispatcher {
                    contract_address: game_registry_address,
                };
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
                    "MinigameToken: Game address does not match component's game address",
                );
                (game_address, 0)
            }
        }

        fn resolve_game_address(
            self: @ComponentState<TContractState>, game_id: u64,
        ) -> ContractAddress {
            if game_id == 0 {
                // Single game token
                self.game_address.read()
            } else {
                // Multi-game token - resolve from game registry
                let game_registry_address = self.game_registry_address.read();
                let game_registry_dispatcher = IMinigameRegistryDispatcher {
                    contract_address: game_registry_address,
                };
                let game_address = game_registry_dispatcher.game_address_from_id(game_id);
                game_address
            }
        }

        fn assert_token_ownership(self: @ComponentState<TContractState>, token_id: u64) {
            let contract = self.get_contract();
            let erc721_component = ERC721::get_component(contract);
            let token_owner = erc721_component._owner_of(token_id.into());
            let caller = get_caller_address();
            assert!(token_owner == caller, "MinigameToken: Caller is not owner of token");
        }

        fn assert_playable(self: @ComponentState<TContractState>, token_id: u64) {
            let metadata = self.token_metadata.entry(token_id).read();
            let current_time = get_block_timestamp();
            let is_active = metadata.lifecycle.is_playable(current_time);
            assert!(
                is_active && !metadata.completed_objective && !metadata.game_over,
                "MinigameToken: Token is not playable",
            );
        }

        // =================================================================
        // NATIVE EVENT EMITTERS
        // =================================================================
        // All events are now emitted directly as native Starknet events.
        // The relayer pattern has been removed for gas efficiency.

        fn emit_token_player_name_update(
            ref self: ComponentState<TContractState>, id: u64, player_name: felt252,
        ) {
            self.emit(TokenPlayerNameUpdate { id, player_name });
        }

        fn emit_token_client_url_update(
            ref self: ComponentState<TContractState>, id: u64, client_url: ByteArray,
        ) {
            self.emit(TokenClientUrlUpdate { id, client_url });
        }

        fn emit_token_metadata_update(
            ref self: ComponentState<TContractState>,
            id: u64,
            game_id: u64,
            minted_at: u64,
            settings_id: u32,
            start: u64,
            end: u64,
            minted_by: u64,
            soulbound: bool,
            game_over: bool,
            completed_objective: bool,
            has_context: bool,
            objective_id: u32,
        ) {
            self
                .emit(
                    TokenMetadataUpdate {
                        id,
                        game_id,
                        minted_at,
                        settings_id,
                        lifecycle_start: start,
                        lifecycle_end: end,
                        minted_by,
                        soulbound,
                        game_over,
                        completed_objective,
                        has_context,
                        objective_id,
                    },
                );
        }

        /// Emit TokenMinted event for new tokens
        fn emit_token_minted(
            ref self: ComponentState<TContractState>,
            token_id: u256,
            owner: ContractAddress,
            game_id: u16,
            minted_by: u16,
            settings_id: u16,
            minted_at: u64,
            soulbound: bool,
        ) {
            self
                .emit(
                    TokenMinted {
                        token_id, owner, game_id, minted_by, settings_id, minted_at, soulbound,
                    },
                );
        }

        fn emit_metadata_update(ref self: ComponentState<TContractState>, token_id: u256) {
            self.emit(MetadataUpdate { token_id });
        }

        fn get_token_metadata(
            self: @ComponentState<TContractState>, token_id: u64,
        ) -> TokenMetadata {
            self.token_metadata.entry(token_id).read()
        }
    }
}
