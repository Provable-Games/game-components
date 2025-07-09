//! Full Featured Token Contract Example
//!
//! This demonstrates direct embedding with multiple optional features enabled.
//! Perfect for complex gaming platforms that need comprehensive token functionality.

use core::num::traits::Zero;
use starknet::ContractAddress;
use game_components_token::token::TokenComponent;
use game_components_token::interface::IMinigameToken;
use game_components_token::callbacks::{
    DefaultTokenContextCallback, DefaultTokenSoulboundCallback,
    DefaultTokenRendererCallback
};
use game_components_token::extensions::minter::minter::MinterComponent;
use game_components_token::extensions::multi_game::multi_game::MultiGameComponent;
use game_components_token::extensions::objectives::objectives::TokenObjectivesComponent;
use game_components_token::structs::TokenMetadata;
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::erc721::ERC721Component;

#[starknet::contract]
pub mod FullFeaturedTokenContract {
    use super::*;

    // Component declarations
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
    component!(path: TokenObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        token: TokenComponent::Storage,
        #[substorage(v0)]
        minter: MinterComponent::Storage,
        #[substorage(v0)]
        multi_game: MultiGameComponent::Storage,
        #[substorage(v0)]
        objectives: TokenObjectivesComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        TokenEvent: TokenComponent::Event,
        #[flat]
        MinterEvent: MinterComponent::Event,
        #[flat]
        MultiGameEvent: MultiGameComponent::Event,
        #[flat]
        ObjectivesEvent: TokenObjectivesComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
    }

    // ✨ DIRECT EMBEDDING with multiple features enabled
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;

    // 🔑 CALLBACK IMPLEMENTATIONS - Multiple features ENABLED
    // ✅ MinterCallback: ENABLED (uses MinterComponent)
    impl MinterCallback of game_components_token::interface::TokenMinterCallback<ContractState> {
        fn on_mint_with_minter(ref self: ContractState, minter_address: ContractAddress) -> u64 {
            self.minter.add_minter(minter_address)
        }
    }

    // ✅ MultiGameCallback: ENABLED (uses MultiGameComponent)
    impl MultiGameCallback of game_components_token::interface::TokenMultiGameCallback<ContractState> {
        fn get_game_id_from_address(ref self: ContractState, game_address: ContractAddress) -> u64 {
            self.multi_game.get_game_id_from_address(game_address)
        }
        
        fn get_game_metadata(ref self: ContractState, game_id: u64) -> game_components_token::extensions::multi_game::structs::GameMetadata {
            self.multi_game.get_game_metadata(game_id)
        }
        
        fn get_game_address_from_id(ref self: ContractState, game_id: u64) -> ContractAddress {
            self.multi_game.get_game_address_from_id(game_id)
        }
    }

    // ✅ ObjectivesCallback: ENABLED (uses TokenObjectivesComponent)
    impl ObjectivesCallback of game_components_token::interface::TokenObjectivesCallback<ContractState> {
        fn get_objective(ref self: ContractState, token_id: u64, objective_index: u32) -> game_components_token::extensions::objectives::structs::TokenObjective {
            self.objectives.get_objective(token_id, objective_index)
        }
        
        fn set_objective(ref self: ContractState, token_id: u64, objective_index: u32, objective: game_components_token::extensions::objectives::structs::TokenObjective) {
            self.objectives.set_objective(token_id, objective_index, objective)
        }
    }

    // ❌ Remaining callbacks: DISABLED (use defaults)
    impl ContextCallback = DefaultTokenContextCallback<ContractState>;
    impl SoulboundCallback = DefaultTokenSoulboundCallback<ContractState>;
    impl RendererCallback = DefaultTokenRendererCallback<ContractState>;

    // Standard component implementations
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;

    // Internal implementations
    impl TokenInternalImpl = TokenComponent::InternalImpl<ContractState>;
    impl MinterInternalImpl = MinterComponent::InternalImpl<ContractState>;
    impl MultiGameInternalImpl = MultiGameComponent::InternalImpl<ContractState>;
    impl ObjectivesInternalImpl = TokenObjectivesComponent::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: Option<ContractAddress>,
    ) {
        // Initialize ERC721
        self.erc721.initializer(name, symbol, base_uri);
        
        // Initialize token component
        self.token.initializer(game_address);
        
        // Initialize feature components
        self.minter.initializer();
        self.multi_game.initializer();
        self.objectives.initializer();
    }

    // ERC721 Hooks implementation
    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // Check if this is a transfer (not a mint) and if token is soulbound
            if !auth.is_zero() && !to.is_zero() { // This is a transfer, not a mint
                // Access the contract state to call get_token_metadata through the token component
                let contract = self.get_contract();
                let token_metadata: TokenMetadata = contract.token
                    .get_token_metadata(token_id.try_into().unwrap());

                assert!(
                    !token_metadata.soulbound,
                    "MinigameToken Soulbound: Token is soulbound and cannot be transferred",
                );
            }
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // No additional logic needed for after_update
        }
    }
}

