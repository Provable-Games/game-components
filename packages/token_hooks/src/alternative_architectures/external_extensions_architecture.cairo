// Alternative Architecture #2: External Extensions with Cross-Contract Calls
// This approach uses external contracts for each extension

use starknet::ContractAddress;

// Extension interface that all extensions must implement
#[starknet::interface]
trait ITokenExtension<TContractState> {
    fn on_before_mint(
        self: @TContractState,
        to: ContractAddress,
        token_id: u64,
        game_address: Option<ContractAddress>,
        settings_id: Option<u32>,
        objective_ids: Option<Span<u32>>,
    ) -> (u64, u32, u32);
    
    fn on_after_mint(
        self: @TContractState,
        to: ContractAddress,
        token_id: u64,
        caller_address: ContractAddress,
    );
    
    fn on_before_update_game(
        self: @TContractState,
        token_id: u64,
        token_metadata: crate::structs::TokenMetadata,
    ) -> ContractAddress;
    
    fn on_after_update_game(
        self: @TContractState,
        token_id: u64,
    ) -> bool;
}

#[starknet::component]
mod TokenWithExternalExtensionsComponent {
    use super::{ITokenExtension, ITokenExtensionDispatcher, ITokenExtensionDispatcherTrait};
    use crate::interface::IMinigameToken;
    use crate::structs::{TokenMetadata, Lifecycle};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use openzeppelin_token::erc721::ERC721Component;

    #[storage]
    struct Storage {
        token_counter: u64,
        token_metadata: Map<u64, TokenMetadata>,
        game_address: ContractAddress,
        // Extension registry - maps extension type to contract address
        extensions: Map<felt252, ContractAddress>,
    }

    mod ExtensionTypes {
        const SETTINGS: felt252 = 'SETTINGS';
        const OBJECTIVES: felt252 = 'OBJECTIVES';
        const MINTER: felt252 = 'MINTER';
        const MULTI_GAME: felt252 = 'MULTI_GAME';
    }

    #[embeddable_as(TokenWithExternalExtensionsImpl)]
    impl TokenWithExternalExtensions<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameToken<ComponentState<TContractState>> {
        fn mint(
            ref self: ComponentState<TContractState>,
            game_address: Option<ContractAddress>,
            player_name: Option<ByteArray>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_ids: Option<Span<u32>>,
            context: Option<game_components_metagame::extensions::context::structs::GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            let caller_address = get_caller_address();
            let token_id = self.token_counter.read() + 1;
            
            // Default values
            let mut game_id = 0_u64;
            let mut validated_settings_id = 0_u32;
            let mut objectives_count = 0_u32;
            
            // Call all registered extensions for before_mint
            // Problem: Each call costs ~15k gas for cross-contract communication
            
            // Check settings extension
            let settings_ext_addr = self.extensions.entry(ExtensionTypes::SETTINGS).read();
            if settings_ext_addr.is_non_zero() {
                let settings_ext = ITokenExtensionDispatcher { contract_address: settings_ext_addr };
                let (ext_game_id, ext_settings_id, ext_obj_count) = settings_ext.on_before_mint(
                    to, token_id, game_address, settings_id, objective_ids
                );
                validated_settings_id = ext_settings_id;
                // Gas cost: +15k for call + extension logic
            }
            
            // Check objectives extension
            let objectives_ext_addr = self.extensions.entry(ExtensionTypes::OBJECTIVES).read();
            if objectives_ext_addr.is_non_zero() {
                let objectives_ext = ITokenExtensionDispatcher { contract_address: objectives_ext_addr };
                let (ext_game_id, ext_settings_id, ext_obj_count) = objectives_ext.on_before_mint(
                    to, token_id, game_address, settings_id, objective_ids
                );
                objectives_count = ext_obj_count;
                // Gas cost: +15k for call + extension logic
            }
            
            // Core mint logic
            self.token_counter.write(token_id);
            
            let metadata = TokenMetadata {
                game_id,
                minted_at: get_block_timestamp(),
                settings_id: validated_settings_id,
                lifecycle: Lifecycle { start: start.unwrap_or(0), end: end.unwrap_or(0) },
                minted_by: 0,
                soulbound,
                game_over: false,
                completed_all_objectives: false,
                has_context: context.is_some(),
                objectives_count,
            };
            
            self.token_metadata.entry(token_id).write(metadata);
            
            // Mint ERC721
            let mut erc721 = get_dep_component_mut!(ref self, ERC721);
            erc721.mint(to, token_id.into());
            
            // Call all extensions for after_mint
            // Minter extension
            let minter_ext_addr = self.extensions.entry(ExtensionTypes::MINTER).read();
            if minter_ext_addr.is_non_zero() {
                let minter_ext = ITokenExtensionDispatcher { contract_address: minter_ext_addr };
                minter_ext.on_after_mint(to, token_id, caller_address);
                // Gas cost: +15k for call + extension logic
            }
            
            token_id
        }

