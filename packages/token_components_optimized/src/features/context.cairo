#[starknet::interface]
pub trait IContextComponent<TState> {
    fn get_context(self: @TState, token_id: u64) -> ContextMetadata;
    fn set_context(ref self: TState, token_id: u64, context: ContextMetadata);
    fn context_exists(self: @TState, token_id: u64) -> bool;
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ContextMetadata {
    pub token_id: u64,
    pub game_address: starknet::ContractAddress,
    pub context_data: felt252,
    pub timestamp: u64,
}

#[starknet::component]
pub mod ContextComponent {
    use starknet::{ContractAddress, get_block_timestamp};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use crate::core::traits::OptionalContext;
    use super::{IContextComponent, ContextMetadata};

    #[storage]
    pub struct Storage {
        token_context: Map<u64, ContextMetadata>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ContextSet: ContextSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContextSet {
        token_id: u64,
        game_address: ContractAddress,
        timestamp: u64,
    }

    #[embeddable_as(ContextImpl)]
    pub impl Context<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IContextComponent<ComponentState<TContractState>> {
        
        fn get_context(self: @ComponentState<TContractState>, token_id: u64) -> ContextMetadata {
            self.token_context.entry(token_id).read()
        }

        fn set_context(ref self: ComponentState<TContractState>, token_id: u64, context: ContextMetadata) {
            self.token_context.entry(token_id).write(context);
            
            self.emit(ContextSet {
                token_id,
                game_address: context.game_address,
                timestamp: context.timestamp,
            });
        }

        fn context_exists(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let context = self.token_context.entry(token_id).read();
            context.token_id != 0
        }
    }

    // Implementation of the OptionalContext trait for integration with CoreTokenComponent
    pub impl ContextOptionalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of OptionalContext<TContractState> {
        
        fn store_context(ref self: TContractState, token_id: u64, game_address: ContractAddress, context_data: felt252) {
            let mut component = HasComponent::get_component_mut(ref self);
            
            let context = ContextMetadata {
                token_id,
                game_address,
                context_data,
                timestamp: get_block_timestamp(),
            };
            
            component.set_context(token_id, context);
        }

        fn retrieve_context(self: @TContractState, token_id: u64) -> Option<ContextMetadata> {
            let component = HasComponent::get_component(self);
            if component.context_exists(token_id) {
                Option::Some(component.get_context(token_id))
            } else {
                Option::None
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