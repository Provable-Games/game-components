#[starknet::component]
pub mod CoreTokenComponent {
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    
    use super::interface::ICoreToken;
    use super::traits::{
        OptionalMinter, OptionalMultiGame, OptionalContext, OptionalObjectives,
        OptionalSoulbound, OptionalRenderer
    };
    use crate::config;
    use crate::structs::{TokenMetadata, Lifecycle};
    use crate::libs::LifecycleTrait;
    
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::InternalTrait as ERC721InternalTrait;
    use openzeppelin_token::erc721::ERC721Component::ERC721Impl;

    #[storage]
    pub struct Storage {
        token_metadata: Map<u64, TokenMetadata>,
        token_player_names: Map<u64, ByteArray>,
        token_counter: u64,
        game_address: ContractAddress,
        token_base_uri: ByteArray,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenMinted: TokenMinted,
        TokenBurned: TokenBurned,
        GameUpdated: GameUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenMinted {
        #[key]
        pub token_id: u64,
        #[key]
        pub to: ContractAddress,
        #[key]
        pub game_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenBurned {
        #[key]
        pub token_id: u64,
        #[key]
        pub from: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameUpdated {
        #[key]
        pub token_id: u64,
        #[key]
        pub old_game_address: ContractAddress,
        #[key]
        pub new_game_address: ContractAddress,
    }

    #[embeddable_as(CoreTokenImpl)]
    pub impl CoreToken<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl MinterOpt: OptionalMinter<TContractState>,
        impl MultiGameOpt: OptionalMultiGame<TContractState>,
        impl ContextOpt: OptionalContext<TContractState>,
        impl ObjectivesOpt: OptionalObjectives<TContractState>,
        impl SoulboundOpt: OptionalSoulbound<TContractState>,
        impl RendererOpt: OptionalRenderer<TContractState>,
        +Drop<TContractState>,
    > of ICoreToken<ComponentState<TContractState>> {
        
        fn token_metadata(self: @ComponentState<TContractState>, token_id: u64) -> TokenMetadata {
            self.token_metadata.entry(token_id).read()
        }

        fn is_playable(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.lifecycle.is_active()
        }

        fn settings_id(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.settings_id
        }

        fn player_name(self: @ComponentState<TContractState>, token_id: u64) -> ByteArray {
            self.token_player_names.entry(token_id).read()
        }

        fn objectives_count(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.objectives_count
        }

        fn minted_by(self: @ComponentState<TContractState>, token_id: u64) -> u64 {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.minted_by
        }

        fn game_address(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.game_address
        }

        fn is_soulbound(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.is_soulbound
        }

        fn renderer_address(self: @ComponentState<TContractState>, token_id: u64) -> ContractAddress {
            let metadata = self.token_metadata.entry(token_id).read();
            metadata.renderer_address
        }

        fn token_uri(self: @ComponentState<TContractState>, token_id: u64) -> ByteArray {
            // Simple token URI implementation - concatenate base URI with token ID
            let base_uri = self.token_base_uri.read();
            let mut token_uri = base_uri.clone();
            // TODO: Implement proper number to string conversion
            token_uri
        }

        fn mint(
            ref self: ComponentState<TContractState>,
            game_address: Option<ContractAddress>,
            player_name: Option<ByteArray>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_ids: Option<Span<u32>>,
            context: Option<felt252>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            let caller = get_caller_address();
            let token_id = self.token_counter.read() + 1;
            self.token_counter.write(token_id);
            
            // Use the provided game address or fall back to the component's game address
            let final_game_address = game_address.unwrap_or(self.game_address.read());
            
            // Handle minter tracking if enabled
            let mut contract_self = self.get_contract_mut();
            let minted_by = MinterOpt::on_mint_with_minter(ref contract_self, caller);
            
            // Handle objectives if provided
            if let Option::Some(objective_ids) = objective_ids {
                let mut contract_self = self.get_contract_mut();
                ObjectivesOpt::set_token_objectives(ref contract_self, token_id, objective_ids);
            }
            
            // Handle context if provided
            if let Option::Some(context_data) = context {
                let mut contract_self = self.get_contract_mut();
                ContextOpt::store_context(ref contract_self, token_id, final_game_address, context_data);
            }
            
            // Handle soulbound if enabled
            if soulbound {
                let mut contract_self = self.get_contract_mut();
                SoulboundOpt::set_soulbound_status(ref contract_self, token_id, true);
            }
            
            // Handle renderer if provided
            if let Option::Some(renderer) = renderer_address {
                let mut contract_self = self.get_contract_mut();
                RendererOpt::set_token_renderer(ref contract_self, token_id, renderer);
            }
            
            // Create token metadata
            let metadata = TokenMetadata {
                token_id,
                game_address: final_game_address,
                player_name: player_name.clone().unwrap_or(""),
                image: "",
                minted_by,
                lifecycle: LifecycleTrait::new(),
                settings_id: settings_id.unwrap_or(0),
                objectives_count: objective_ids.map(|ids| ids.len()).unwrap_or(0),
                is_soulbound: soulbound,
                renderer_address: renderer_address.unwrap_or(starknet::contract_address_const::<0>()),
            };
            
            self.token_metadata.entry(token_id).write(metadata);
            
            // Set player name if provided
            if let Option::Some(name) = player_name {
                self.token_player_names.entry(token_id).write(name);
            }
            
            // Mint the ERC721 token
            let mut erc721_component = ERC721::get_component_mut(ref self.get_contract_mut());
            erc721_component.mint(to, token_id.into());
            
            self.emit(TokenMinted {
                token_id,
                to,
                game_address: final_game_address,
            });
            
            token_id
        }
        
        fn burn(ref self: ComponentState<TContractState>, token_id: u64) {
            let mut erc721_component = ERC721::get_component_mut(ref self.get_contract_mut());
            let owner = erc721_component.owner_of(token_id.into());
            erc721_component.burn(token_id.into());
            
            // Clear metadata
            let default_metadata: TokenMetadata = Default::default();
            self.token_metadata.entry(token_id).write(default_metadata);
            self.token_player_names.entry(token_id).write("");
            
            self.emit(TokenBurned {
                token_id,
                from: owner,
            });
        }

        fn update_game(ref self: ComponentState<TContractState>, token_id: u64) {
            let mut metadata = self.token_metadata.entry(token_id).read();
            let old_game_address = metadata.game_address;
            let new_game_address = self.game_address.read();
            
            metadata.game_address = new_game_address;
            self.token_metadata.entry(token_id).write(metadata);
            
            self.emit(GameUpdated {
                token_id,
                old_game_address,
                new_game_address,
            });
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl MinterOpt: OptionalMinter<TContractState>,
        impl MultiGameOpt: OptionalMultiGame<TContractState>,
        impl ContextOpt: OptionalContext<TContractState>,
        impl ObjectivesOpt: OptionalObjectives<TContractState>,
        impl SoulboundOpt: OptionalSoulbound<TContractState>,
        impl RendererOpt: OptionalRenderer<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        
        fn initializer(
            ref self: ComponentState<TContractState>, 
            game_address: Option<ContractAddress>
        ) {
            // Register token interface
            let mut src5_component = SRC5::get_component_mut(ref self.get_contract_mut());
            src5_component.register_interface(crate::interface::IMINIGAME_TOKEN_ID);
            
            // Set game address if provided
            if let Option::Some(game_address) = game_address {
                self.game_address.write(game_address);
            }
            
            // Set default base URI
            self.token_base_uri.write("https://example.com/token/");
        }
    }
} 