        fn update_game(ref self: ComponentState<TContractState>, token_id: u64) {
            let token_metadata = self.token_metadata.entry(token_id).read();
            
            // Get game address from multi-game extension if available
            let mut game_address = self.game_address.read();
            let multi_game_ext_addr = self.extensions.entry(ExtensionTypes::MULTI_GAME).read();
            if multi_game_ext_addr.is_non_zero() {
                let multi_game_ext = ITokenExtensionDispatcher { contract_address: multi_game_ext_addr };
                game_address = multi_game_ext.on_before_update_game(token_id, token_metadata);
                // Gas cost: +15k for call
            }
            
            // Get game state
            let dispatcher = game_components_minigame::interface::IMinigameTokenDataDispatcher { 
                contract_address: game_address 
            };
            let game_over = dispatcher.game_over(token_id);
            let score = dispatcher.score(token_id);
            
            // Check objectives via extension
            let mut completed_all_objectives = false;
            let objectives_ext_addr = self.extensions.entry(ExtensionTypes::OBJECTIVES).read();
            if objectives_ext_addr.is_non_zero() {
                let objectives_ext = ITokenExtensionDispatcher { contract_address: objectives_ext_addr };
                completed_all_objectives = objectives_ext.on_after_update_game(token_id);
                // Gas cost: +15k for call
            }
            
            // Update metadata
            self.token_metadata.entry(token_id).write(
                TokenMetadata {
                    game_over,
                    completed_all_objectives,
                    ..token_metadata
                }
            );
        }

        // Other interface methods...
        fn settings_id(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            self.token_metadata.entry(token_id).read().settings_id
        }

        fn token_metadata(self: @ComponentState<TContractState>, token_id: u64) -> TokenMetadata {
            self.token_metadata.entry(token_id).read()
        }

        fn is_playable(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let metadata = self.token_metadata.entry(token_id).read();
            let active = metadata.lifecycle.is_playable(get_block_timestamp());
            active && !metadata.completed_all_objectives && !metadata.game_over
        }

        fn player_name(self: @ComponentState<TContractState>, token_id: u64) -> ByteArray {
            "" // Simplified
        }
    }
    
    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn register_extension(
            ref self: ComponentState<TContractState>,
            extension_type: felt252,
            extension_address: ContractAddress,
        ) {
            self.extensions.entry(extension_type).write(extension_address);
        }
    }
}

// Example extension contract
#[starknet::contract]
mod SettingsExtension {
    use super::{ITokenExtension, ContractAddress};
    use crate::structs::TokenMetadata;
    
    #[storage]
    struct Storage {
        valid_settings: Map<ContractAddress, Map<u32, bool>>,
    }
    
    #[abi(embed_v0)]
    impl TokenExtensionImpl of ITokenExtension<ContractState> {
        fn on_before_mint(
            self: @ContractState,
            to: ContractAddress,
            token_id: u64,
            game_address: Option<ContractAddress>,
            settings_id: Option<u32>,
            objective_ids: Option<Span<u32>>,
        ) -> (u64, u32, u32) {
            // Validate settings
            if let (Option::Some(game), Option::Some(settings)) = (game_address, settings_id) {
                assert!(
                    self.valid_settings.entry(game).entry(settings).read(),
                    "Invalid settings"
                );
                (0, settings, 0)
            } else {
                (0, 0, 0)
            }
        }
        
        fn on_after_mint(
            self: @ContractState,
            to: ContractAddress,
            token_id: u64,
            caller_address: ContractAddress,
        ) {
            // No post-mint logic for settings
        }
        
        fn on_before_update_game(
            self: @ContractState,
            token_id: u64,
            token_metadata: TokenMetadata,
        ) -> ContractAddress {
            // Not used by settings extension
            starknet::contract_address_const::<0>()
        }
        
        fn on_after_update_game(
            self: @ContractState,
            token_id: u64,
        ) -> bool {
            false
        }
    }
}

// ===== ANALYSIS =====
//
// Problems with this approach:
// 1. High gas overhead: Each extension call costs ~15k gas
//    - Minimal token with 0 extensions: ~50k gas
//    - Token with 4 extensions: ~50k + (4 * 15k * 2) = ~170k gas (+240% overhead)
// 2. Complex deployment: Need to deploy multiple contracts and register them
// 3. Security risks: External contracts could be malicious or upgradeable
// 4. Loss of type safety: Can't verify extensions implement correct logic at compile time
// 5. Storage inefficiency: Each extension needs its own storage contract
// 6. Harder to audit: Logic spread across multiple contracts
//
// Benefits:
// - Very flexible: Can add/remove extensions without redeploying token
// - Clean separation: Each extension is independent
// - Upgradeable: Can upgrade extensions separately
//
// But the gas overhead makes this impractical for most use cases.