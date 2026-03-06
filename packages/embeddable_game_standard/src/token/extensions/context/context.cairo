#[starknet::component]
pub mod ContextComponent {
    use game_components_embeddable_game_standard::metagame::extensions::context::interface::IMETAGAME_CONTEXT_ID;
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component::{self, InternalTrait as SRC5InternalTrait};
    use starknet::ContractAddress;
    use crate::token::extensions::context::interface::IMINIGAME_TOKEN_CONTEXT_ID;
    use crate::token::traits::OptionalContext;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenContextUpdate: TokenContextUpdate,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenContextUpdate {
        #[key]
        pub token_id: felt252,
        pub details: GameContextDetails,
    }

    // Implementation of the OptionalContext trait for integration with CoreTokenComponent
    pub impl ContextOptionalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of OptionalContext<TContractState> {
        fn emit_context(
            ref self: TContractState,
            caller: ContractAddress,
            token_id: felt252,
            context: GameContextDetails,
        ) {
            let src5_dispatcher = ISRC5Dispatcher { contract_address: caller };
            assert!(
                src5_dispatcher.supports_interface(IMETAGAME_CONTEXT_ID),
                "MinigameTokenContext: Minter does not implement IMetagameContext",
            );

            // Emit native event with full details struct
            let mut component = HasComponent::get_component_mut(ref self);
            component.emit(TokenContextUpdate { token_id: token_id, details: context });
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
            src5_component.register_interface(IMINIGAME_TOKEN_CONTEXT_ID);
        }
    }
}
