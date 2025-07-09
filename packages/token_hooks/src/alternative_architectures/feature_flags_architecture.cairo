// Alternative Architecture #1: Feature Flags with Runtime Checks
// This approach uses feature flags to enable/disable functionality at runtime

use starknet::ContractAddress;
use game_components_minigame::interface::{
    IMinigameTokenDataDispatcher, IMinigameTokenDataDispatcherTrait,
};

#[derive(Drop, Serde, starknet::Store)]
struct FeatureFlags {
    has_settings: bool,
    has_objectives: bool,
    has_minter: bool,
    has_multi_game: bool,
    has_renderer: bool,
    has_soulbound: bool,
}

#[starknet::component]
mod TokenWithFeatureFlagsComponent {
    use super::FeatureFlags;
    use crate::interface::IMinigameToken;
    use crate::structs::{TokenMetadata, Lifecycle};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use openzeppelin_token::erc721::ERC721Component;

    #[storage]
    struct Storage {
        features: FeatureFlags,
        token_counter: u64,
        token_metadata: Map<u64, TokenMetadata>,
        game_address: ContractAddress,
        // Optional storage - always present even if not used
        settings_registry: Map<ContractAddress, Map<u32, bool>>,
        objectives_registry: Map<u64, Span<u32>>,
        minter_registry: Map<ContractAddress, u64>,
        multi_game_registry: Map<u64, ContractAddress>,
    }

    #[embeddable_as(TokenWithFeatureFlagsImpl)]
    impl TokenWithFeatureFlags<
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
            let features = self.features.read();
            let caller_address = get_caller_address();
            
            // Runtime checks for each feature
            let mut game_id = 0_u64;
            let mut validated_settings_id = 0_u32;
            let mut objectives_count = 0_u32;
            
            // Problem: Runtime overhead for each check
            if features.has_settings && settings_id.is_some() {
                // Validate settings
                validated_settings_id = settings_id.unwrap();
                // More validation logic...
            }
            
            if features.has_objectives && objective_ids.is_some() {
                // Validate objectives
                let objs = objective_ids.unwrap();
                objectives_count = objs.len();
                // Store objectives
                self.objectives_registry.entry(self.token_counter.read() + 1).write(objs);
            }
            
            if features.has_multi_game && game_address.is_some() {
                // Register game
                game_id = 1; // Simplified
                self.multi_game_registry.entry(self.token_counter.read() + 1).write(game_address.unwrap());
            }
            
            // Core mint logic
            let token_id = self.token_counter.read() + 1;
            self.token_counter.write(token_id);
            
            let metadata = TokenMetadata {
                game_id,
                minted_at: get_block_timestamp(),
                settings_id: validated_settings_id,
                lifecycle: Lifecycle { start: start.unwrap_or(0), end: end.unwrap_or(0) },
                minted_by: 0,
                soulbound: features.has_soulbound && soulbound,
                game_over: false,
                completed_all_objectives: false,
                has_context: context.is_some(),
                objectives_count,
            };
            
            self.token_metadata.entry(token_id).write(metadata);
            
            // Mint ERC721
            let mut erc721 = get_dep_component_mut!(ref self, ERC721);
            erc721.mint(to, token_id.into());
            
            // Post-mint runtime checks
            if features.has_minter {
                self.minter_registry.entry(caller_address).write(token_id);
            }
            
            token_id
        }

        fn update_game(ref self: ComponentState<TContractState>, token_id: u64) {
            let features = self.features.read();
            let token_metadata = self.token_metadata.entry(token_id).read();
            
            // Determine game address with runtime check
            let game_address = if features.has_multi_game && token_metadata.game_id > 0 {
                self.multi_game_registry.entry(token_id).read()
            } else {
                self.game_address.read()
            };
            
            // Get game state
            let dispatcher = IMinigameTokenDataDispatcher { contract_address: game_address };
            let game_over = dispatcher.game_over(token_id);
            let score = dispatcher.score(token_id);
            
            // Check objectives with runtime check
            let mut completed_all_objectives = false;
            if features.has_objectives && token_metadata.objectives_count > 0 {
                // Check objectives completion
                // ... objectives logic
                completed_all_objectives = true; // Simplified
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
}

// ===== ANALYSIS =====
// 
// Problems with this approach:
// 1. Runtime overhead: Every operation has if-checks for features (~200 gas each)
// 2. Storage overhead: All optional storage is included even if not used
// 3. Code complexity: Core logic mixed with feature checks
// 4. Not extensible: Adding new features requires modifying core component
// 5. Testing complexity: Need to test all feature flag combinations
//
// Gas cost comparison:
// - Feature flags approach: ~50k (base) + 1k (flag checks) = ~51k for minimal
// - Hooks approach: ~50k (base) + 0 (compiled away) = ~50k for minimal
//
// Storage comparison:
// - Feature flags: Always includes all storage fields
// - Hooks: Only includes storage for used components