//================================================================================================
// USAGE NOTES - Multiple Features Enabled
//================================================================================================

// ✅ This is the most complete example using direct embedding!
// 
// 📊 Features in this example:
// - ✅ Minter tracking: ENABLED (tracks who minted which tokens)
// - ✅ Multi-game support: ENABLED (supports multiple games in one contract)
// - ✅ Token objectives: ENABLED (achievement/quest system)
// - ❌ Context: DISABLED (could be enabled for additional metadata)
// - ❌ Soulbound: DISABLED (could be enabled for non-transferable tokens)
// - ❌ Renderer: DISABLED (could be enabled for custom rendering)

//================================================================================================
// DIRECT EMBEDDING PATTERN - COMPLETE EXAMPLE
//================================================================================================

// 🎯 This shows the full power of the callback pattern with direct embedding:

// 1️⃣ ONE line for interface embedding:
//    #[abi(embed_v0)]
//    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;

// 2️⃣ Selective feature enablement via callback implementations:
//    impl MinterCallback of TokenMinterCallback<ContractState> { /* component logic */ }
//    impl MultiGameCallback of TokenMultiGameCallback<ContractState> { /* component logic */ }
//    impl ObjectivesCallback of TokenObjectivesCallback<ContractState> { /* component logic */ }
//    impl ContextCallback = DefaultTokenContextCallback<ContractState>;  // disabled

// 3️⃣ Component initialization:
//    self.minter.initializer();
//    self.multi_game.initializer();
//    self.objectives.initializer();

//================================================================================================
// COMPARISON WITH OLD APPROACH
//================================================================================================

// 🆚 OLD WAY (manual interface implementation):
// #[abi(embed_v0)]
// impl TokenImpl of IMinigameToken<ContractState> {
//     fn settings_id(self: @ContractState, token_id: u64) -> u32 { self.token.settings_id(token_id) }
//     fn token_metadata(self: @ContractState, token_id: u64) -> TokenMetadata { self.token.token_metadata(token_id) }
//     fn is_playable(self: @ContractState, token_id: u64) -> bool { self.token.is_playable(token_id) }
//     fn player_name(self: @ContractState, token_id: u64) -> ByteArray { self.token.player_name(token_id) }
//     fn mint(ref self: ContractState, /* 10+ parameters */) -> u64 { self.token.mint(/* 10+ parameters */) }
//     fn update_game(ref self: ContractState, token_id: u64) { self.token.update_game(token_id) }
// }

// ✅ NEW WAY (direct embedding):
// #[abi(embed_v0)]
// impl TokenImpl = TokenComponent::TokenImpl<ContractState>;

//================================================================================================
// FEATURE MATRIX
//================================================================================================

// | Feature          | Simple Token | Advanced Token | Full Featured Token |
// |------------------|------------- |----------------|---------------------|
// | Direct Embedding | ✅           | ✅             | ✅                  |
// | Minter Tracking  | ❌           | ✅             | ✅                  |
// | Multi-Game       | ❌           | ❌             | ✅                  |
// | Objectives       | ❌           | ❌             | ✅                  |
// | Context          | ❌           | ❌             | ❌                  |
// | Soulbound        | ❌           | ❌             | ❌                  |
// | Renderer         | ❌           | ❌             | ❌                  |

//================================================================================================
// BENEFITS OF THIS APPROACH
//================================================================================================

// ✅ Direct embedding (exactly what you wanted!)
// ✅ Callback pattern for flexibility
// ✅ Multiple features enabled simultaneously
// ✅ Clean, maintainable code
// ✅ No interface method duplication
// ✅ Type-safe feature switching
// ✅ Modular component architecture
// ✅ Automatic SRC5 interface registration
// ✅ Easy feature addition/removal
// ✅ Extensible for future features 