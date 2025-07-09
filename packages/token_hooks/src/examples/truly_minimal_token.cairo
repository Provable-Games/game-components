// Truly minimal token - no optional components at all
// This demonstrates the minimum storage footprint possible

#[starknet::contract]
mod TrulyMinimalToken {
    use starknet::ContractAddress;
    
    use crate::token::TokenComponent;
    use crate::interface::IMINIGAME_TOKEN_ID;
    
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use crate::libs::token_hooks_empty::token_hooks_empty::TokenHooksEmptyImpl;
    
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    
    // Use the empty hooks implementation
    impl TokenHooks = TokenHooksEmptyImpl<ContractState>;
    
    impl ERC721Hooks = ERC721HooksEmptyImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Metadata = ERC721Component::ERC721MetadataImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    
    impl TokenInternalImpl = TokenComponent::InternalImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    
    #[storage]
    struct Storage {
        // ONLY the absolutely required components
        #[substorage(v0)]
        token: TokenComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // NO minter, objectives, settings, or other optional storage
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        TokenEvent: TokenComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        // NO optional component events
    }
    
    #[constructor]
    fn constructor(
        ref self: ContractState, 
        name: ByteArray, 
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: ContractAddress,
    ) {
        // Initialize only required components
        self.erc721.initializer(name, symbol, base_uri);
        self.token.initializer(Option::Some(game_address));
        
        // Register only the base interface
        self.src5.register_interface(IMINIGAME_TOKEN_ID);
        // NO other interface registrations
    }
}