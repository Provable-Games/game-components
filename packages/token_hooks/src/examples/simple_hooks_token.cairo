#[starknet::contract]
mod SimpleHooksToken {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::Zero;
    
    use crate::token::TokenComponent;
    use crate::interface::{IMinigameToken, IMINIGAME_TOKEN_ID};
    use crate::libs::validation::validation;
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use game_components_minigame::interface::{IMINIGAME_ID};
    
    // Import optional components
    use crate::extensions::minter::minter::MinterComponent;
    use crate::extensions::minter::minter::MinterComponent::InternalTrait as MinterInternalTrait;
    use crate::extensions::minter::interface::IMINIGAME_TOKEN_MINTER_ID;
    
    use crate::extensions::objectives::objectives::TokenObjectivesComponent;
    use crate::extensions::objectives::objectives::TokenObjectivesComponent::InternalTrait as TokenObjectivesInternalTrait;
    use crate::extensions::objectives::interface::IMINIGAME_TOKEN_OBJECTIVES_ID;
    use crate::extensions::objectives::structs::TokenObjective;
    
    use crate::extensions::settings::interface::IMINIGAME_TOKEN_SETTINGS_ID;
    
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: TokenObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    
    // SIMPLIFIED TOKEN HOOKS IMPLEMENTATION
    impl TokenHooksImpl of TokenComponent::TokenHooksTrait<ContractState> {
        fn before_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            game_address: Option<ContractAddress>,
            settings_id: Option<u32>,
            objective_ids: Option<Span<u32>>,
        ) -> (u64, u32, u32) {
            match game_address {
                Option::Some(game_addr) => {
                    // Validate game supports IMinigame
                    validation::validate_game_address(game_addr);
                    
                    // No multi-game support in this example
                    assert!(
                        game_addr == self.game_address.read(),
                        "MinigameToken: Game address mismatch"
                    );
                    
                    // Validate settings if provided
                    let validated_settings_id = validation::validate_settings(
                        game_addr,
                        settings_id,
                        true // assume settings are supported
                    );
                    
                    // Validate objectives if provided  
                    let objectives_count = validation::validate_objectives(
                        game_addr,
                        objective_ids,
                        true // assume objectives are supported
                    );
                    
                    (0, validated_settings_id, objectives_count)
                },
                Option::None => {
                    // Blank NFT support
                    (0, 0, 0)
                }
            }
        }
        
        fn after_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u64,
            caller_address: ContractAddress,
            game_address: Option<ContractAddress>,
            token_metadata: crate::structs::TokenMetadata,
        ) {
            // Get contract state to access components
            let mut contract = self.get_contract_mut();
            
            // Minter: Register minter with original caller preserved
            if contract.src5.supports_interface(IMINIGAME_TOKEN_MINTER_ID) {
                contract.minter.add_minter(caller_address);
            }
        }
        
        fn before_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
            token_metadata: crate::structs::TokenMetadata,
        ) -> ContractAddress {
            // Add custom logic if needed
            // Return the base game address
            self.game_address.read()
        }
        
        fn after_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
        ) -> bool {
            false
            // Add custom logic if needed
        }
    }
    
    // Implement ERC721 hooks
    impl ERC721Hooks = ERC721HooksEmptyImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ObjectivesImpl = TokenObjectivesComponent::TokenObjectivesImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Metadata = ERC721Component::ERC721MetadataImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    
    impl TokenInternalImpl = TokenComponent::InternalImpl<ContractState>;
    impl MinterInternalImpl = MinterComponent::InternalImpl<ContractState>;
    impl TokenObjectivesInternalImpl = TokenObjectivesComponent::InternalImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    
    #[storage]
    struct Storage {
        #[substorage(v0)]
        token: TokenComponent::Storage,
        #[substorage(v0)]
        minter: MinterComponent::Storage,
        #[substorage(v0)]
        objectives: TokenObjectivesComponent::Storage,
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
        MinterEvent: MinterComponent::Event,
        #[flat]
        ObjectivesEvent: TokenObjectivesComponent::Event,
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
        self.minter.initializer();
        
        // Register interfaces
        self.src5.register_interface(IMINIGAME_TOKEN_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_MINTER_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_OBJECTIVES_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_SETTINGS_ID);
    }
}