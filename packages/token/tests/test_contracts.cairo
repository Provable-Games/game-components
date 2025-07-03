// Test contracts for testing token functionality
use starknet::ContractAddress;
use game_components_token::interface::IMinigameToken;
use game_components_token::token::TokenComponent;
use game_components_metagame::extensions::context::structs::GameContextDetails;
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
use game_components_token::extensions::multi_game::multi_game::MultiGameComponent;
use game_components_token::extensions::minter::minter::MinterComponent;
use game_components_token::extensions::objectives::objectives::TokenObjectivesComponent;

// Basic token contract without extensions
#[starknet::contract]
pub mod BasicTokenContract {
    use super::*;
    
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Metadata = ERC721Component::ERC721MetadataImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    
    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        token: TokenComponent::Storage,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        TokenEvent: TokenComponent::Event,
    }
    
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: ContractAddress
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.token.initializer(Option::Some(game_address));
    }
}

// Token contract with multi-game support
#[starknet::contract]
pub mod MultiGameTokenContract {
    use super::*;
    
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: TokenObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Metadata = ERC721Component::ERC721MetadataImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl MultiGameImpl = MultiGameComponent::MultiGameImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl TokenObjectivesImpl = TokenObjectivesComponent::TokenObjectivesImpl<ContractState>;
    
    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        token: TokenComponent::Storage,
        #[substorage(v0)]
        multi_game: MultiGameComponent::Storage,
        #[substorage(v0)]
        minter: MinterComponent::Storage,
        #[substorage(v0)]
        objectives: TokenObjectivesComponent::Storage,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        TokenEvent: TokenComponent::Event,
        #[flat]
        MultiGameEvent: MultiGameComponent::Event,
        #[flat]
        MinterEvent: MinterComponent::Event,
        #[flat]
        ObjectivesEvent: TokenObjectivesComponent::Event,
    }
    
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.token.initializer(Option::None);
    }
}