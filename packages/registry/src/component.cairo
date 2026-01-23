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
    use game_components_minigame::interface::IMINIGAME_ID;
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalImpl as SRC5InternalImpl;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::interface::{GameMetadata, IMINIGAME_REGISTRY_ID, IMinigameRegistry};

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

    // ==========================================================================
    // ERRORS
    // ==========================================================================

    pub mod Errors {
        pub const CALLER_NOT_MINIGAME: felt252 = 'Registry: not IMinigame';
        pub const GAME_ALREADY_REGISTERED: felt252 = 'Registry: already registered';
        pub const NOT_GAME_OWNER: felt252 = 'Registry: not game owner';
        pub const INVALID_GAME_ID: felt252 = 'Registry: invalid game id';
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
            self.game_id_by_address.entry(contract_address).read() != 0
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

            // Prepare optional fields
            let final_color = match color {
                Option::Some(c) => c,
                Option::None => "",
            };

            let final_client_url = match client_url {
                Option::Some(url) => url,
                Option::None => "",
            };

            let final_renderer_address: ContractAddress = match renderer_address {
                Option::Some(addr) => addr,
                Option::None => 0.try_into().unwrap(),
            };

            let final_royalty_fraction: u128 = match royalty_fraction {
                Option::Some(fraction) => fraction,
                Option::None => 0,
            };

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
                    },
                );

            // Call hook for after registration (e.g., mint creator token)
            let mut contract = self.get_contract_mut();
            MinigameRegistryHooksTrait::after_register_game(
                ref contract, new_game_id, creator_address,
            );

            new_game_id
        }

        fn set_game_royalty(
            ref self: ComponentState<TContractState>, game_id: u64, royalty_fraction: u128,
        ) {
            // Validate game_id exists
            let game_count = self.game_counter.read();
            assert!(game_id > 0 && game_id <= game_count, "{}", Errors::INVALID_GAME_ID);

            // Check caller owns the game creator token (game_id)
            // Call owner_of on this contract to check token ownership
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

            // Update the royalty_fraction in game metadata
            let mut metadata = self.game_metadata.entry(game_id).read();
            metadata.royalty_fraction = royalty_fraction;
            self.game_metadata.entry(game_id).write(metadata);

            // Emit royalty update event
            self.emit(GameRoyaltyUpdate { game_id, royalty_fraction });
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
        /// Initializes the component by registering the SRC5 interface.
        /// Should be called in the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_REGISTRY_ID);
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
}
