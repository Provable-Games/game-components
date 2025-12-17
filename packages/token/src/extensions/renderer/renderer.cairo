#[starknet::component]
pub mod RendererComponent {
    use core::num::traits::Zero;
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use openzeppelin_token::erc721::ERC721Component::ERC721Impl;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::core::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
    use crate::core::traits::OptionalRenderer;
    use crate::extensions::renderer::interface::{
        IMINIGAME_TOKEN_RENDERER_ID, IMinigameTokenRenderer,
    };
    use crate::interface::{ITokenEventRelayerDispatcher, ITokenEventRelayerDispatcherTrait};
    use crate::libs::address_utils;

    #[storage]
    pub struct Storage {
        token_renderers: Map<u64, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenRendererUpdate: TokenRendererUpdate,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenRendererUpdate {
        token_id: u64,
        renderer: ContractAddress,
    }

    #[embeddable_as(RendererImpl)]
    pub impl Renderer<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IMinigameTokenRenderer<ComponentState<TContractState>> {
        fn get_renderer(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            self.token_renderers.entry(token_id).read()
        }

        fn has_custom_renderer(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let renderer = self.token_renderers.entry(token_id).read();
            address_utils::is_non_zero_address(renderer)
        }

        fn reset_token_renderer(ref self: ComponentState<TContractState>, token_id: u64) {
            // Get the contract address to check ownership
            let contract_address = get_contract_address();
            let erc721 = IERC721Dispatcher { contract_address };
            let token_owner = erc721.owner_of(token_id.into());
            let caller = get_caller_address();
            assert!(token_owner == caller, "MinigameToken: Caller is not owner of token");
            let zero_address: ContractAddress = 0.try_into().unwrap();
            self.token_renderers.entry(token_id).write(zero_address);

            let minigame_token_dispatcher = IMinigameTokenDispatcher { contract_address };
            let event_relayer_address = minigame_token_dispatcher.event_relayer_address();

            if !event_relayer_address.is_zero() {
                let relayer = ITokenEventRelayerDispatcher {
                    contract_address: event_relayer_address,
                };
                relayer.emit_token_renderer_update(token_id, zero_address);
            } else {
                self.emit(TokenRendererUpdate { token_id, renderer: zero_address });
            }
        }
    }

    // Implementation of the OptionalRenderer trait for integration with CoreTokenComponent
    pub impl RendererOptionalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of OptionalRenderer<TContractState> {
        fn get_token_renderer(self: @TContractState, token_id: u64) -> Option<ContractAddress> {
            let component = HasComponent::get_component(self);
            let renderer = component.token_renderers.entry(token_id).read();
            address_utils::address_to_option(renderer)
        }

        fn set_token_renderer(
            ref self: TContractState,
            token_id: u64,
            renderer: ContractAddress,
            event_relayer: Option<ITokenEventRelayerDispatcher>,
        ) {
            let mut component = HasComponent::get_component_mut(ref self);
            component.token_renderers.entry(token_id).write(renderer);

            match event_relayer {
                Option::Some(relayer) => relayer.emit_token_renderer_update(token_id, renderer),
                Option::None => component.emit(TokenRendererUpdate { token_id, renderer }),
            }
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_TOKEN_RENDERER_ID);
        }
    }
}
