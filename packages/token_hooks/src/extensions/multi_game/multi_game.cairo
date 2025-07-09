#[starknet::component]
pub mod MultiGameComponent {
    use crate::extensions::multi_game::structs::GameMetadata;
    use crate::extensions::multi_game::interface::{
        IMINIGAME_TOKEN_MULTIGAME_ID, IMinigameTokenMultiGame,
    };

    use game_components_minigame::interface::{
        IMINIGAME_ID, IMinigameDispatcher, IMinigameDispatcherTrait,
    };

    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;

    use crate::token::TokenComponent;

    #[storage]
    pub struct Storage {
        // Token-specific storage
        token_client_urls: Map<u64, ByteArray>,
        token_game_addresses: Map<u64, ContractAddress>,
        // Game registry storage
        game_count: u64,
        game_id_by_address: Map<ContractAddress, u64>,
        game_address_by_id: Map<u64, ContractAddress>,
        game_metadata: Map<u64, GameMetadata>,
        // Creator tokens
        game_creator_tokens: Map<u64, u64>, // game_id -> creator_token_id
        creator_token_counter: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        GameRegistered: GameRegistered,
        ClientUrlSet: ClientUrlSet,
        CreatorTokenMinted: CreatorTokenMinted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameRegistered {
        pub game_id: u64,
        pub contract_address: ContractAddress,
        pub name: ByteArray,
        pub creator_token_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ClientUrlSet {
        pub token_id: u64,
        pub client_url: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CreatorTokenMinted {
        pub game_id: u64,
        pub token_id: u64,
        pub creator_address: ContractAddress,
    }

    #[embeddable_as(MultiGameImpl)]
    impl MultiGame<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl Token: TokenComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameTokenMultiGame<ComponentState<TContractState>> {
        fn game_count(self: @ComponentState<TContractState>) -> u64 {
            self.game_count.read()
        }

        fn game_id_from_address(
            self: @ComponentState<TContractState>, contract_address: ContractAddress,
        ) -> u64 {
            self.game_id_by_address.entry(contract_address).read()
        }

        fn game_address_from_id(
            self: @ComponentState<TContractState>, game_id: u64,
        ) -> ContractAddress {
            self.game_address_by_id.entry(game_id).read()
        }

        fn game_metadata(self: @ComponentState<TContractState>, game_id: u64) -> GameMetadata {
            self.game_metadata.entry(game_id).read()
        }

        fn is_game_registered(
            self: @ComponentState<TContractState>, contract_address: ContractAddress,
        ) -> bool {
            let game_id = self.game_id_by_address.entry(contract_address).read();
            game_id != 0
        }

        fn game_address(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            self.token_game_addresses.entry(token_id).read()
        }

        fn creator_token_id(self: @ComponentState<TContractState>, game_id: u64) -> u64 {
            self.game_creator_tokens.entry(game_id).read()
        }

        fn client_url(self: @ComponentState<TContractState>, token_id: u64) -> ByteArray {
            self.token_client_urls.entry(token_id).read()
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
        ) -> u64 {
            let game_count = self.game_count.read();
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
            let game_address_display: felt252 = caller_address.into();
            assert!(
                existing_game_id == 0,
                "MultiGame: Game address {} already registered",
                game_address_display,
            );

            // Set up the game registry
            self.game_id_by_address.entry(caller_address).write(new_game_id);
            self.game_address_by_id.entry(new_game_id).write(caller_address);

            // Mint creator token
            let creator_token_id = self.mint_creator_token(new_game_id, creator_address);

            // Prepare optional fields
            let final_color = match color {
                Option::Some(color) => color,
                Option::None => "",
            };

            let final_client_url = match client_url {
                Option::Some(client_url) => client_url,
                Option::None => "",
            };

            let final_renderer_address = match renderer_address {
                Option::Some(renderer_address) => renderer_address,
                Option::None => starknet::contract_address_const::<0>(),
            };

            let minigame_dispatcher = IMinigameDispatcher { contract_address: caller_address };
            let settings_address = minigame_dispatcher.settings_address();
            let objectives_address = minigame_dispatcher.objectives_address();

            // Store game metadata
            let metadata = GameMetadata {
                creator_token_id,
                contract_address: caller_address,
                name: name.clone(),
                description,
                developer,
                publisher,
                genre,
                image,
                color: final_color,
                client_url: final_client_url,
                renderer_address: final_renderer_address,
                settings_address,
                objectives_address,
            };

            self.game_metadata.entry(new_game_id).write(metadata);
            self.game_count.write(new_game_id);

            self
                .emit(
                    GameRegistered {
                        game_id: new_game_id,
                        contract_address: caller_address,
                        name: name.clone(),
                        creator_token_id,
                    },
                );

            new_game_id
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl Token: TokenComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_TOKEN_MULTIGAME_ID);
        }

        fn mint_creator_token(
            ref self: ComponentState<TContractState>,
            game_id: u64,
            creator_address: ContractAddress,
        ) -> u64 {
            let current_counter = self.creator_token_counter.read();
            let creator_token_id = current_counter + 1;

            self.creator_token_counter.write(creator_token_id);
            self.game_creator_tokens.entry(game_id).write(creator_token_id);

            self.emit(CreatorTokenMinted { game_id, token_id: creator_token_id, creator_address });

            creator_token_id
        }

        fn set_token_client_url(
            ref self: ComponentState<TContractState>, token_id: u64, client_url: ByteArray,
        ) {
            self.token_client_urls.entry(token_id).write(client_url.clone());
            self.emit(ClientUrlSet { token_id, client_url });
        }

        fn set_token_game_address(
            ref self: ComponentState<TContractState>, token_id: u64, game_address: ContractAddress,
        ) {
            self.token_game_addresses.entry(token_id).write(game_address);
        }

        fn _set_client_url_if_provided(
            ref self: ComponentState<TContractState>, token_id: u64, client_url: Option<ByteArray>,
        ) {
            if let Option::Some(url) = client_url {
                self.set_token_client_url(token_id, url);
            }
        }

        fn get_game_count(self: @ComponentState<TContractState>) -> u64 {
            self.game_count.read()
        }

        fn get_game_id_from_address(
            self: @ComponentState<TContractState>, contract_address: ContractAddress,
        ) -> u64 {
            self.game_id_by_address.entry(contract_address).read()
        }

        fn get_game_address_from_id(
            self: @ComponentState<TContractState>, game_id: u64,
        ) -> ContractAddress {
            self.game_address_by_id.entry(game_id).read()
        }

        fn get_game_metadata(self: @ComponentState<TContractState>, game_id: u64) -> GameMetadata {
            self.game_metadata.entry(game_id).read()
        }

        fn get_is_game_registered(
            self: @ComponentState<TContractState>, contract_address: ContractAddress,
        ) -> bool {
            let game_id = self.game_id_by_address.entry(contract_address).read();
            game_id != 0
        }

        fn get_game_address(
            self: @ComponentState<TContractState>, token_id: u64,
        ) -> ContractAddress {
            self.token_game_addresses.entry(token_id).read()
        }

        fn get_creator_token_id(self: @ComponentState<TContractState>, game_id: u64) -> u64 {
            self.game_creator_tokens.entry(game_id).read()
        }

        fn get_client_url(self: @ComponentState<TContractState>, token_id: u64) -> ByteArray {
            self.token_client_urls.entry(token_id).read()
        }
    }
}
