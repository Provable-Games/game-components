#[starknet::component]
pub mod ContextComponent {
    use starknet::{ContractAddress, get_block_timestamp};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use crate::core::traits::OptionalContext;
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use game_components_metagame::extensions::context::interface::IMETAGAME_CONTEXT_ID;
    use game_components_utils::json::create_context_json;

    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenContextData: TokenContextData,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenContextData {
        pub token_id: u64,
        pub data: ByteArray,
    }

    // #[embeddable_as(ContextImpl)]
    // pub impl Context<
    //     TContractState,
    //     +HasComponent<TContractState>,
    //     +Drop<TContractState>,
    // > of IMinigameTokenContext<ComponentState<TContractState>> {}

    // Implementation of the OptionalContext trait for integration with CoreTokenComponent
    pub impl ContextOptionalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of OptionalContext<TContractState> {
        fn emit_context(ref self: TContractState, caller: ContractAddress, token_id: u64, context: Option<GameContextDetails>) -> bool {
            match context {
                Option::Some(context) => {
                    let src5_dispatcher = ISRC5Dispatcher { contract_address: caller };
                    assert!(
                        src5_dispatcher.supports_interface(IMETAGAME_CONTEXT_ID),
                        "Denshokan: Minter does not implement IMetagameContext",
                    );
                    let context_json = create_context_json(context.name, context.description, context.id, context.context);
                    let mut component = HasComponent::get_component_mut(ref self);
                    component.emit(TokenContextData { token_id: token_id, data: context_json });
                    true
                },
                Option::None => {
                    false
                }
            }
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            // Nothing to initialize for context
        }
    }
} 