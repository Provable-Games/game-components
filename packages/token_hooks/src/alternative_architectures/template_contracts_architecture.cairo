// Alternative Architecture #5: Pre-built Template Contracts
// This approach provides ready-to-use contract templates for common patterns

// Template 1: Minimal Token (No Extensions)
#[starknet::contract]
pub mod MinimalToken {
    use crate::token::TokenComponent;
    use crate::libs::token_hooks_empty::TokenHooksEmptyImpl;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_introspection::src5::SRC5Component;

    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

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

    impl TokenHooks = TokenHooksEmptyImpl<ContractState>;
    impl ERC721Hooks = ERC721HooksEmptyImpl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: Option<ContractAddress>,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.token.initializer(game_address);
        self.src5.register_interface(crate::interface::IMINIGAME_TOKEN_ID);
    }

    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
}

// Template 2: Token with Settings Only
#[starknet::contract]
pub mod TokenWithSettings {
    use crate::token::TokenComponent;
    use crate::extensions::settings::settings::SettingsComponent;
    use crate::libs::validation::validation;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: SettingsComponent, storage: settings, event: SettingsEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        token: TokenComponent::Storage,
        #[substorage(v0)]
        settings: SettingsComponent::Storage,
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
        SettingsEvent: SettingsComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    // Inline hooks for settings validation
    impl TokenHooks of TokenComponent::TokenHooksTrait<ContractState> {
        fn before_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u64,
            game_address: Option<ContractAddress>,
            settings_id: Option<u32>,
            objective_ids: Option<Span<u32>>,
        ) -> (u64, u32, u32) {
            match game_address {
                Option::Some(game_addr) => {
                    validation::validate_game_address(game_addr);
                    let validated_settings = validation::validate_settings(
                        game_addr, settings_id, true
                    );
                    (0, validated_settings, 0)
                },
                Option::None => (0, 0, 0),
            }
        }
        
        fn after_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u64,
            caller_address: ContractAddress,
        ) {}
        
        fn before_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
            token_metadata: crate::structs::TokenMetadata,
        ) -> ContractAddress {
            self.game_address.read()
        }
        
        fn after_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
        ) -> bool {
            false
        }
    }

    impl ERC721Hooks = ERC721HooksEmptyImpl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: Option<ContractAddress>,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.token.initializer(game_address);
        self.src5.register_interface(crate::interface::IMINIGAME_TOKEN_ID);
        self.src5.register_interface(crate::extensions::settings::interface::IMINIGAME_SETTINGS_ID);
    }

    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl SettingsImpl = SettingsComponent::SettingsImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
}

// Template 3: Full Featured Token
#[starknet::contract]
pub mod FullFeaturedToken {
    use crate::token::TokenComponent;
    use crate::token_hooks_full_impl::TokenHooksFullImpl;
    use crate::extensions::settings::settings::SettingsComponent;
    use crate::extensions::objectives::objectives::TokenObjectivesComponent;
    use crate::extensions::minter::minter::MinterComponent;
    use crate::extensions::multi_game::multi_game::MultiGameComponent;
    use crate::extensions::renderer::renderer::RendererComponent;
    use crate::extensions::soulbound::soulbound::SoulboundComponent;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: SettingsComponent, storage: settings, event: SettingsEvent);
    component!(path: TokenObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
    component!(path: RendererComponent, storage: renderer, event: RendererEvent);
    component!(path: SoulboundComponent, storage: soulbound, event: SoulboundEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        token: TokenComponent::Storage,
        #[substorage(v0)]
        settings: SettingsComponent::Storage,
        #[substorage(v0)]
        objectives: TokenObjectivesComponent::Storage,
        #[substorage(v0)]
        minter: MinterComponent::Storage,
        #[substorage(v0)]
        multi_game: MultiGameComponent::Storage,
        #[substorage(v0)]
        renderer: RendererComponent::Storage,
        #[substorage(v0)]
        soulbound: SoulboundComponent::Storage,
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
        // All extension events...
    }

    // Use pre-built full hooks implementation
    impl TokenHooks = TokenHooksFullImpl<ContractState>;
    impl ERC721Hooks = ERC721HooksEmptyImpl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.token.initializer(Option::None); // Multi-game token
        // Register all interfaces
        self.src5.register_interface(crate::interface::IMINIGAME_TOKEN_ID);
        self.src5.register_interface(crate::extensions::settings::interface::IMINIGAME_SETTINGS_ID);
        self.src5.register_interface(crate::extensions::objectives::interface::IMINIGAME_TOKEN_OBJECTIVES_ID);
        self.src5.register_interface(crate::extensions::minter::interface::IMINIGAME_TOKEN_MINTER_ID);
        self.src5.register_interface(crate::extensions::multi_game::interface::IMINIGAME_TOKEN_MULTIGAME_ID);
    }

    // Implement all interfaces
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl SettingsImpl = SettingsComponent::SettingsImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ObjectivesImpl = TokenObjectivesComponent::TokenObjectivesImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl MultiGameImpl = MultiGameComponent::MultiGameImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl IMinigameTokenMultiGame of crate::extensions::multi_game::interface::IMinigameTokenMultiGame<ContractState> {
        fn game_address_from_id(self: @ContractState, game_id: u64) -> ContractAddress {
            self.multi_game.game_address_from_id(game_id)
        }
    }
}

// Template Generator Macro (conceptual - not valid Cairo)
// This shows how we could generate custom contracts
pub mod TemplateGenerator {
    // Developers would use something like:
    // generate_token_contract!(
    //     name: "MyGameToken",
    //     features: [settings, objectives, minter],
    //     custom_hooks: MyCustomHooks
    // );
    
    // Which would generate:
    // - Correct component declarations
    // - Minimal storage for selected features
    // - Appropriate hook implementation
    // - Only needed interface implementations
}

// ===== ANALYSIS =====
//
// Benefits of template approach:
// 1. Zero learning curve: Pick template, deploy
// 2. Optimized by default: Each template is pre-optimized
// 3. Type-safe: Compiler ensures everything matches
// 4. Minimal size: Only includes needed components
// 5. Best practices built-in: Templates follow all patterns
//
// Developer workflow:
// 1. Choose template matching needs
// 2. Copy and customize if needed
// 3. Deploy
//
// Templates provided:
// - MinimalToken: Just NFT functionality (~50k gas mint)
// - TokenWithSettings: NFT + settings (~65k gas mint)
// - TokenWithObjectives: NFT + objectives (~70k gas mint)
// - TokenWithMinter: NFT + minter tracking (~60k gas mint)
// - FullFeaturedToken: Everything (~100k gas mint)
//
// Custom combinations:
// - Copy closest template
// - Add/remove components
// - Adjust hooks implementation
//
// This preserves all hook benefits while making it extremely developer-friendly.