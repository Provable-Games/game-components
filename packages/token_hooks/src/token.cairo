#[starknet::component]
pub mod TokenComponent {
    use crate::interface::{IMinigameToken, IMINIGAME_TOKEN_ID};
    use crate::structs::{TokenMetadata, Lifecycle};
    use crate::libs::lifecycle::LifecycleTrait;
    use game_components_minigame::interface::{
        IMinigameTokenDataDispatcher, IMinigameTokenDataDispatcherTrait,
    };
    
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc721::{
        ERC721Component, ERC721Component::{InternalImpl as ERC721InternalImpl},
    };

    // Hooks trait that contracts must implement or use default implementation
    pub trait TokenHooksTrait<TContractState> {
        fn before_mint(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            game_address: Option<ContractAddress>,
            settings_id: Option<u32>,
            objective_ids: Option<Span<u32>>,
        ) -> (u64, u32, u32);
        
        fn after_mint(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u64,
            caller_address: ContractAddress,
            game_address: Option<ContractAddress>,
            token_metadata: TokenMetadata,
        );
        
        fn before_update_game(
            ref self: ComponentState<TContractState>,
            token_id: u64,
            token_metadata: TokenMetadata,
        ) -> ContractAddress;
        
        fn after_update_game(
            ref self: ComponentState<TContractState>,
            token_id: u64,
        ) -> bool;
    }


