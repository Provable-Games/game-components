#[starknet::component]
pub mod SoulboundComponent {
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use crate::core::traits::OptionalSoulbound;
    use crate::extensions::soulbound::interface::IMinigameTokenSoulbound;

    #[storage]
    pub struct Storage {
        soulbound_tokens: Map<u64, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenSoulbound: TokenSoulbound,
        TokenSoulboundRevoked: TokenSoulboundRevoked,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenSoulbound {
        token_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenSoulboundRevoked {
        token_id: u64,
    }

    #[embeddable_as(SoulboundImpl)]
    pub impl Soulbound<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameTokenSoulbound<ComponentState<TContractState>> {
        
        fn is_soulbound(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            self.soulbound_tokens.entry(token_id).read()
        }

        fn make_soulbound(ref self: ComponentState<TContractState>, token_id: u64) {
            self.soulbound_tokens.entry(token_id).write(true);
            
            self.emit(TokenSoulbound {
                token_id,
            });
        }

        fn revoke_soulbound(ref self: ComponentState<TContractState>, token_id: u64) {
            self.soulbound_tokens.entry(token_id).write(false);
            
            self.emit(TokenSoulboundRevoked {
                token_id,
            });
        }
    }

    // Implementation of the OptionalSoulbound trait for integration with CoreTokenComponent
    pub impl SoulboundOptionalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of OptionalSoulbound<TContractState> {
        
        fn check_transfer_allowed(self: @TContractState, token_id: u64) -> bool {
            let component = HasComponent::get_component(self);
            !component.is_soulbound(token_id)
        }

        fn set_soulbound_status(ref self: TContractState, token_id: u64, is_soulbound: bool) {
            let mut component = HasComponent::get_component_mut(ref self);
            if is_soulbound {
                component.make_soulbound(token_id);
            } else {
                component.revoke_soulbound(token_id);
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
            // Nothing to initialize for soulbound
        }
    }
} 