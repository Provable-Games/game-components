// Alternative Architecture #3: All Components with Enable/Disable Pattern
// This approach includes all components but with enabled flags

use starknet::ContractAddress;

#[starknet::contract]
mod TokenWithAllComponents {
    use crate::token::TokenComponent;
    use crate::extensions::settings::settings::SettingsComponent;
    use crate::extensions::objectives::objectives::TokenObjectivesComponent;
    use crate::extensions::minter::minter::MinterComponent;
    use crate::extensions::multi_game::multi_game::MultiGameComponent;
    use crate::extensions::renderer::renderer::RendererComponent;
    use crate::extensions::soulbound::soulbound::SoulboundComponent;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_introspection::src5::SRC5Component;

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
        // Component enable flags
        settings_enabled: bool,
        objectives_enabled: bool,
        minter_enabled: bool,
        multi_game_enabled: bool,
        renderer_enabled: bool,
        soulbound_enabled: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        TokenEvent: TokenComponent::Event,
        #[flat]
        SettingsEvent: SettingsComponent::Event,
        #[flat]
        ObjectivesEvent: TokenObjectivesComponent::Event,
        #[flat]
        MinterEvent: MinterComponent::Event,
        #[flat]
        MultiGameEvent: MultiGameComponent::Event,
        #[flat]
        RendererEvent: RendererComponent::Event,
        #[flat]
        SoulboundEvent: SoulboundComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    // Custom hooks implementation that checks enabled flags
    impl TokenHooks of TokenComponent::TokenHooksTrait<ContractState> {
        fn before_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u64,
            game_address: Option<ContractAddress>,
            settings_id: Option<u32>,
            objective_ids: Option<Span<u32>>,
        ) -> (u64, u32, u32) {
            let contract = self.get_contract();
            let mut validated_settings_id = 0_u32;
            let mut objectives_count = 0_u32;
            let mut game_id = 0_u64;
            
            // Runtime check for settings
            if contract.settings_enabled.read() && settings_id.is_some() {
                // Problem: Even if disabled, settings component storage is allocated
                let settings = settings_id.unwrap();
                // Validation logic...
                validated_settings_id = settings;
            }
            
            // Runtime check for objectives
            if contract.objectives_enabled.read() && objective_ids.is_some() {
                let objs = objective_ids.unwrap();
                objectives_count = objs.len();
                // Store objectives...
            }
            
            // Runtime check for multi-game
            if contract.multi_game_enabled.read() && game_address.is_some() {
                // Multi-game logic...
                game_id = 1; // Simplified
            }
            
            (game_id, validated_settings_id, objectives_count)
        }
        
        fn after_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u64,
            caller_address: ContractAddress,
        ) {
            let mut contract = self.get_contract_mut();
            
            // Runtime check for minter
            if contract.minter_enabled.read() {
                // Register minter
                let minter = contract.minter;
                // minter.add_minter(caller_address);
            }
            
            // Runtime check for renderer
            if contract.renderer_enabled.read() {
                // Set renderer logic...
            }
        }
        
        fn before_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
            token_metadata: crate::structs::TokenMetadata,
        ) -> ContractAddress {
            let contract = self.get_contract();
            
            // Runtime check for multi-game
            if contract.multi_game_enabled.read() && token_metadata.game_id > 0 {
                // Get game address from multi-game component
                // return contract.multi_game.get_game_address(token_metadata.game_id);
            }
            
            self.game_address.read()
        }
        
        fn after_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
        ) -> bool {
            let contract = self.get_contract();
            
            // Runtime check for objectives
            if contract.objectives_enabled.read() {
                // Check objectives completion
                // return contract.objectives.check_completion(token_id);
            }
            
            false
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        settings_enabled: bool,
        objectives_enabled: bool,
        minter_enabled: bool,
        multi_game_enabled: bool,
        renderer_enabled: bool,
        soulbound_enabled: bool,
    ) {
        // Set enable flags
        self.settings_enabled.write(settings_enabled);
        self.objectives_enabled.write(objectives_enabled);
        self.minter_enabled.write(minter_enabled);
        self.multi_game_enabled.write(multi_game_enabled);
        self.renderer_enabled.write(renderer_enabled);
        self.soulbound_enabled.write(soulbound_enabled);
        
        // Initialize components
        self.token.initializer(Option::None);
        self.erc721.initializer("Token", "TKN", "");
        self.src5.register_interface(crate::interface::IMINIGAME_TOKEN_ID);
        
        // Problem: All components are initialized even if disabled
        // This consumes gas and storage
    }

    // Implement all interfaces
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    
    // Conditionally implement extension interfaces
    #[abi(embed_v0)]
    impl SettingsImpl = SettingsComponent::SettingsImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ObjectivesImpl = TokenObjectivesComponent::TokenObjectivesImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl MultiGameImpl = MultiGameComponent::MultiGameImpl<ContractState>;
}

// ===== ANALYSIS =====
//
// Problems with this approach:
// 1. Storage overhead: ALL components allocate storage even if disabled
//    - Minimal token still has storage for settings, objectives, minter, etc.
//    - Each component adds ~10-20 storage slots
//    - Total overhead: ~100+ storage slots even if using none
//
// 2. Contract size: Including all components may exceed 5MB limit
//    - Each component adds code even if disabled
//    - Interface implementations can't be conditionally compiled
//
// 3. Runtime overhead: Every operation has runtime checks
//    - Each enabled check costs ~200 gas
//    - 4-6 checks per operation = ~1k gas overhead
//
// 4. Deployment cost: Higher due to larger contract size
//    - More code to deploy even if not used
//    - Higher initial gas cost
//
// 5. Interface confusion: Contract exposes all interfaces even if disabled
//    - Users might call settings methods when settings are disabled
//    - No compile-time safety
//
// Gas comparison for minimal token:
// - Enabled components: ~50k (base) + 1k (checks) + storage overhead = ~52k+
// - Hooks approach: ~50k (base) + 0 = ~50k
//
// Storage comparison:
// - Enabled components: ~100+ slots allocated
// - Hooks approach: ~10 slots for minimal token
//
// This approach is simpler but wasteful.