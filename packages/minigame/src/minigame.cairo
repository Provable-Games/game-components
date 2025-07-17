///
/// Game Component
///
#[starknet::component]
pub mod MinigameComponent {
    use core::num::traits::Zero;
    use crate::interface::{IMinigame, IMinigameTokenData, IMINIGAME_ID};
    use crate::libs;
    use game_components_token::core::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait, IMINIGAME_TOKEN_ID,
    };
    use game_components_token::examples::minigame_registry_contract::{
        IMINIGAME_REGISTRY_ID, IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
    };
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use starknet::{ContractAddress, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

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

        fn mint_game(
            self: @ComponentState<TContractState>,
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
            libs::mint(
                self.token_address.read(),
                get_contract_address(),
                player_name,
                settings_id,
                start,
                end,
                objective_ids,
                context,
                client_url,
                renderer_address,
                to,
                soulbound,
            )
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
            settings_address: Option<ContractAddress>,
            objectives_address: Option<ContractAddress>,
            token_address: ContractAddress,
        ) {
            // Register base SRC5 interface
            self.register_game_interface();

            // Store the namespace, token address, and feature flags
            self.token_address.write(token_address.clone());

            let token_src5_dispatcher = ISRC5Dispatcher { contract_address: token_address };
            let supports_minigame_token = token_src5_dispatcher
                .supports_interface(IMINIGAME_TOKEN_ID);
            assert!(supports_minigame_token, "Minigame: Token does not support IMINIGAME_TOKEN_ID");
            let minigame_token_dispatcher = IMinigameTokenDispatcher {
                contract_address: token_address,
            };
            let minigame_registry_address = minigame_token_dispatcher.game_registry_address();
            if !minigame_registry_address.is_zero() {
                let minigame_registry_src5_dispatcher = ISRC5Dispatcher {
                    contract_address: minigame_registry_address,
                };
                let supports_minigame_registry = minigame_registry_src5_dispatcher
                    .supports_interface(IMINIGAME_REGISTRY_ID);
                if supports_minigame_registry {
                    let minigame_registry_dispatcher = IMinigameRegistryDispatcher {
                        contract_address: minigame_registry_address,
                    };
                    minigame_registry_dispatcher
                        .register_game(
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
            }

            // Store the settings and objectives addresses
            if let Option::Some(settings_address) = settings_address {
                self.settings_address.write(settings_address);
            }
            if let Option::Some(objectives_address) = objectives_address {
                self.objectives_address.write(objectives_address);
            }
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
