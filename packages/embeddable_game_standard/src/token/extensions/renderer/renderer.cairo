#[starknet::component]
pub mod RendererComponent {
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
    use crate::token::core::traits::OptionalRenderer;
    use crate::token::extensions::renderer::interface::{
        IMINIGAME_TOKEN_RENDERER_ID, IMinigameTokenRenderer,
    };
    use crate::token::libs::address_utils;

    #[storage]
    pub struct Storage {
        token_renderers: Map<felt252, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenRendererUpdate: TokenRendererUpdate,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenRendererUpdate {
        #[key]
        pub token_id: felt252,
        pub renderer: ContractAddress,
    }

    #[embeddable_as(RendererImpl)]
    pub impl Renderer<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IMinigameTokenRenderer<ComponentState<TContractState>> {
        fn get_renderer(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> ContractAddress {
            self.token_renderers.entry(token_id).read()
        }

        fn has_custom_renderer(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            let renderer = self.token_renderers.entry(token_id).read();
            address_utils::is_non_zero_address(renderer)
        }

        fn reset_token_renderer(ref self: ComponentState<TContractState>, token_id: felt252) {
            // Get the contract address to check ownership
            let contract_address = get_contract_address();
            let erc721 = IERC721Dispatcher { contract_address };
            let token_owner = erc721.owner_of(token_id.into());
            let caller = get_caller_address();
            assert!(token_owner == caller, "MinigameToken: Caller is not owner of token");
            let zero_address: ContractAddress = 0.try_into().unwrap();
            self.token_renderers.entry(token_id).write(zero_address);

            // Emit native event
            self.emit(TokenRendererUpdate { token_id, renderer: zero_address });
        }

        fn reset_token_renderer_batch(
            ref self: ComponentState<TContractState>, token_ids: Span<felt252>,
        ) {
            let mut index = 0;
            loop {
                if index >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(index);
                self.reset_token_renderer(token_id);
                index += 1;
            }
        }

        fn get_renderer_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            let mut results = array![];
            let mut index = 0;

            loop {
                if index >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(index);
                let renderer = self.get_renderer(token_id);
                results.append(renderer);
                index += 1;
            }

            results
        }
    }

    // Implementation of the OptionalRenderer trait for integration with CoreTokenComponent
    pub impl RendererOptionalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of OptionalRenderer<TContractState> {
        fn get_token_renderer(self: @TContractState, token_id: felt252) -> Option<ContractAddress> {
            let component = HasComponent::get_component(self);
            let renderer = component.token_renderers.entry(token_id).read();
            address_utils::address_to_option(renderer)
        }

        fn set_token_renderer(
            ref self: TContractState, token_id: felt252, renderer: ContractAddress,
        ) {
            let mut component = HasComponent::get_component_mut(ref self);
            component.token_renderers.entry(token_id).write(renderer);

            // Emit native event
            component.emit(TokenRendererUpdate { token_id, renderer });
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
