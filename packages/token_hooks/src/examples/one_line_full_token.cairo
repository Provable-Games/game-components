#[starknet::contract]
mod OneLineFullToken {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::Zero;
    
    use crate::token::TokenComponent;
    use crate::interface::{IMinigameToken, IMINIGAME_TOKEN_ID};
    
    // Import all the components we need
    use crate::extensions::minter::minter::MinterComponent;
    use crate::extensions::minter::minter::MinterComponent::InternalTrait as MinterInternalTrait;
    use crate::extensions::minter::interface::IMINIGAME_TOKEN_MINTER_ID;
    
    use crate::extensions::objectives::objectives::TokenObjectivesComponent;
    use crate::extensions::objectives::objectives::TokenObjectivesComponent::InternalTrait as TokenObjectivesInternalTrait;
    use crate::extensions::objectives::interface::IMINIGAME_TOKEN_OBJECTIVES_ID;
    use crate::extensions::objectives::structs::TokenObjective;
    
    use crate::extensions::settings::interface::IMINIGAME_TOKEN_SETTINGS_ID;
    
    use crate::extensions::multi_game::interface::{IMINIGAME_TOKEN_MULTIGAME_ID, IMinigameTokenMultiGame};
    use crate::extensions::multi_game::multi_game::MultiGameComponent;
    
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: TokenObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    
    // ✨ ONE LINE to get full token hooks implementation! ✨
    impl TokenHooks = crate::token_hooks_full_impl::TokenHooksFullImpl<ContractState>;
    
    // Implement ERC721 hooks
    impl ERC721Hooks = ERC721HooksEmptyImpl<ContractState>;
    
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
        // Initialize components
        self.erc721.initializer(name, symbol, base_uri);
        self.token.initializer(Option::Some(game_address));
        self.minter.initializer();
        self.multi_game.initializer();
        
        // Register interfaces
        self.src5.register_interface(IMINIGAME_TOKEN_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_MINTER_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_OBJECTIVES_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_SETTINGS_ID);
        self.src5.register_interface(IMINIGAME_TOKEN_MULTIGAME_ID);
    }
}