#[starknet::contract]
mod FullFeaturedUpdateToken {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::Zero;
    
    use crate::token::TokenComponent;
    use crate::interface::{IMinigameToken, IMINIGAME_TOKEN_ID};
    use crate::libs::validation::validation;
    use crate::libs::objectives_update::objectives_update;
    use crate::libs::multi_game_update::multi_game_update;
    
    // Import all components for full features
    use crate::extensions::minter::minter::MinterComponent;
    use crate::extensions::minter::interface::IMINIGAME_TOKEN_MINTER_ID;
    use crate::extensions::objectives::objectives::TokenObjectivesComponent;
    use crate::extensions::objectives::interface::IMINIGAME_TOKEN_OBJECTIVES_ID;
    use crate::extensions::multi_game::multi_game::MultiGameComponent;
    use crate::extensions::multi_game::interface::IMINIGAME_TOKEN_MULTIGAME_ID;
    use crate::extensions::settings::interface::IMINIGAME_TOKEN_SETTINGS_ID;
    
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_introspection::src5::SRC5Component;
    use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
    
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: TokenObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    
    // Full featured hooks using ERC721 hooks
    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {
            // Standard validation logic here
            match game_address {
                Option::Some(game_addr) => {
                    validation::validate_game_address(game_addr);
                    // For multi-game, don't enforce address match
                    let game_id = if self.get_contract().src5.supports_interface(IMINIGAME_TOKEN_MULTIGAME_ID) {
                        // Would get/assign game_id in real implementation
                        1
                    } else {
                        assert!(game_addr == self.game_address.read(), "Game address mismatch");
                        0
                    };
                    
                    let validated_settings = validation::validate_settings(
                        game_addr, settings_id, true
                    );
                    let objectives_count = validation::validate_objectives(
                        game_addr, objective_ids, true
                    );
                    
                    (game_id, validated_settings, objectives_count)
                },
                Option::None => (0, 0, 0)
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
            let mut contract = self.get_contract_mut();
            if contract.src5.supports_interface(IMINIGAME_TOKEN_MINTER_ID) {
                contract.minter.add_minter(caller_address);
            }
        }
        
        fn before_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
            token_metadata: crate::structs::TokenMetadata,
        ) -> ContractAddress {
            // Could add pre-update validation here
            // For multi-game, use the metadata to determine the game address
            let contract = self.get_contract();
            multi_game_update::get_game_address_for_token(
                @contract,
                token_id,
                token_metadata.game_id,
                self.game_address.read()
            )
        }
        
        fn after_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
            game_over: bool,
            completed_all_objectives: bool,
        ) {
            // This is where we use our new libraries!
            let mut contract = self.get_contract_mut();
            let token_data = self.get_token_metadata(token_id);
            
            // Step 1: Get the correct game address (handles multi-game)
            let game_address = multi_game_update::get_game_address_for_token(
                @contract,
                token_id,
                token_data.game_id,
                self.game_address.read()
            );
            
            // Step 2: Process objectives if supported and game not over
            if !game_over && token_data.objectives_count > 0 {
                let all_completed = objectives_update::process_token_objectives(
                    ref contract,
                    token_id,
                    game_address,
                    token_data.objectives_count.into()
                );
                
                // If all objectives completed, could trigger additional logic
                if all_completed {
                    // Emit event, give rewards, etc.
                }
            }
        }
    }
    
    // Removed - we're implementing our own hooks
    
    // Standard implementations
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ObjectivesImpl = TokenObjectivesComponent::TokenObjectivesImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl MultiGameImpl = MultiGameComponent::MultiGameImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Metadata = ERC721Component::ERC721MetadataImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    
    impl TokenInternalImpl = TokenComponent::InternalImpl<ContractState>;
    impl MinterInternalImpl = MinterComponent::InternalImpl<ContractState>;
    impl TokenObjectivesInternalImpl = TokenObjectivesComponent::InternalImpl<ContractState>;
    impl MultiGameInternalImpl = MultiGameComponent::InternalImpl<ContractState>;
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
        multi_game: MultiGameComponent::Storage,
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
        MultiGameEvent: MultiGameComponent::Event,
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
        self.erc721.initializer(name, symbol, base_uri);
        self.token.initializer(Option::Some(game_address));
        self.minter.initializer();
        self.multi_game.initializer();
        
        self.src5.register_interface(IMINIGAME_TOKEN_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_MINTER_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_OBJECTIVES_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_SETTINGS_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_MULTIGAME_ID);
    }
}