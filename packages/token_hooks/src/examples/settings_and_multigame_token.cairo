#[starknet::contract]
mod SettingsAndMultigameToken {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::Zero;
    
    use crate::token::TokenComponent;
    use crate::interface::{IMinigameToken, IMINIGAME_TOKEN_ID};
    use crate::libs::validation::validation;
    
    // Only import the components we need
    use crate::extensions::settings::interface::IMINIGAME_TOKEN_SETTINGS_ID;
    use crate::extensions::multi_game::interface::IMINIGAME_TOKEN_MULTIGAME_ID;
    
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    
    // Clean token hooks - only handles settings and multi-game
    impl TokenHooksImpl of TokenComponent::TokenHooksTrait<ContractState> {
        fn before_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            game_address: Option<ContractAddress>,
            settings_id: Option<u32>,
            objective_ids: Option<Span<u32>>,
        ) -> (u64, u32, u32) {
            // We don't support objectives in this contract
            assert!(
                objective_ids.is_none(),
                "MinigameToken: Objectives not supported in this contract"
            );
            
            // Validate game with multi-game support
            let (game_addr, game_id) = match game_address {
                Option::Some(addr) => {
                    validation::validate_game_address(addr);
                    // Multi-game support - allow different game addresses
                    // In a real implementation, you'd look up or assign game_id
                    (addr, 1) // Simplified - would be dynamic
                },
                Option::None => (self.game_address.read(), 0)
            };
            
            // Then validate settings
            let validated_settings_id = validation::validate_settings(
                game_addr,
                settings_id,
                true // this contract supports settings
            );
            
            (game_id, validated_settings_id, 0) // 0 objectives count
        }
        
        fn after_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u64,
            caller_address: ContractAddress,
            game_address: Option<ContractAddress>,
            token_metadata: crate::structs::TokenMetadata,
        ) {
            // No minter component in this example
            // No objectives component in this example
            // Just settings and multi-game support
        }
        
        fn before_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
            token_metadata: crate::structs::TokenMetadata,
        ) -> ContractAddress {
            // Could add multi-game specific logic here
            // For multi-game, return the game address from token metadata
            if token_metadata.game_id != 0 {
                // In a real implementation, you'd look up the game address by game_id
                // For now, return base game address
                self.game_address.read()
            } else {
                self.game_address.read()
            }
        }
        
        fn after_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
        ) -> bool {
            false
            // No objectives in this contract, so completed_all_objectives is ignored
        }
    }
    
    // Implement ERC721 hooks
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
        #[substorage(v0)]
        token: TokenComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Notice: No minter or objectives storage!
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
        // Notice: No minter or objectives events!
    }
    
    #[constructor]
    fn constructor(
        ref self: ContractState, 
        name: ByteArray, 
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: ContractAddress,
    ) {
        // Initialize components
        self.erc721.initializer(name, symbol, base_uri);
        self.token.initializer(Option::Some(game_address));
        
        // Only register the interfaces we support
        self.src5.register_interface(IMINIGAME_TOKEN_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_SETTINGS_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_MULTIGAME_ID);
        // Notice: NOT registering IMINIGAME_TOKEN_MINTER_ID or IMINIGAME_TOKEN_OBJECTIVES_ID
    }
}