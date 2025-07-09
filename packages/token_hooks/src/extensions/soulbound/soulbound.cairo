#[starknet::component]
pub mod SoulboundComponent {
    use starknet::ContractAddress;
    use openzeppelin_token::erc721::ERC721Component;

    use crate::token::TokenComponent;
    use crate::structs::TokenMetadata;

    #[storage]
    pub struct Storage {}

    impl SoulboundHooksImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Token: TokenComponent::HasComponent<TContractState>,
    > of ERC721Component::ERC721HooksTrait<ComponentState<TContractState>> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ComponentState<TContractState>>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // Check if this is a transfer (not a mint) and if token is soulbound
            if !auth.is_zero() && !to.is_zero() { // This is a transfer, not a mint
                let token_component = get_dep_component_mut!(ref self, Token);
                let token_metadata: TokenMetadata = token_component
                    .get_token_metadata(token_id.try_into().unwrap());

                assert!(
                    !token_metadata.soulbound,
                    "MinigameToken Soulbound: Token is soulbound and cannot be transferred",
                );
            }
        }
    }
}
