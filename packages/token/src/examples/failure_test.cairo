// Example: Optimized Token Contract using the new component system
// This demonstrates how to configure and use the modular components

use starknet::ContractAddress;

// Core imports
use openzeppelin_token::erc721::ERC721Component;
use openzeppelin_introspection::src5::SRC5Component;

// Game components imports
use crate::core::core_token::CoreTokenComponent;
use crate::extensions::minter::MinterComponent;
use crate::extensions::multi_game::MultiGameComponent;
use crate::extensions::objectives::ObjectivesComponent;
use crate::extensions::context::ContextComponent;
use crate::extensions::soulbound::SoulboundComponent;
use crate::extensions::renderer::RendererComponent;

use crate::core::noop_traits::{NoOpMultiGame};

use crate::config;

#[starknet::contract]
mod OptimizedTokenContract {
    use super::*;

    // ================================================================================================
    // COMPONENT DECLARATIONS
    // ================================================================================================

    // Core components (always included)
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);

    // Optional components (only included if enabled)
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    // component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
    component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    component!(path: ContextComponent, storage: context, event: ContextEvent);
    component!(path: SoulboundComponent, storage: soulbound, event: SoulboundEvent);
    component!(path: RendererComponent, storage: renderer, event: RendererEvent);

    // ================================================================================================
    // STORAGE
    // ================================================================================================

    #[storage]
    struct Storage {
        // Core storage (always included)
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        core_token: CoreTokenComponent::Storage,
        // Optional storage (only included if features are enabled)
        #[substorage(v0)]
        minter: MinterComponent::Storage,
        // #[substorage(v0)]
        // multi_game: MultiGameComponent::Storage,
        #[substorage(v0)]
        objectives: ObjectivesComponent::Storage,
        #[substorage(v0)]
        context: ContextComponent::Storage,
        #[substorage(v0)]
        soulbound: SoulboundComponent::Storage,
        #[substorage(v0)]
        renderer: RendererComponent::Storage,
    }

    // ================================================================================================
    // EVENTS
    // ================================================================================================

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        CoreTokenEvent: CoreTokenComponent::Event,
        #[flat]
        MinterEvent: MinterComponent::Event,
        // #[flat]
        // MultiGameEvent: MultiGameComponent::Event,
        #[flat]
        ObjectivesEvent: ObjectivesComponent::Event,
        #[flat]
        ContextEvent: ContextComponent::Event,
        #[flat]
        SoulboundEvent: SoulboundComponent::Event,
        #[flat]
        RendererEvent: RendererComponent::Event,
    }

    // ================================================================================================
    // COMPONENT IMPLEMENTATIONS
    // ================================================================================================

    // Core implementations (always included)
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl CoreTokenImpl = CoreTokenComponent::CoreTokenImpl<ContractState>;

    // Optional implementations (conditional based on feature flags)
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;
    // #[abi(embed_v0)]
    // impl MultiGameImpl = MultiGameComponent::MultiGameImpl<ContractState>;
    #[abi(embed_v0)]
    impl ObjectivesImpl = ObjectivesComponent::ObjectivesImpl<ContractState>;

    // Internal implementations
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    impl CoreTokenInternalImpl = CoreTokenComponent::InternalImpl<ContractState>;
    impl MinterInternalImpl = MinterComponent::InternalImpl<ContractState>;
    impl MultiGameInternalImpl = MultiGameComponent::InternalImpl<ContractState>;
    impl ObjectivesInternalImpl = ObjectivesComponent::InternalImpl<ContractState>;
    impl ContextInternalImpl = ContextComponent::InternalImpl<ContractState>;
    impl SoulboundInternalImpl = SoulboundComponent::InternalImpl<ContractState>;
    impl RendererInternalImpl = RendererComponent::InternalImpl<ContractState>;

    // ================================================================================================
    // OPTIONAL TRAIT IMPLEMENTATIONS
    // ================================================================================================

    // These implementations are chosen based on compile-time feature flags
    // If a feature is disabled, the NoOp implementation is used (zero runtime cost)

    impl MinterOptionalImpl = MinterComponent::MinterOptionalImpl<ContractState>;
    impl MultiGameOptionalImpl = MultiGameComponent::MultiGameOptionalImpl<ContractState>;
    impl ObjectivesOptionalImpl = ObjectivesComponent::ObjectivesOptionalImpl<ContractState>;
    impl ContextOptionalImpl = ContextComponent::ContextOptionalImpl<ContractState>;
    impl SoulboundOptionalImpl = SoulboundComponent::SoulboundOptionalImpl<ContractState>;
    impl RendererOptionalImpl = RendererComponent::RendererOptionalImpl<ContractState>;

    // Alternative: Use NoOp implementations for disabled features
    // impl MinterOptionalImpl = NoOpMinter<ContractState>;
    // impl MultiGameOptionalImpl = NoOpMultiGame<ContractState>;
    // etc.

    // ================================================================================================
    // ERC721 HOOKS
    // ================================================================================================

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // Soulbound validation (compile-time optimized)
            if config::SOULBOUND_ENABLED {
                let contract_state = self.get_contract();
                // Check if transfer is allowed for soulbound tokens
                if !contract_state.check_transfer_allowed(token_id.try_into().unwrap()) {
                    panic!("Token is soulbound and cannot be transferred");
                }
            }
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) { // Post-transfer logic can be added here
        }
    }

    // ================================================================================================
    // CONSTRUCTOR
    // ================================================================================================

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: Option<ContractAddress>,
        owner: ContractAddress,
    ) {
        // Initialize core components
        self.erc721.initializer(name, symbol, base_uri);
        // SRC5 doesn't require initialization
        self.core_token.initializer(game_address);

        // Initialize optional components (compile-time optimized)
        if config::MINTER_ENABLED {
            self.minter.initializer();
        }
        // if config::MULTI_GAME_ENABLED {
        //     self.multi_game.initializer();
        // }
        if config::OBJECTIVES_ENABLED {
            self.objectives.initializer();
        }
        if config::CONTEXT_ENABLED {
            self.context.initializer();
        }
        if config::SOULBOUND_ENABLED {
            self.soulbound.initializer();
        }
        if config::RENDERER_ENABLED {
            self.renderer.initializer();
        }
    }
}
// ================================================================================================
// CONFIGURATION EXAMPLES
// ================================================================================================

