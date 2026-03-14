// ==============================================================================
// MINIGAME REGISTRY COMPONENT
// ==============================================================================
// A reusable component for registering and tracking minigames.
// This component handles game registration, metadata storage, and ID mapping.
// It does NOT include ERC721 functionality - that should be added by the contract
// if creator tokens are desired.

use starknet::ContractAddress;

#[starknet::component]
pub mod MinigameRegistryComponent {
    use game_components_embeddable_game_standard::minigame::interface::IMINIGAME_ID;
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalImpl as SRC5InternalImpl;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::registry::interface::{
        DEFAULT_GAME_FEE_BPS, GameFeeInfo, GameMetadata, IMINIGAME_REGISTRY_ID, IMinigameRegistry,
        default_license,
    };
    use crate::registry::registry::registry::{
        Errors, apply_metadata_defaults, assert_valid_fee_numerator,
    };
    use crate::registry::registry_store::{RegistryStoreImpl, RegistryStoreTrait};
    use crate::registry::store::Store;

    // ==========================================================================
    // STORAGE
    // ==========================================================================

    #[storage]
    pub struct Storage {
        /// Counter for total number of registered games
        game_counter: u64,
        /// Mapping from game contract address to game ID
        game_id_by_address: Map<ContractAddress, u64>,
        /// Mapping from game ID to game metadata
        game_metadata: Map<u64, GameMetadata>,
        /// Default game fee info (license + fee) for all games
        default_game_fee_info: GameFeeInfo,
        /// Per-game fee info overrides (set by game creator)
        game_fee_info: Map<u64, GameFeeInfo>,
    }

