///
/// Game Component
///
#[starknet::component]
pub mod MinigameComponent {
    use crate::interface::{
        IMinigame, IMinigameTokenData, IMINIGAME_ID,
    };
    use crate::libs;
    use game_components_token::extensions::multi_game::interface::{
        IMINIGAME_TOKEN_MULTIGAME_ID, IMinigameTokenMultiGameDispatcher, IMinigameTokenMultiGameDispatcherTrait,
    };

    use starknet::{ContractAddress};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;

    #[storage]
    pub struct Storage {
        token_address: ContractAddress,
        settings_address: ContractAddress,
        objectives_address: ContractAddress,
    }

    #[embeddable_as(MinigameImpl)]
    impl Minigame<
        TContractState,
        +HasComponent<TContractState>,
        +IMinigameTokenData<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigame<ComponentState<TContractState>> {
        fn token_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.token_address.read()
        }

        fn settings_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.settings_address.read()
        }

        fn objectives_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.objectives_address.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
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
            settings_address: ContractAddress,
            objectives_address: ContractAddress,
            token_address: ContractAddress,
        ) {
            // Register base SRC5 interface
            self.register_game_interface();

            // Store the namespace, token address, and feature flags
            self.token_address.write(token_address.clone());

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            let supports_multi_game = src5_component.supports_interface(IMINIGAME_TOKEN_MULTIGAME_ID);
            if supports_multi_game {
                let minigame_token_multi_game_dispatcher = IMinigameTokenMultiGameDispatcher {
                    contract_address: token_address,
                };
                minigame_token_multi_game_dispatcher.register_game(
                    creator_address,
                    name,
                    description,
                    developer,
                    publisher,
                    genre,
                    image,
                    color,
                    client_url,
                    renderer_address,
                );
            }

            // Store the settings and objectives addresses
            self.settings_address.write(settings_address.clone());
            self.objectives_address.write(objectives_address.clone());
        }

        fn register_game_interface(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_ID);
        }

        fn pre_action(self: @ComponentState<TContractState>, token_id: u64) {
            libs::pre_action(self.token_address.read(), token_id);
        }

        fn post_action(self: @ComponentState<TContractState>, token_id: u64) {
            libs::post_action(self.token_address.read(), token_id);
        }

        fn get_player_name(self: @ComponentState<TContractState>, token_id: u64) -> ByteArray {
            libs::get_player_name(self.token_address.read(), token_id)
        }

        fn assert_token_ownership(self: @ComponentState<TContractState>, token_id: u64) {
            libs::assert_token_ownership(self.token_address.read(), token_id);
        }

        fn assert_game_token_playable(self: @ComponentState<TContractState>, token_id: u64) {
            libs::assert_game_token_playable(self.token_address.read(), token_id);
        }
    }
}
