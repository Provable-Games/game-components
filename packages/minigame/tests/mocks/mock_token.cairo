use starknet::ContractAddress;
use game_components_token::structs::{TokenMetadata, Lifecycle};
use game_components_metagame::extensions::context::structs::GameContextDetails;

// Simple mock token contract that implements the minimum required interfaces
#[starknet::contract]
pub mod MockToken {
    use super::{ContractAddress, TokenMetadata, Lifecycle, GameContextDetails};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess
    };
    use game_components_token::interface::IMinigameToken;
    use game_components_token::extensions::multi_game::interface::IMinigameTokenMultiGame;
    use game_components_token::extensions::multi_game::structs::GameMetadata;
    
    #[storage]
    struct Storage {
        owners: Map<u64, ContractAddress>,
        playable: Map<u64, bool>,
        game_over: Map<u64, bool>,
        player_names: Map<u64, ByteArray>,
        settings_ids: Map<u64, u32>,
        next_token_id: u64,
        registered_games: Map<ContractAddress, bool>,
        game_count: u64,
    }
    
    // IMinigameToken implementation
    #[abi(embed_v0)]
    impl MinigameTokenImpl of IMinigameToken<ContractState> {
        fn token_metadata(self: @ContractState, token_id: u64) -> TokenMetadata {
            TokenMetadata {
                game_id: 1,
                minted_at: 1000,
                settings_id: self.settings_ids.read(token_id),
                lifecycle: Lifecycle { start: 0, end: 0 },
                minted_by: 1,
                soulbound: false,
                game_over: self.game_over.read(token_id),
                completed_all_objectives: false,
                has_context: false,
                objectives_count: 0,
            }
        }
        
        fn is_playable(self: @ContractState, token_id: u64) -> bool {
            self.playable.read(token_id)
        }
        
        fn settings_id(self: @ContractState, token_id: u64) -> u32 {
            self.settings_ids.read(token_id)
        }
        
        fn player_name(self: @ContractState, token_id: u64) ->  ByteArray {
            self.player_names.read(token_id)
        }
        
        fn mint(
            ref self: ContractState,
            game_address: Option<ContractAddress>,
            player_name: Option<ByteArray>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_ids: Option<Span<u32>>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            let token_id = self.next_token_id.read();
            self.next_token_id.write(token_id + 1);
            
            self.owners.write(token_id, to);
            self.playable.write(token_id, true);
            self.game_over.write(token_id, false);
            
            if let Option::Some(name) = player_name {
                self.player_names.write(token_id, name);
            }
            
            if let Option::Some(id) = settings_id {
                self.settings_ids.write(token_id, id);
            }
            
            token_id
        }
        
        fn update_game(ref self: ContractState, token_id: u64) {
            // Mock implementation - could track update count if needed
        }
    }
    
    // IMinigameTokenMultiGame implementation
    #[abi(embed_v0)]
    impl MultiGameImpl of IMinigameTokenMultiGame<ContractState> {
        fn game_count(self: @ContractState) -> u64 {
            self.game_count.read()
        }
        
        fn game_id_from_address(self: @ContractState, contract_address: ContractAddress) -> u64 {
            1 // Mock implementation
        }
        
        fn game_address_from_id(self: @ContractState, game_id: u64) -> ContractAddress {
            starknet::contract_address_const::<0x1234>() // Mock implementation
        }
        
        fn game_metadata(self: @ContractState, game_id: u64) -> GameMetadata {
            GameMetadata {
                creator_token_id: 0,
                contract_address: starknet::contract_address_const::<0x1234>(),
                name: "Mock Game",
                description: "Mock Description",
                developer: "Mock Developer",
                publisher: "Mock Publisher",
                genre: "Mock Genre",
                image: "Mock Image",
                color: "Mock Color",
                client_url: "https://mock.url",
                renderer_address: starknet::contract_address_const::<0>(),
                settings_address: starknet::contract_address_const::<0>(),
                objectives_address: starknet::contract_address_const::<0>(),
            }
        }
        
        fn is_game_registered(self: @ContractState, contract_address: ContractAddress) -> bool {
            self.registered_games.read(contract_address)
        }
        
        fn game_address(self: @ContractState, token_id: u64) -> ContractAddress {
            starknet::contract_address_const::<0x1234>() // Mock implementation
        }
        
        fn creator_token_id(self: @ContractState, game_id: u64) -> u64 {
            0 // Mock implementation
        }
        
        fn client_url(self: @ContractState, token_id: u64) -> ByteArray {
            "https://mock.url" // Mock implementation
        }
        
        fn register_game(
            ref self: ContractState,
            creator_address: ContractAddress,
            name: ByteArray,
            description: ByteArray,
            developer: ByteArray,
            publisher: ByteArray,
            genre: ByteArray,
            image: ByteArray,
            color: Option<ByteArray>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
        ) -> u64 {
            self.registered_games.write(creator_address, true);
            let game_id = self.game_count.read() + 1;
            self.game_count.write(game_id);
            game_id
        }
    }
    
    // External function to get owner (to support IERC721Dispatcher calls)
    #[external(v0)]
    fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
        let token_id_u64: u64 = token_id.try_into().unwrap();
        self.owners.read(token_id_u64)
    }
    
    // Mock helpers
    #[generate_trait]
    impl MockHelpers of MockHelpersTrait {
        fn set_owner(ref self: ContractState, token_id: u64, owner: ContractAddress) {
            self.owners.write(token_id, owner);
        }
        
        fn set_playable(ref self: ContractState, token_id: u64, playable: bool) {
            self.playable.write(token_id, playable);
        }
        
        fn set_game_over(ref self: ContractState, token_id: u64, game_over: bool) {
            self.game_over.write(token_id, game_over);
        }
    }
}

// Interface for mock helpers
#[starknet::interface]
pub trait IMockToken<TContractState> {
    fn set_owner(ref self: TContractState, token_id: u64, owner: ContractAddress);
    fn set_playable(ref self: TContractState, token_id: u64, playable: bool);
    fn set_game_over(ref self: TContractState, token_id: u64, game_over: bool);
}