// Example 1: Minimal Token (only core features)
// mod MinimalConfig {
//     pub const MINTER_ENABLED: bool = false;
//     pub const MULTI_GAME_ENABLED: bool = false;
//     pub const OBJECTIVES_ENABLED: bool = false;
//     pub const CONTEXT_ENABLED: bool = false;
//     pub const SOULBOUND_ENABLED: bool = false;
//     pub const RENDERER_ENABLED: bool = false;
// }

// Example 2: Full-Featured Token (all features enabled)
// mod FullFeaturedConfig {
//     pub const MINTER_ENABLED: bool = true;
//     pub const MULTI_GAME_ENABLED: bool = true;
//     pub const OBJECTIVES_ENABLED: bool = true;
//     pub const CONTEXT_ENABLED: bool = true;
//     pub const SOULBOUND_ENABLED: bool = true;
//     pub const RENDERER_ENABLED: bool = true;
// }

// Example 3: Gaming-Focused Token (selective features)
// mod GamingConfig {
//     pub const MINTER_ENABLED: bool = true;
//     pub const MULTI_GAME_ENABLED: bool = true;
//     pub const OBJECTIVES_ENABLED: bool = true;
//     pub const CONTEXT_ENABLED: bool = false;
//     pub const SOULBOUND_ENABLED: bool = false;
//     pub const RENDERER_ENABLED: bool = false;
// }