    // ==========================================================================
    // EVENTS
    // ==========================================================================

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        GameMetadataUpdate: GameMetadataUpdate,
        GameRegistryUpdate: GameRegistryUpdate,
        GameRoyaltyUpdate: GameRoyaltyUpdate,
        GameFeeUpdate: GameFeeUpdate,
        DefaultGameFeeUpdate: DefaultGameFeeUpdate,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameMetadataUpdate {
        #[key]
        pub id: u64,
        pub contract_address: ContractAddress,
        pub name: ByteArray,
        pub description: ByteArray,
        pub developer: ByteArray,
        pub publisher: ByteArray,
        pub genre: ByteArray,
        pub image: ByteArray,
        pub color: ByteArray,
        pub client_url: ByteArray,
        pub renderer_address: ContractAddress,
        pub royalty_fraction: u128,
        pub skills_address: ContractAddress,
        pub version: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameRegistryUpdate {
        #[key]
        pub id: u64,
        pub contract_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameRoyaltyUpdate {
        #[key]
        pub game_id: u64,
        pub royalty_fraction: u128,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameFeeUpdate {
        #[key]
        pub game_id: u64,
        pub license: ByteArray,
        pub fee_numerator: u16,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DefaultGameFeeUpdate {
        pub license: ByteArray,
        pub fee_numerator: u16,
    }

    // ==========================================================================
    // STORE IMPLEMENTATION
    // ==========================================================================
    // Maps the generic Store<T> trait to the component's storage fields.

    impl ComponentStore<
        TContractState, +HasComponent<TContractState>,
    > of Store<ComponentState<TContractState>> {
        fn get_game_count(self: @ComponentState<TContractState>) -> u64 {
            self.game_counter.read()
        }

        fn set_game_count(ref self: ComponentState<TContractState>, count: u64) {
            self.game_counter.write(count);
        }

        fn get_game_id_by_address(
            self: @ComponentState<TContractState>, address: ContractAddress,
        ) -> u64 {
            self.game_id_by_address.entry(address).read()
        }

        fn set_game_id_by_address(
            ref self: ComponentState<TContractState>, address: ContractAddress, game_id: u64,
        ) {
            self.game_id_by_address.entry(address).write(game_id);
        }

        fn get_game_metadata(self: @ComponentState<TContractState>, game_id: u64) -> GameMetadata {
            self.game_metadata.entry(game_id).read()
        }

        fn set_game_metadata(
            ref self: ComponentState<TContractState>, game_id: u64, metadata: GameMetadata,
        ) {
            self.game_metadata.entry(game_id).write(metadata);
        }

        fn get_default_game_fee_info(self: @ComponentState<TContractState>) -> GameFeeInfo {
            self.default_game_fee_info.read()
        }

        fn set_default_game_fee_info(ref self: ComponentState<TContractState>, info: GameFeeInfo) {
            self.default_game_fee_info.write(info);
        }

        fn get_game_fee_info(self: @ComponentState<TContractState>, game_id: u64) -> GameFeeInfo {
            self.game_fee_info.entry(game_id).read()
        }

        fn set_game_fee_info(
            ref self: ComponentState<TContractState>, game_id: u64, info: GameFeeInfo,
        ) {
            self.game_fee_info.entry(game_id).write(info);
        }
    }

    // ==========================================================================
    // HOOKS TRAIT
    // ==========================================================================
    // Allows the embedding contract to hook into registration events
    // (e.g., for validation before or minting creator tokens after)

    pub trait MinigameRegistryHooksTrait<TContractState> {
        /// Called before a game is registered.
        /// Can be used for additional validation or access control.
        /// The caller_address is the game contract attempting to register.
        fn before_register_game(
            ref self: TContractState,
            caller_address: ContractAddress,
            creator_address: ContractAddress,
        );

        /// Called after a game is registered.
        /// Can be used to mint creator tokens or perform other post-registration logic.
        fn after_register_game(
            ref self: TContractState, game_id: u64, creator_address: ContractAddress,
        );

        /// Called to check if the caller is the registry owner/admin.
        /// Used for admin-only operations like set_default_game_fee.
        fn assert_registry_owner(self: @TContractState);
    }

    // ==========================================================================
    // EMBEDDABLE IMPLEMENTATION
    // ==========================================================================

    #[embeddable_as(MinigameRegistryImpl)]
    impl MinigameRegistry<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +MinigameRegistryHooksTrait<TContractState>,
    > of IMinigameRegistry<ComponentState<TContractState>> {
        fn game_count(self: @ComponentState<TContractState>) -> u64 {
            self.game_counter.read()
        }

        fn game_id_from_address(
            self: @ComponentState<TContractState>, contract_address: ContractAddress,
        ) -> u64 {
            self.game_id_by_address.entry(contract_address).read()
        }

        fn game_address_from_id(
            self: @ComponentState<TContractState>, game_id: u64,
        ) -> ContractAddress {
            self.game_metadata.entry(game_id).read().contract_address
        }

        fn game_metadata(self: @ComponentState<TContractState>, game_id: u64) -> GameMetadata {
            self.game_metadata.entry(game_id).read()
        }

        fn is_game_registered(
            self: @ComponentState<TContractState>, contract_address: ContractAddress,
        ) -> bool {
            RegistryStoreTrait::is_game_registered(self, contract_address)
        }

        fn register_game(
            ref self: ComponentState<TContractState>,
            creator_address: ContractAddress,
            name: ByteArray,
            description: ByteArray,
            developer: ByteArray,
            publisher: ByteArray,
            genre: ByteArray,
            image: ByteArray,
            color: Option<ByteArray>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            royalty_fraction: Option<u128>,
            skills_address: Option<ContractAddress>,
            version: u64,
            license: Option<ByteArray>,
            fee_numerator: Option<u16>,
        ) -> u64 {
            let game_count = self.game_counter.read();
            let new_game_id = game_count + 1;
            let caller_address = get_caller_address();

            // Check that caller implements IMINIGAME_ID
            let src5_dispatcher = ISRC5Dispatcher { contract_address: caller_address };
            assert!(
                src5_dispatcher.supports_interface(IMINIGAME_ID), "{}", Errors::CALLER_NOT_MINIGAME,
            );

            // Check the game is not already registered
            let existing_game_id = self.game_id_by_address.entry(caller_address).read();
            assert!(existing_game_id == 0, "{}", Errors::GAME_ALREADY_REGISTERED);

            // Call hook for before registration (e.g., additional validation)
            let mut contract = self.get_contract_mut();
            MinigameRegistryHooksTrait::before_register_game(
                ref contract, caller_address, creator_address,
            );

            // Set up the game registry
            self.game_id_by_address.entry(caller_address).write(new_game_id);

            // Emit native event for game ID mapping
            self.emit(GameRegistryUpdate { id: new_game_id, contract_address: caller_address });

            // Prepare optional fields using pure library
            let (
                final_color,
                final_client_url,
                final_renderer_address,
                final_royalty_fraction,
                final_skills_address,
            ) =
                apply_metadata_defaults(
                color, client_url, renderer_address, royalty_fraction, skills_address,
            );

            // Store game metadata
            let metadata = GameMetadata {
                contract_address: caller_address,
                name: name.clone(),
                description: description.clone(),
                developer: developer.clone(),
                publisher: publisher.clone(),
                genre: genre.clone(),
                image: image.clone(),
                color: final_color.clone(),
                client_url: final_client_url.clone(),
                renderer_address: final_renderer_address,
                royalty_fraction: final_royalty_fraction,
                skills_address: final_skills_address,
                created_at: get_block_timestamp(),
                version,
            };

            self.game_metadata.entry(new_game_id).write(metadata);
            self.game_counter.write(new_game_id);

            // Emit native event for metadata
            self
                .emit(
                    GameMetadataUpdate {
                        id: new_game_id,
                        contract_address: caller_address,
                        name,
                        description,
                        developer,
                        publisher,
                        genre,
                        image,
                        color: final_color,
                        client_url: final_client_url,
                        renderer_address: final_renderer_address,
                        royalty_fraction: final_royalty_fraction,
                        skills_address: final_skills_address,
                        version,
                    },
                );

            // Call hook for after registration (e.g., mint creator token)
            let mut contract = self.get_contract_mut();
            MinigameRegistryHooksTrait::after_register_game(
                ref contract, new_game_id, creator_address,
            );

            // Set per-game fee override if provided
            if let (Option::Some(lic), Option::Some(fee)) = (license, fee_numerator) {
                assert_valid_fee_numerator(fee);
                self
                    .game_fee_info
                    .entry(new_game_id)
                    .write(GameFeeInfo { license: lic.clone(), fee_numerator: fee });
                self.emit(GameFeeUpdate { game_id: new_game_id, license: lic, fee_numerator: fee });
            }

            new_game_id
        }

        fn set_game_royalty(
            ref self: ComponentState<TContractState>, game_id: u64, royalty_fraction: u128,
        ) {
            // Validate game_id exists
            let game_count = self.game_counter.read();
            assert!(game_id > 0 && game_id <= game_count, "{}", Errors::INVALID_GAME_ID);

            // Check caller owns the game creator token (game_id)
            self._assert_game_creator_token_owner(game_id);

            // Update the royalty_fraction in game metadata
            let mut metadata = self.game_metadata.entry(game_id).read();
            metadata.royalty_fraction = royalty_fraction;
            self.game_metadata.entry(game_id).write(metadata);

            // Emit royalty update event
            self.emit(GameRoyaltyUpdate { game_id, royalty_fraction });
        }

        fn skills_address(self: @ComponentState<TContractState>, game_id: u64) -> ContractAddress {
            self.game_metadata.entry(game_id).read().skills_address
        }

        fn game_metadata_batch(
            self: @ComponentState<TContractState>, game_ids: Span<u64>,
        ) -> Array<GameMetadata> {
            RegistryStoreTrait::game_metadata_batch(self, game_ids)
        }

        fn games_registered_batch(
            self: @ComponentState<TContractState>, addresses: Span<ContractAddress>,
        ) -> Array<bool> {
            RegistryStoreTrait::games_registered_batch(self, addresses)
        }

        fn get_games(
            self: @ComponentState<TContractState>, start: u64, count: u64,
        ) -> Array<GameMetadata> {
            RegistryStoreTrait::get_games(self, start, count)
        }

        fn get_games_by_developer(
            self: @ComponentState<TContractState>, developer: ByteArray, start: u64, count: u64,
        ) -> Array<GameMetadata> {
            RegistryStoreTrait::get_games_by_developer(self, developer, start, count)
        }

        fn get_games_by_publisher(
            self: @ComponentState<TContractState>, publisher: ByteArray, start: u64, count: u64,
        ) -> Array<GameMetadata> {
            RegistryStoreTrait::get_games_by_publisher(self, publisher, start, count)
        }

        fn get_games_by_genre(
            self: @ComponentState<TContractState>, genre: ByteArray, start: u64, count: u64,
        ) -> Array<GameMetadata> {
            RegistryStoreTrait::get_games_by_genre(self, genre, start, count)
        }

        fn game_fee_info(self: @ComponentState<TContractState>, game_id: u64) -> GameFeeInfo {
            let info = self.game_fee_info.entry(game_id).read();
            if info.fee_numerator == 0 && info.license.len() == 0 {
                self.default_game_fee_info.read()
            } else {
                info
            }
        }

        fn default_game_fee_info(self: @ComponentState<TContractState>) -> GameFeeInfo {
            self.default_game_fee_info.read()
        }

        fn set_default_game_fee(
            ref self: ComponentState<TContractState>, license: ByteArray, fee_numerator: u16,
        ) {
            // Admin-only via hook
            let contract = self.get_contract();
            MinigameRegistryHooksTrait::assert_registry_owner(contract);

            assert_valid_fee_numerator(fee_numerator);

            self
                .default_game_fee_info
                .write(GameFeeInfo { license: license.clone(), fee_numerator });

            self.emit(DefaultGameFeeUpdate { license, fee_numerator });
        }

        fn set_game_fee(
            ref self: ComponentState<TContractState>,
            game_id: u64,
            license: ByteArray,
            fee_numerator: u16,
        ) {
            // Validate game_id exists
            let game_count = self.game_counter.read();
            assert!(game_id > 0 && game_id <= game_count, "{}", Errors::INVALID_GAME_ID);

            // Check caller owns the game creator token
            self._assert_game_creator_token_owner(game_id);

            assert_valid_fee_numerator(fee_numerator);

            self
                .game_fee_info
                .entry(game_id)
                .write(GameFeeInfo { license: license.clone(), fee_numerator });

            self.emit(GameFeeUpdate { game_id, license, fee_numerator });
        }

        fn reset_game_fee(ref self: ComponentState<TContractState>, game_id: u64) {
            // Validate game_id exists
            let game_count = self.game_counter.read();
            assert!(game_id > 0 && game_id <= game_count, "{}", Errors::INVALID_GAME_ID);

            // Check caller owns the game creator token
            self._assert_game_creator_token_owner(game_id);

            // Write zero/empty to clear the override
            self.game_fee_info.entry(game_id).write(GameFeeInfo { license: "", fee_numerator: 0 });

            // Emit with default values to indicate reset
            let default_info = self.default_game_fee_info.read();
            self
                .emit(
                    GameFeeUpdate {
                        game_id,
                        license: default_info.license,
                        fee_numerator: default_info.fee_numerator,
                    },
                );
        }
    }

    // ==========================================================================
    // INTERNAL IMPLEMENTATION
    // ==========================================================================

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the component by registering the SRC5 interface
        /// and setting the default game fee.
        /// Should be called in the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_REGISTRY_ID);

            // Initialize default game fee
            self
                .default_game_fee_info
                .write(
                    GameFeeInfo { license: default_license(), fee_numerator: DEFAULT_GAME_FEE_BPS },
                );
        }
    }

    // ==========================================================================
    // PRIVATE HELPERS
    // ==========================================================================

    #[generate_trait]
    impl PrivateImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of PrivateTrait<TContractState> {
        /// Asserts that the caller owns the game creator token (ERC721 token with id = game_id)
        fn _assert_game_creator_token_owner(self: @ComponentState<TContractState>, game_id: u64) {
            let caller = get_caller_address();
            let contract_address = get_contract_address();
            let owner_of_selector = selector!("owner_of");
            let mut calldata = array![];
            let game_id_u256: u256 = game_id.into();
            calldata.append(game_id_u256.low.into());
            calldata.append(game_id_u256.high.into());

            let owner =
                match call_contract_syscall(contract_address, owner_of_selector, calldata.span()) {
                Result::Ok(result) => {
                    let mut result_span = result;
                    match Serde::<ContractAddress>::deserialize(ref result_span) {
                        Option::Some(addr) => addr,
                        Option::None => panic!("{}", Errors::NOT_GAME_OWNER),
                    }
                },
                Result::Err(_) => panic!("{}", Errors::NOT_GAME_OWNER),
            };

            assert!(caller == owner, "{}", Errors::NOT_GAME_OWNER);
        }
    }
}

// ==============================================================================
// EMPTY HOOKS IMPLEMENTATION
// ==============================================================================
// Provides a no-op implementation for contracts that don't need hooks

pub impl MinigameRegistryHooksEmptyImpl<
    TContractState,
> of MinigameRegistryComponent::MinigameRegistryHooksTrait<TContractState> {
    fn before_register_game(
        ref self: TContractState, caller_address: ContractAddress, creator_address: ContractAddress,
    ) { // No-op: contracts can override for additional validation
    }

    fn after_register_game(
        ref self: TContractState, game_id: u64, creator_address: ContractAddress,
    ) { // No-op: contracts can override to mint creator tokens
    }

    fn assert_registry_owner(
        self: @TContractState,
    ) { // No-op: contracts should override to implement ownership checks
    }
}
