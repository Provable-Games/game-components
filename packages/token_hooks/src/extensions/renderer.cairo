#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TokenRenderer {
    pub renderer_address: starknet::ContractAddress,
}

#[starknet::component]
pub mod TokenRendererComponent {
    use super::TokenRenderer;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};

    #[storage]
    pub struct Storage {
        token_renderers: Map<u64, TokenRenderer>,
        default_renderer: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RendererSet: RendererSet,
        DefaultRendererSet: DefaultRendererSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RendererSet {
        pub token_id: u64,
        pub renderer_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DefaultRendererSet {
        pub renderer_address: ContractAddress,
    }

    #[embeddable_as(TokenRendererImpl)]
    impl TokenRenderer<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of ITokenRenderer<ComponentState<TContractState>> {
        fn get_renderer(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            let renderer = self.token_renderers.read(token_id);
            if renderer.renderer_address.is_zero() {
                self.default_renderer.read()
            } else {
                renderer.renderer_address
            }
        }

        fn has_custom_renderer(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let renderer = self.token_renderers.read(token_id);
            !renderer.renderer_address.is_zero()
        }

        fn get_default_renderer(self: @ComponentState<TContractState>) -> ContractAddress {
            self.default_renderer.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>, default_renderer: ContractAddress,
        ) {
            self.default_renderer.write(default_renderer);
        }

        fn set_token_renderer(
            ref self: ComponentState<TContractState>,
            token_id: u64,
            renderer_address: ContractAddress,
        ) {
            self.token_renderers.write(token_id, TokenRenderer { renderer_address });
            self.emit(RendererSet { token_id, renderer_address });
        }

        fn set_default_renderer(
            ref self: ComponentState<TContractState>, renderer_address: ContractAddress,
        ) {
            self.default_renderer.write(renderer_address);
            self.emit(DefaultRendererSet { renderer_address });
        }

        fn _set_renderer_if_provided(
            ref self: ComponentState<TContractState>,
            token_id: u64,
            renderer_address: Option<ContractAddress>,
        ) {
            if let Option::Some(renderer) = renderer_address {
                self.set_token_renderer(token_id, renderer);
            }
        }
    }
}

#[starknet::interface]
pub trait ITokenRenderer<TState> {
    fn get_renderer(self: @TState, token_id: u64) -> ContractAddress;
    fn has_custom_renderer(self: @TState, token_id: u64) -> bool;
    fn get_default_renderer(self: @TState) -> ContractAddress;
}
