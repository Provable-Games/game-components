#[starknet::contract]
mod SettingsOnlyToken {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::Zero;
    
    use crate::token::TokenComponent;
    use crate::interface::{IMinigameToken, IMINIGAME_TOKEN_ID};
    use crate::libs::validation::validation;
    
    // Only import settings component
    use crate::extensions::settings::interface::IMINIGAME_TOKEN_SETTINGS_ID;
    
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    
    // Clean token hooks - only handles settings with explicit validation
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
            
            // Step 1: Validate game address if provided
            let game_addr = match game_address {
                Option::Some(addr) => {
                    validation::validate_game_address(addr);
                    // Ensure single game (no multi-game support)
                    assert!(
                        addr == self.game_address.read(),
                        "MinigameToken: Game address mismatch"
                    );
                    addr
                },
                Option::None => self.game_address.read()
            };
            
            // Step 2: Validate settings
            let validated_settings_id = validation::validate_settings(
                game_addr,
                settings_id,
                true // this contract supports settings
            );
            
            // Return: (game_id=0 for single game, settings_id, objectives_count=0)
            (0, validated_settings_id, 0)
        }
        
        fn after_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u64,
            caller_address: ContractAddress,
            game_address: Option<ContractAddress>,
            token_metadata: crate::structs::TokenMetadata,
        ) {
            // No additional processing needed for settings-only token
        }
        
        fn before_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
            token_metadata: crate::structs::TokenMetadata,
        ) -> ContractAddress {
            // Could add settings-specific pre-update logic here
            // Return the base game address
            self.game_address.read()
        }
        
        fn after_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
        ) -> bool {
            false
            // No objectives to track in this contract
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
        // NOT registering objectives, minter, or multi-game interfaces
    }
}