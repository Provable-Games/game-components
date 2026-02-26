#[starknet::component]
pub mod CoreTokenComponent {
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::metagame::extensions::callback::interface::{
        IMETAGAME_CALLBACK_ID, IMetagameCallbackDispatcher, IMetagameCallbackDispatcherTrait,
    };
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
    use game_components_embeddable_game_standard::minigame::interface::{
        IMINIGAME_ID, IMinigameTokenDataDispatcher, IMinigameTokenDataDispatcherTrait,
    };
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use openzeppelin_token::common::erc2981::erc2981::ERC2981Component;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::{
        ERC721Impl, InternalTrait as ERC721InternalTrait,
    };
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_tx_info};
    use crate::token::interface::{
        IMINIGAME_TOKEN_ID, IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
        IMinigameToken,
    };
    use crate::token::structs::{
        LifecycleStorePacking, MintParams, PlayerNameUpdate, TokenFullState, TokenMetadata,
        TokenMutableState, TokenMutableStateStorePacking, extract_tx_hash_bits, pack_token_id,
        to_token_metadata, unpack_game_id, unpack_minted_by, unpack_objective_id, unpack_soulbound,
        unpack_token_id,
    };
    use crate::token::token::{LifecycleTrait, token_state};
    use crate::token::traits::{
        OptionalContext, OptionalMinter, OptionalObjectives, OptionalRenderer, OptionalSettings,
    };

    #[storage]
    pub struct Storage {
        token_mutable_state: Map<felt252, TokenMutableState>,
        token_player_names: Map<felt252, felt252>,
        token_client_url: Map<felt252, ByteArray>,
        game_address: ContractAddress,
        game_registry_address: ContractAddress,
    }

    // ==========================================================================
    // NATIVE EVENTS - Optimized for indexing with proper #[key] fields
    // ==========================================================================

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        // Player events
        TokenPlayerNameUpdate: TokenPlayerNameUpdate,
        TokenClientUrlUpdate: TokenClientUrlUpdate,
        // ERC721 standard
        MetadataUpdate: MetadataUpdate,
        ScoreUpdate: ScoreUpdate,
        GameOver: GameOver,
        CompletedObjective: CompletedObjective,
    }

    /// Emitted when player name is updated
    #[derive(Drop, starknet::Event)]
    pub struct TokenPlayerNameUpdate {
        #[key]
        pub id: felt252,
        pub player_name: felt252,
    }

    /// Emitted when client URL is updated
    #[derive(Drop, starknet::Event)]
    pub struct TokenClientUrlUpdate {
        #[key]
        pub id: felt252,
        pub client_url: ByteArray,
    }

    /// ERC721 standard metadata update event
    #[derive(Drop, starknet::Event)]
    pub struct MetadataUpdate {
        #[key]
        pub token_id: u256,
    }

    /// Emitted when score is updated
    #[derive(Drop, starknet::Event)]
    pub struct ScoreUpdate {
        #[key]
        pub token_id: felt252,
        pub score: u64,
    }

    /// Emitted when a game ends (game_over transitions from false to true)
    #[derive(Drop, starknet::Event)]
    pub struct GameOver {
        #[key]
        pub token_id: felt252,
        pub score: u64,
    }

    /// Emitted when an objective is completed
    #[derive(Drop, starknet::Event)]
    pub struct CompletedObjective {
        #[key]
        pub token_id: felt252,
    }

    #[embeddable_as(CoreTokenImpl)]
    pub impl CoreToken<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl ERC2981: ERC2981Component::HasComponent<TContractState>,
        impl MinterOpt: OptionalMinter<TContractState>,
        impl ContextOpt: OptionalContext<TContractState>,
        impl ObjectivesOpt: OptionalObjectives<TContractState>,
        impl SettingsOpt: OptionalSettings<TContractState>,
        impl RendererOpt: OptionalRenderer<TContractState>,
        +Drop<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +ERC2981Component::ImmutableConfig,
    > of IMinigameToken<ComponentState<TContractState>> {
        fn token_metadata(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> TokenMetadata {
            let packed = unpack_token_id(token_id);
            let mutable_state = self.token_mutable_state.entry(token_id).read();
            to_token_metadata(packed, mutable_state)
        }

        fn is_playable(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            let metadata = self.token_metadata(token_id);
            let current_time = get_block_timestamp();
            token_state::is_token_playable(@metadata, current_time)
        }

        fn settings_id(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            crate::token::structs::unpack_settings_id(token_id)
        }

        fn player_name(self: @ComponentState<TContractState>, token_id: felt252) -> felt252 {
            self.token_player_names.entry(token_id).read()
        }

        fn objective_id(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            unpack_objective_id(token_id)
        }

        fn token_mutable_state(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> TokenMutableState {
            self.token_mutable_state.entry(token_id).read()
        }

        fn minted_by(self: @ComponentState<TContractState>, token_id: felt252) -> felt252 {
            let minted_by_val: u64 = unpack_minted_by(token_id);
            minted_by_val.into()
        }

        fn game_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.game_address.read()
        }

        fn game_registry_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.game_registry_address.read()
        }

        fn is_soulbound(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            unpack_soulbound(token_id)
        }

        fn renderer_address(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> ContractAddress {
            let contract_self = self.get_contract();
            let renderer = RendererOpt::get_token_renderer(contract_self, token_id);
            match renderer {
                Option::Some(addr) => addr,
                Option::None => {
                    let game_id = unpack_game_id(token_id);
                    if game_id == 0 {
                        // Single game token
                        self.game_address.read()
                    } else {
                        let game_registry_dispatcher = IMinigameRegistryDispatcher {
                            contract_address: self.game_registry_address.read(),
                        };
                        let game_metadata = game_registry_dispatcher.game_metadata(game_id.into());
                        let game_renderer_address = game_metadata.renderer_address;
                        if !game_renderer_address.is_zero() {
                            game_renderer_address
                        } else {
                            self.token_game_address(token_id)
                        }
                    }
                },
            }
        }

        fn token_game_address(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> ContractAddress {
            let game_id = unpack_game_id(token_id);
            self.resolve_game_address(game_id.into())
        }

        // Batch view functions - all panic if token_ids array is empty
        fn token_metadata_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<TokenMetadata> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut results: Array<TokenMetadata> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(i);
                results.append(self.token_metadata(token_id));
                i += 1;
            }
            results
        }

        fn is_playable_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<bool> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut results: Array<bool> = ArrayTrait::new();
            let current_time = get_block_timestamp();
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(i);
                let metadata = self.token_metadata(token_id);
                results.append(token_state::is_token_playable(@metadata, current_time));
                i += 1;
            }
            results
        }

        fn settings_id_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<u32> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut results: Array<u32> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(crate::token::structs::unpack_settings_id(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn player_name_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<felt252> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut results: Array<felt252> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(i);
                results.append(self.token_player_names.entry(token_id).read());
                i += 1;
            }
            results
        }

        fn objective_id_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<u32> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut results: Array<u32> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(unpack_objective_id(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn token_mutable_state_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<TokenMutableState> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut results: Array<TokenMutableState> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(i);
                results.append(self.token_mutable_state.entry(token_id).read());
                i += 1;
            }
            results
        }

        fn minted_by_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<felt252> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut results: Array<felt252> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                let minted_by_val: u64 = unpack_minted_by(*token_ids.at(i));
                results.append(minted_by_val.into());
                i += 1;
            }
            results
        }

        fn is_soulbound_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<bool> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut results: Array<bool> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(unpack_soulbound(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn renderer_address_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut results: Array<ContractAddress> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(i);
                results.append(self.renderer_address(token_id));
                i += 1;
            }
            results
        }

        fn token_game_address_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut results: Array<ContractAddress> = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(i);
                results.append(self.token_game_address(token_id));
                i += 1;
            }
            results
        }

        fn token_full_state_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<TokenFullState> {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let current_time = get_block_timestamp();
            let contract = self.get_contract();
            let erc721_component = ERC721::get_component(contract);

            // Cache: (game_id, resolved_address) to avoid redundant registry lookups
            let mut game_cache: Array<(u32, ContractAddress)> = array![];
            let mut results: Array<TokenFullState> = ArrayTrait::new();

            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(i);

                // Local unpack + mutable state read (no cross-contract dispatch)
                let packed = unpack_token_id(token_id);
                let mutable_state = self.token_mutable_state.entry(token_id).read();
                let metadata = to_token_metadata(packed, mutable_state);

                // Local storage reads (same contract, no dispatch)
                let player_name = self.token_player_names.entry(token_id).read();

                // Internal ERC721 component access (no dispatch)
                let owner = erc721_component._owner_of(token_id.into());

                // Compute is_playable locally (pure math)
                let is_playable = token_state::is_token_playable(@metadata, current_time);

                // Resolve game_address with cache (1 registry dispatch per unique game_id)
                let game_address = self
                    ._resolve_game_address_cached(packed.game_id, ref game_cache);

                results
                    .append(
                        TokenFullState {
                            token_id,
                            owner,
                            player_name,
                            is_playable,
                            game_address,
                            game_over: mutable_state.game_over,
                            completed_objective: mutable_state.completed_objective,
                            lifecycle: metadata.lifecycle,
                        },
                    );
                i += 1;
            };

            results
        }

        fn mint(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
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
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> felt252 {
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
                    paymaster,
                    salt,
                    metadata,
                )
        }

        /// Batch mint with full per-token parameters.
        fn mint_batch(
            ref self: ComponentState<TContractState>, mut mints: Array<MintParams>,
        ) -> Array<felt252> {
            assert!(mints.len() > 0, "MinigameToken: mints array cannot be empty");
            let mut token_ids: Array<felt252> = ArrayTrait::new();
            loop {
                match mints.pop_front() {
                    Option::Some(params) => {
                        let token_id = self
                            .mint_game(
                                params.game_address,
                                params.player_name,
                                params.settings_id,
                                params.start,
                                params.end,
                                params.objective_id,
                                params.context,
                                params.client_url,
                                params.renderer_address,
                                params.to,
                                params.soulbound,
                                params.paymaster,
                                params.salt,
                                params.metadata,
                            );
                        token_ids.append(token_id);
                    },
                    Option::None => { break; },
                }
            }
            token_ids
        }

        /// Batch mint identical tokens to multiple recipients with auto-incrementing salt.
        fn mint_batch_recipients(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            mut recipients: Array<ContractAddress>,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> Array<felt252> {
            let count = recipients.len();
            assert!(count > 0, "MinigameToken: recipients array cannot be empty");
            // Ensure salt won't overflow u16 during auto-increment
            let max_salt: u32 = salt.into() + count - 1;
            assert!(
                max_salt <= 0xFFFF, "MinigameToken: salt overflow, reduce base salt or recipients",
            );

            let mut token_ids: Array<felt252> = ArrayTrait::new();
            let mut index: u16 = 0;
            loop {
                match recipients.pop_front() {
                    Option::Some(to) => {
                        let current_salt = salt + index;
                        let ctx = match @context {
                            Option::Some(c) => Option::Some(c.clone()),
                            Option::None => Option::None,
                        };
                        let url = match @client_url {
                            Option::Some(u) => Option::Some(u.clone()),
                            Option::None => Option::None,
                        };
                        let token_id = self
                            .mint_game(
                                game_address,
                                player_name,
                                settings_id,
                                start,
                                end,
                                objective_id,
                                ctx,
                                url,
                                renderer_address,
                                to,
                                soulbound,
                                paymaster,
                                current_salt,
                                metadata,
                            );
                        token_ids.append(token_id);
                        index += 1;
                    },
                    Option::None => { break; },
                }
            }
            token_ids
        }

        fn update_game(ref self: ComponentState<TContractState>, token_id: felt252) {
            // Validate token exists
            let mut contract = self.get_contract_mut();
            let mut erc721_component = ERC721::get_component_mut(ref contract);
            assert!(
                erc721_component.exists(token_id.into()),
                "MinigameToken: Token {} does not exist",
                token_id,
            );

            let game_id = unpack_game_id(token_id);
            let game_address = self.resolve_game_address(game_id.into());

            // Validate game address supports required interfaces
            let game_src5_dispatcher = ISRC5Dispatcher { contract_address: game_address };
            assert!(
                game_src5_dispatcher.supports_interface(IMINIGAME_ID),
                "MinigameToken: Game does not support IMinigame interface",
            );

            // Read mutable state
            let mutable_state = self.token_mutable_state.entry(token_id).read();

            // Check objective completion if token has an objective
            let obj_id = unpack_objective_id(token_id);
            let completed_objective = if obj_id != 0 {
                let contract_ref = self.get_contract();
                ObjectivesOpt::is_objective_completed(contract_ref, game_address, token_id, obj_id)
            } else {
                mutable_state.completed_objective
            };

            // Get current game state
            let minigame_token_data_dispatcher = IMinigameTokenDataDispatcher {
                contract_address: game_address,
            };

            let game_over = minigame_token_data_dispatcher.game_over(token_id);
            let score = minigame_token_data_dispatcher.score(token_id);

            // Emit score update event
            self.emit(ScoreUpdate { token_id, score });

            // Ensure game_over and completed_objective can only transition from false to true
            let final_game_over = token_state::ensure_game_over_transition(
                mutable_state.game_over, game_over,
            );
            let final_completed_objective = token_state::ensure_objectives_completion_transition(
                mutable_state.completed_objective, completed_objective,
            );

            // Track state transitions for callbacks and events
            let game_over_transition = final_game_over && !mutable_state.game_over;
            let objective_complete_transition = final_completed_objective
                && !mutable_state.completed_objective;

            // Emit new events on transitions
            if game_over_transition {
                self.emit(GameOver { token_id, score });
            }
            if objective_complete_transition {
                self.emit(CompletedObjective { token_id });
            }

            // Update mutable state if changed
            if final_completed_objective != mutable_state.completed_objective
                || final_game_over != mutable_state.game_over {
                let updated_state = TokenMutableState {
                    game_over: final_game_over, completed_objective: final_completed_objective,
                };
                self.token_mutable_state.entry(token_id).write(updated_state);
            }

            // Always emit metadata update
            self.emit_metadata_update(token_id.into());

            // =================================================================
            // METAGAME CALLBACKS - Notify minter contract of state changes
            // =================================================================
            let minted_by = unpack_minted_by(token_id);
            let contract_ref = self.get_contract();
            let minter_address = MinterOpt::get_minter_address(contract_ref, minted_by);

            if !minter_address.is_zero() {
                // Safe SRC5 check using call_contract_syscall
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

                    // Always notify game action
                    callback.on_game_action(token_id.into(), score);

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
            ref self: ComponentState<TContractState>, token_id: felt252, name: felt252,
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

        // Batch write functions
        fn update_game_batch(ref self: ComponentState<TContractState>, token_ids: Span<felt252>) {
            assert!(token_ids.len() > 0, "MinigameToken: token_ids array cannot be empty");
            let mut i: u32 = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(i);
                self.update_game(token_id);
                i += 1;
            };
        }

        fn update_player_name_batch(
            ref self: ComponentState<TContractState>, updates: Span<PlayerNameUpdate>,
        ) {
            assert!(updates.len() > 0, "MinigameToken: updates array cannot be empty");
            let mut i: u32 = 0;
            loop {
                if i >= updates.len() {
                    break;
                }
                let update = *updates.at(i);
                self.update_player_name(update.token_id, update.name);
                i += 1;
            };
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl ERC2981: ERC2981Component::HasComponent<TContractState>,
        impl MinterOpt: OptionalMinter<TContractState>,
        impl ContextOpt: OptionalContext<TContractState>,
        impl ObjectivesOpt: OptionalObjectives<TContractState>,
        impl SettingsOpt: OptionalSettings<TContractState>,
        impl RendererOpt: OptionalRenderer<TContractState>,
        +Drop<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +ERC2981Component::ImmutableConfig,
    > of InternalTrait<TContractState> {
        /// Initializes the CoreTokenComponent.
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

        fn mint_game(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
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
            paymaster: bool,
            salt: u16,
            metadata_val: u16,
        ) -> felt252 {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Validate lifecycle parameters
            let lifecycle = token_state::create_lifecycle_with_defaults(start, end);
            lifecycle.validate();

            // Compute delays relative to current time
            let start_delay: u32 = if lifecycle.start > current_time {
                (lifecycle.start - current_time).try_into().unwrap()
            } else {
                0
            };
            let end_delay: u32 = if lifecycle.end > 0 && lifecycle.end > lifecycle.start {
                (lifecycle.end - lifecycle.start).try_into().unwrap()
            } else {
                0
            };

            // Get tx_hash bits for collision protection
            let tx_info = get_tx_info().unbox();
            let tx_hash_bits = extract_tx_hash_bits(tx_info.transaction_hash);

            // Full game token with validation and setup
            let (final_game_address, game_id) = self
                .validate_and_process_game_address(game_address);

            let mut contract = self.get_contract();
            let mut contract_self = self.get_contract_mut();
            // Validate settings if provided
            let validated_settings_id = match settings_id {
                Option::Some(sid) => {
                    SettingsOpt::validate_settings(contract, final_game_address, sid);
                    sid
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

            // Handle minter tracking if enabled
            let minted_by = MinterOpt::add_minter(ref contract_self, caller);

            // Determine has_context before packing to avoid double-pack
            let has_context = context.is_some();

            // Pack token ID with correct has_context from the start
            let final_token_id = pack_token_id(
                game_id.try_into().unwrap(),
                minted_by,
                validated_settings_id,
                current_time,
                start_delay,
                end_delay,
                validated_objective_id,
                soulbound,
                has_context,
                paymaster,
                tx_hash_bits,
                salt,
                metadata_val,
            );

            // Emit context event with the final token_id
            if let Option::Some(ctx) = context {
                ContextOpt::emit_context(ref contract_self, caller, final_token_id, ctx);
            }

            // Handle renderer if provided
            match renderer_address {
                Option::Some(raddr) => {
                    RendererOpt::set_token_renderer(ref contract_self, final_token_id, raddr);
                },
                Option::None => {},
            }

            // No need to write token_metadata or token_mutable_state —
            // immutable data is in the token_id, mutable state defaults to zero

            // Set player name if provided
            if let Option::Some(name) = player_name {
                self.token_player_names.entry(final_token_id).write(name);
                self.emit_token_player_name_update(final_token_id, name);
            }

            // Set client url if provided
            if let Option::Some(url) = client_url {
                self.token_client_url.entry(final_token_id).write(url.clone());
                self.emit_token_client_url_update(final_token_id, url);
            }

            // Mint the ERC721 token
            let mut contract = self.get_contract_mut();
            let mut erc721_component = ERC721::get_component_mut(ref contract);
            erc721_component.mint(to, final_token_id.into());

            final_token_id
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

        fn _resolve_game_address_cached(
            self: @ComponentState<TContractState>,
            game_id: u32,
            ref cache: Array<(u32, ContractAddress)>,
        ) -> ContractAddress {
            // Scan cache for existing entry
            let mut j: u32 = 0;
            let found: Option<ContractAddress> = loop {
                if j >= cache.len() {
                    break Option::None;
                }
                let (cached_id, cached_addr) = *cache.at(j);
                if cached_id == game_id {
                    break Option::Some(cached_addr);
                }
                j += 1;
            };
            match found {
                Option::Some(addr) => addr,
                Option::None => {
                    let address = self.resolve_game_address(game_id.into());
                    cache.append((game_id, address));
                    address
                },
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

        fn assert_token_ownership(self: @ComponentState<TContractState>, token_id: felt252) {
            let contract = self.get_contract();
            let erc721_component = ERC721::get_component(contract);
            let token_owner = erc721_component._owner_of(token_id.into());
            let caller = get_caller_address();
            assert!(token_owner == caller, "MinigameToken: Caller is not owner of token");
        }

        fn assert_playable(self: @ComponentState<TContractState>, token_id: felt252) {
            let metadata = CoreToken::token_metadata(self, token_id);
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

        fn emit_token_player_name_update(
            ref self: ComponentState<TContractState>, id: felt252, player_name: felt252,
        ) {
            self.emit(TokenPlayerNameUpdate { id, player_name });
        }

        fn emit_token_client_url_update(
            ref self: ComponentState<TContractState>, id: felt252, client_url: ByteArray,
        ) {
            self.emit(TokenClientUrlUpdate { id, client_url });
        }

        fn emit_metadata_update(ref self: ComponentState<TContractState>, token_id: u256) {
            self.emit(MetadataUpdate { token_id });
        }
    }
}
