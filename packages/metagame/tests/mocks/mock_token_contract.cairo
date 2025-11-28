// This is essentially the same as MockMinigameToken but with a different contract name
// for use in integration tests that expect "MockTokenContract"
use starknet::{ContractAddress, contract_address_const};
use game_components_token::interface::IMinigameToken;
use game_components_token::structs::{TokenMetadata, Lifecycle};
use game_components_token::extensions::multi_game::interface::IMinigameTokenMultiGame;
use game_components_token::extensions::multi_game::structs::GameMetadata;
use game_components_metagame::extensions::context::structs::GameContextDetails;
use openzeppelin_interfaces::introspection::ISRC5;

#[starknet::contract]
pub mod MockTokenContract {
    use super::*;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    #[storage]
    struct Storage {
        // Maps for game registration
        game_addresses: Map<u32, ContractAddress>,
        address_to_game_id: Map<ContractAddress, u32>,
        game_registered: Map<ContractAddress, bool>,
        game_count: u32,
        // Token storage
        next_token_id: u64,
        token_game_address: Map<u64, ContractAddress>,
        token_player_names: Map<u64, ByteArray>,
        token_lifecycle_start: Map<u64, u64>,
        token_lifecycle_end: Map<u64, u64>,
        // Mock behavior flags
        should_fail_mint: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_token_id.write(1);
        self.game_count.write(0);
    }

    #[abi(embed_v0)]
    impl MinigameTokenImpl of IMinigameToken<ContractState> {
        fn token_metadata(self: @ContractState, token_id: u64) -> TokenMetadata {
            let game_address = self.token_game_address.read(token_id);
            let game_id = self.address_to_game_id.read(game_address);

            TokenMetadata {
                game_id: game_id.into(),
                minted_at: 0,
                settings_id: 0,
                lifecycle: Lifecycle {
                    start: self.token_lifecycle_start.read(token_id),
                    end: self.token_lifecycle_end.read(token_id),
                },
                minted_by: 0,
                soulbound: false,
                game_over: false,
                completed_all_objectives: false,
                has_context: false,
                objectives_count: 0,
            }
        }

        fn is_playable(self: @ContractState, token_id: u64) -> bool {
            token_id < self.next_token_id.read()
        }

        fn settings_id(self: @ContractState, token_id: u64) -> u32 {
            0
        }

        fn player_name(self: @ContractState, token_id: u64) -> ByteArray {
            self.token_player_names.read(token_id)
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
            if self.should_fail_mint.read() {
                panic!("Mint failed");
            }

            let token_id = self.next_token_id.read();
            self.next_token_id.write(token_id + 1);

            // Store game address
            if let Option::Some(game_addr) = game_address {
                self.token_game_address.write(token_id, game_addr);
            }

            // Store player name
            if let Option::Some(name) = player_name {
                self.token_player_names.write(token_id, name);
            }

            // Store lifecycle data
            if let Option::Some(start_time) = start {
                self.token_lifecycle_start.write(token_id, start_time);
            }

            if let Option::Some(end_time) = end {
                self.token_lifecycle_end.write(token_id, end_time);
            }

            token_id
        }

        fn update_game(ref self: ContractState, token_id: u64) { // Mock implementation - no-op
        }
    }

    #[abi(embed_v0)]
    impl MinigameTokenMultiGameImpl of IMinigameTokenMultiGame<ContractState> {
        fn game_count(self: @ContractState) -> u64 {
            self.game_count.read().into()
        }

        fn game_id_from_address(self: @ContractState, contract_address: ContractAddress) -> u64 {
            self.address_to_game_id.read(contract_address).into()
        }

        fn game_address_from_id(self: @ContractState, game_id: u64) -> ContractAddress {
            self.game_addresses.read(game_id.try_into().unwrap())
        }

        fn game_metadata(self: @ContractState, game_id: u64) -> GameMetadata {
            GameMetadata {
                creator_token_id: 0,
                contract_address: contract_address_const::<0x0>(),
                name: "Mock Game",
                description: "Mock Description",
                developer: "Mock Developer",
                publisher: "Mock Publisher",
                genre: "Mock Genre",
                image: "Mock Image",
                color: "",
                client_url: "",
                renderer_address: contract_address_const::<0x0>(),
                settings_address: contract_address_const::<0x0>(),
                objectives_address: contract_address_const::<0x0>(),
            }
        }

        fn is_game_registered(self: @ContractState, contract_address: ContractAddress) -> bool {
            self.game_registered.read(contract_address)
        }

        fn game_address(self: @ContractState, token_id: u64) -> ContractAddress {
            self.token_game_address.read(token_id)
        }

        fn creator_token_id(self: @ContractState, game_id: u64) -> u64 {
            0
        }

        fn client_url(self: @ContractState, token_id: u64) -> ByteArray {
            ""
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
            let game_id = self.game_count.read() + 1;
            self.game_count.write(game_id);
            self.game_addresses.write(game_id, creator_address);
            self.address_to_game_id.write(creator_address, game_id);
            self.game_registered.write(creator_address, true);
            game_id.into()
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == game_components_token::interface::IMINIGAME_TOKEN_ID
                || interface_id == game_components_token::extensions::multi_game::interface::IMINIGAME_TOKEN_MULTIGAME_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }

    // Helper functions for testing
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn set_should_fail_mint(ref self: ContractState, should_fail: bool) {
            self.should_fail_mint.write(should_fail);
        }
    }
}