    #[storage]
    pub struct Storage {
        pub token_counter: u64,
        pub token_metadata: Map<u64, TokenMetadata>,
        pub token_player_names: Map<u64, ByteArray>,
        pub game_address: ContractAddress // this is set if the token is not a multi game token
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ScoreUpdate: ScoreUpdate,
        MetadataUpdate: MetadataUpdate,
        TokenMinted: TokenMinted,
        // Also emit Owners event for compatibility
        Owners: Owners,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ScoreUpdate {
        pub token_id: u64,
        pub score: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MetadataUpdate {
        pub token_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenMinted {
        pub token_id: u64,
        pub to: ContractAddress,
        pub game_address: ContractAddress,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct Owners {
        pub token_id: u64,
        pub owner: ContractAddress,
        pub auth: ContractAddress,
    }

    #[embeddable_as(TokenImpl)]
    impl Token<
        TContractState,
        +HasComponent<TContractState>,
        impl Hooks: TokenHooksTrait<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameToken<ComponentState<TContractState>> {
        fn settings_id(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.settings_id
        }

        fn token_metadata(self: @ComponentState<TContractState>, token_id: u64) -> TokenMetadata {
            self.token_metadata.entry(token_id).read()
        }

        fn is_playable(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let token_metadata = self.token_metadata.entry(token_id).read();
            let active = token_metadata.lifecycle.is_playable(starknet::get_block_timestamp());
            active && !token_metadata.completed_all_objectives && !token_metadata.game_over
        }

        fn player_name(self: @ComponentState<TContractState>, token_id: u64) -> ByteArray {
            self.token_player_names.entry(token_id).read()
        }

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
            // Store original caller for after_mint hook
            let caller_address = get_caller_address();
            
            // Call before hook for validation and get processed values
            let (game_id, settings_id_validated, objectives_count) = Hooks::before_mint(
                ref self, to, game_address, settings_id, objective_ids
            );
            
            // Process lifecycle parameters
            let start_time = start.unwrap_or(0);
            let end_time = end.unwrap_or(0);
            
            // Create token metadata
            let metadata = TokenMetadata {
                game_id,
                minted_at: get_block_timestamp(),
                settings_id: settings_id_validated,
                lifecycle: Lifecycle { start: start_time, end: end_time },
                minted_by: 0, // Will be set by hooks if minter extension is used
                soulbound,
                game_over: false,
                completed_all_objectives: false,
                has_context: context.is_some(),
                objectives_count: objectives_count.try_into().unwrap(),
            };
            
            // Get next token ID
            let token_id = self.token_counter.read() + 1;
            self.token_metadata.entry(token_id).write(metadata);
            self.token_counter.write(token_id);
            
            // Set optional player name
            if let Option::Some(name) = player_name {
                self.token_player_names.entry(token_id).write(name);
            }
            
            // Mint ERC721 token
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            erc721_component.mint(to, token_id.into());
            
            // Call after hook - preserves original caller
            Hooks::after_mint(ref self, to, token_id, caller_address, game_address, metadata);
            
            self.emit(TokenMinted { token_id, to, game_address: game_address.unwrap_or(self.game_address.read()) });
            
            token_id
        }

        fn update_game(ref self: ComponentState<TContractState>, token_id: u64) {
            // Verify token exists
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            assert!(
                erc721_component.exists(token_id.into()),
                "MinigameToken: Token id {} not minted",
                token_id,
            );
            
            // Get token metadata - only read once for gas optimization
            let token_metadata: TokenMetadata = self.token_metadata.entry(token_id).read();
            
            // Call before hook to get the correct game address
            // This allows multi-game tokens to return the right address without extra storage reads
            let game_address = Hooks::before_update_game(ref self, token_id, token_metadata);
            
            // Get game state
            let minigame_token_data_dispatcher = IMinigameTokenDataDispatcher {
                contract_address: game_address,
            };
            let game_over = minigame_token_data_dispatcher.game_over(token_id);
            let score = minigame_token_data_dispatcher.score(token_id);
            
            // Call after hook to handle objectives and multi-game logic
            let completed_all_objectives = Hooks::after_update_game(ref self, token_id);
            
            // Only update metadata if game state changed
            if (completed_all_objectives || game_over) {
                self.token_metadata.entry(token_id).write(
                    TokenMetadata {
                        game_id: token_metadata.game_id,
                        minted_by: token_metadata.minted_by,
                        minted_at: token_metadata.minted_at,
                        settings_id: token_metadata.settings_id,
                        lifecycle: token_metadata.lifecycle,
                        soulbound: token_metadata.soulbound,
                        game_over,
                        completed_all_objectives,
                        has_context: token_metadata.has_context,
                        objectives_count: token_metadata.objectives_count,
                    },
                );
            }
            
            // Emit events
            self.emit(ScoreUpdate { token_id, score: score.into() });
            self.emit(MetadataUpdate { token_id });
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Hooks: TokenHooksTrait<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>, game_address: Option<ContractAddress>,
        ) {
            // Register token interface
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_TOKEN_ID);
            match game_address {
                Option::Some(game_address) => { self.game_address.write(game_address); },
                Option::None => {},
            }
        }

        fn get_token_metadata(
            self: @ComponentState<TContractState>, token_id: u64,
        ) -> TokenMetadata {
            self.token_metadata.entry(token_id).read()
        }
        
        fn set_token_metadata(
            ref self: ComponentState<TContractState>, 
            token_id: u64,
            metadata: TokenMetadata
        ) {
            self.token_metadata.entry(token_id).write(metadata);
        }

        fn assert_token_ownership(self: @ComponentState<TContractState>, token_id: u64) {
            let erc721_component = get_dep_component!(self, ERC721);
            let token_owner = erc721_component._owner_of(token_id.into());
            assert!(
                token_owner == starknet::get_caller_address(),
                "Caller is not owner of token {}",
                token_id,
            );
        }

        fn assert_playable(self: @ComponentState<TContractState>, token_id: u64) {
            let metadata = self.token_metadata.entry(token_id).read();
            let active = metadata.lifecycle.is_playable(starknet::get_block_timestamp());
            assert!(
                active && !metadata.completed_all_objectives && !metadata.game_over,
                "MinigameToken: Token {} is not playable",
                token_id
            )
        }

        fn emit_score_update(ref self: ComponentState<TContractState>, token_id: u64, score: u64) {
            self.emit(ScoreUpdate { token_id, score });
        }

        fn emit_metadata_update(ref self: ComponentState<TContractState>, token_id: u64) {
            self.emit(MetadataUpdate { token_id });
        }
        
        fn emit_owners(
            ref self: ComponentState<TContractState>, 
            token_id: u64, 
            owner: ContractAddress,
            auth: ContractAddress
        ) {
            self.emit(Owners { token_id, owner, auth });
        }
    }
}