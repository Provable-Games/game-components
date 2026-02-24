#[starknet::component]
pub mod ContextComponent {
    use game_components_metagame::extensions::context::interface::IMETAGAME_CONTEXT_ID;
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use game_components_utils::json::create_context_json;
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::core::traits::OptionalContext;
    use crate::interface::{ITokenEventRelayerDispatcher, ITokenEventRelayerDispatcherTrait};

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenContextUpdate: TokenContextUpdate,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenContextUpdate {
        pub token_id: u64,
        pub data: ByteArray,
    }

    // Implementation of the OptionalContext trait for integration with CoreTokenComponent
    pub impl ContextOptionalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of OptionalContext<TContractState> {
        fn emit_context(
            ref self: TContractState,
            caller: ContractAddress,
            token_id: u64,
            context: GameContextDetails,
            event_relayer: Option<ITokenEventRelayerDispatcher>,
        ) {
            let src5_dispatcher = ISRC5Dispatcher { contract_address: caller };
            assert!(
                src5_dispatcher.supports_interface(IMETAGAME_CONTEXT_ID),
                "MinigameTokenContext: Minter does not implement IMetagameContext",
            );
            let context_json = create_context_json(
                context.name, context.description, context.id, context.context,
            );

            // Emit event
            match event_relayer {
                Option::Some(relayer) => relayer
                    .emit_token_context_update(token_id, context_json.clone()),
                Option::None => {
                    let mut component = HasComponent::get_component_mut(ref self);
                    component
                        .emit(
                            TokenContextUpdate { token_id: token_id, data: context_json.clone() },
                        );
                },
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
        // No-op: IMINIGAME_TOKEN_CONTEXT_ID was removed (no backing trait).
        // Kept for backwards compatibility with existing initializer call sites.
        fn initializer(ref self: ComponentState<TContractState>) {}
    }
}
