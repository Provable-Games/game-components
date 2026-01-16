// Re-export from the registry package
pub use game_components_registry::interface::{
    GameMetadata, IMINIGAME_REGISTRY_ID, IMinigameRegistry,
};

#[starknet::contract]
pub mod MinigameRegistryContract {
    use core::num::traits::Zero;
    use game_components_minigame::interface::IMINIGAME_ID;
    use game_components_token::interface::{
        ITokenEventRelayerDispatcher, ITokenEventRelayerDispatcherTrait,
    };
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    // use crate::extensions::multi_game::interface::{IMinigameTokenMultiGame};
    use super::GameMetadata;
    use super::{IMINIGAME_REGISTRY_ID, IMinigameRegistry};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721 Mixin (includes SRC5 support)
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // SRC5 Internal implementation (not exposed in ABI to avoid conflict)
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Game registry storage
        game_counter: u64,
        game_id_by_address: Map<ContractAddress, u64>,
        game_metadata: Map<u64, GameMetadata>,
        // Event relayer storage
        event_relayer_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        GameMetadataUpdate: GameMetadataUpdate,
        GameRegistryUpdate: GameRegistryUpdate,
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
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameRegistryUpdate {
        #[key]
        pub id: u64,
        pub contract_address: ContractAddress,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        event_relayer_address: Option<ContractAddress>,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.src5.register_interface(IMINIGAME_REGISTRY_ID);

        // Store the event relayer address
        if let Option::Some(relayer) = event_relayer_address {
            self.event_relayer_address.write(relayer);
        }
    }

    #[abi(embed_v0)]
    impl MultiGameImpl of IMinigameRegistry<ContractState> {
        fn game_count(self: @ContractState) -> u64 {
            self.game_counter.read()
        }

        fn game_id_from_address(self: @ContractState, contract_address: ContractAddress) -> u64 {
            self.game_id_by_address.entry(contract_address).read()
        }

        fn game_address_from_id(self: @ContractState, game_id: u64) -> ContractAddress {
            self.game_metadata.entry(game_id).read().contract_address
        }

        fn game_metadata(self: @ContractState, game_id: u64) -> GameMetadata {
            self.game_metadata.entry(game_id).read()
        }

        fn is_game_registered(self: @ContractState, contract_address: ContractAddress) -> bool {
            self.game_id_by_address.entry(contract_address).read() != 0
        }

        fn register_game(
            ref self: ContractState,
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
        ) -> u64 {
            let game_count = self.game_counter.read();
            let new_game_id = game_count + 1;
            let caller_address = get_caller_address();

            // Check that caller implements IMINIGAME_ID
            let src5_dispatcher = ISRC5Dispatcher { contract_address: caller_address };
            assert!(
                src5_dispatcher.supports_interface(IMINIGAME_ID),
                "MultiGame: Caller does not implement IMinigame",
            );

            // Check the game is not already registered
            let existing_game_id = self.game_id_by_address.entry(caller_address).read();
            assert!(existing_game_id == 0, "MultiGame: Game already registered");

            // Set up the game registry
            self.game_id_by_address.entry(caller_address).write(new_game_id);

            // Emit relayer event for game ID mapping
            match self.get_event_relayer() {
                Option::Some(relayer) => relayer
                    .emit_game_registry_update(new_game_id, caller_address),
                Option::None => self
                    .emit(GameRegistryUpdate { id: new_game_id, contract_address: caller_address }),
            }

            // Mint creator token
            self.mint_creator_token(new_game_id, creator_address);

            // Prepare optional fields
            let final_color = match color {
                Option::Some(color) => color,
                Option::None => "",
            };

            let final_client_url = match client_url {
                Option::Some(client_url) => client_url,
                Option::None => "",
            };

            let final_renderer_address: ContractAddress = match renderer_address {
                Option::Some(renderer_address) => renderer_address,
                Option::None => 0.try_into().unwrap(),
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
            };

            self.game_metadata.entry(new_game_id).write(metadata);
            self.game_counter.write(new_game_id);

            // Emit events
            match self.get_event_relayer() {
                Option::Some(relayer) => relayer
                    .emit_game_metadata_update(
                        new_game_id,
                        caller_address,
                        name.clone(),
                        description,
                        developer,
                        publisher,
                        genre,
                        image,
                        final_color.clone(),
                        final_client_url.clone(),
                        final_renderer_address,
                    ),
                Option::None => self
                    .emit(
                        GameMetadataUpdate {
                            id: new_game_id,
                            contract_address: caller_address,
                            name: name.clone(),
                            description,
                            developer,
                            publisher,
                            genre,
                            image,
                            color: final_color.clone(),
                            client_url: final_client_url.clone(),
                            renderer_address: final_renderer_address,
                        },
                    ),
            }

            new_game_id
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn mint_creator_token(
            ref self: ContractState, game_id: u64, creator_address: ContractAddress,
        ) {
            // Mint the ERC721 token to the creator
            self.erc721.mint(creator_address, game_id.into());
        }

        fn get_event_relayer(self: @ContractState) -> Option<ITokenEventRelayerDispatcher> {
            let event_relayer_address = self.event_relayer_address.read();
            if !event_relayer_address.is_zero() {
                Option::Some(
                    ITokenEventRelayerDispatcher { contract_address: event_relayer_address },
                )
            } else {
                Option::None
            }
        }
    }
}
