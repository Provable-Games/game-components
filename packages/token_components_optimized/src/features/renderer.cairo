#[starknet::interface]
pub trait IRendererComponent<TState> {
    fn get_renderer(self: @TState, token_id: u64) -> starknet::ContractAddress;
    fn set_renderer(ref self: TState, token_id: u64, renderer: starknet::ContractAddress);
    fn has_custom_renderer(self: @TState, token_id: u64) -> bool;
}

#[starknet::component]
pub mod RendererComponent {
    use starknet::ContractAddress;
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use crate::core::traits::OptionalRenderer;
    use super::IRendererComponent;

    #[storage]
    pub struct Storage {
        token_renderers: Map<u64, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RendererSet: RendererSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RendererSet {
        token_id: u64,
        renderer: ContractAddress,
    }

    #[embeddable_as(RendererImpl)]
    pub impl Renderer<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IRendererComponent<ComponentState<TContractState>> {
        
        fn get_renderer(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            self.token_renderers.entry(token_id).read()
        }

        fn set_renderer(ref self: ComponentState<TContractState>, token_id: u64, renderer: ContractAddress) {
            self.token_renderers.entry(token_id).write(renderer);
            
            self.emit(RendererSet {
                token_id,
                renderer,
            });
        }

        fn has_custom_renderer(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let renderer = self.token_renderers.entry(token_id).read();
            renderer != starknet::contract_address_const::<0>()
        }
    }

    // Implementation of the OptionalRenderer trait for integration with CoreTokenComponent
    pub impl RendererOptionalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of OptionalRenderer<TContractState> {
        
        fn get_token_renderer(self: @TContractState, token_id: u64) -> Option<ContractAddress> {
            let component = HasComponent::get_component(self);
            let renderer = component.get_renderer(token_id);
            
            if renderer == starknet::contract_address_const::<0>() {
                Option::None
            } else {
                Option::Some(renderer)
            }
        }

        fn set_token_renderer(ref self: TContractState, token_id: u64, renderer: ContractAddress) {
            let mut component = HasComponent::get_component_mut(ref self);
            component.set_renderer(token_id, renderer);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        
        fn initializer(ref self: ComponentState<TContractState>) {
            // Nothing to initialize for renderer
        }
    }
} 