#[starknet::component]
pub mod RendererComponent {
    use starknet::{ContractAddress, contract_address_const};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use crate::core::traits::OptionalRenderer;
    use crate::extensions::renderer::interface::IMinigameTokenRenderer;
    use crate::libs::address_utils;

    use crate::extensions::renderer::interface::IMINIGAME_TOKEN_RENDERER_ID;

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;

    use crate::interface::{ITokenEventRelayerDispatcher, ITokenEventRelayerDispatcherTrait};

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
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IMinigameTokenRenderer<ComponentState<TContractState>> {
        fn get_renderer(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            self.token_renderers.entry(token_id).read()
        }

        fn has_custom_renderer(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let renderer = self.token_renderers.entry(token_id).read();
            address_utils::is_non_zero_address(renderer)
        }
    }

    // Implementation of the OptionalRenderer trait for integration with CoreTokenComponent
    pub impl RendererOptionalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of OptionalRenderer<TContractState> {
        fn get_token_renderer(self: @TContractState, token_id: u64) -> Option<ContractAddress> {
            let component = HasComponent::get_component(self);
            let renderer = component.get_renderer(token_id);
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

            component.emit(RendererSet { token_id, renderer });

            if let Option::Some(relayer) = event_relayer {
                relayer.emit_token_renderer_update(token_id, renderer);
            }
        }

        fn reset_token_renderer(
            ref self: TContractState,
            token_id: u64,
            event_relayer: Option<ITokenEventRelayerDispatcher>,
        ) {
            let mut component = HasComponent::get_component_mut(ref self);
            component.token_renderers.entry(token_id).write(contract_address_const::<0>());

            component.emit(RendererSet { token_id, renderer: contract_address_const::<0>() });

            if let Option::Some(relayer) = event_relayer {
                relayer.emit_token_renderer_update(token_id, contract_address_const::<0>());
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
