use game_components_minigame::interface::{IMINIGAME_ID, IMinigame, IMinigameTokenData};
use openzeppelin_interfaces::introspection::ISRC5;
use starknet::ContractAddress;

#[starknet::contract]
pub mod MockMinigame {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::*;

    #[storage]
    struct Storage {
        // Minigame interface fields
        token_address: ContractAddress,
        settings_address: ContractAddress,
        objectives_address: ContractAddress,
        // Mock storage for game state
        token_scores: Map<u64, u32>,
        token_game_over: Map<u64, bool>,
        objectives_completed: Map<(u64, u32), bool>,
        // Test behavior flags
        should_fail_score: bool,
        should_fail_game_over: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        settings_address: ContractAddress,
        objectives_address: ContractAddress,
    ) {
        self.token_address.write(token_address);
        self.settings_address.write(settings_address);
        self.objectives_address.write(objectives_address);
    }

    // Implement IMinigame interface
    #[abi(embed_v0)]
    impl MinigameImpl of IMinigame<ContractState> {
        fn token_address(self: @ContractState) -> ContractAddress {
            self.token_address.read()
        }

        fn settings_address(self: @ContractState) -> ContractAddress {
            self.settings_address.read()
        }

        fn objectives_address(self: @ContractState) -> ContractAddress {
            self.objectives_address.read()
        }
    }

    // Implement IMinigameTokenData for testing
    #[abi(embed_v0)]
    impl MinigameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: u64) -> u32 {
            if self.should_fail_score.read() {
                panic!("Score failed");
            }
            self.token_scores.read(token_id)
        }

        fn game_over(self: @ContractState, token_id: u64) -> bool {
            if self.should_fail_game_over.read() {
                panic!("Game over failed");
            }
            self.token_game_over.read(token_id)
        }
    }

    // Implement ISRC5
    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IMINIGAME_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }

    // Interface for setting values in tests
    #[starknet::interface]
    trait IMockMinigameSetter<TContractState> {
        fn set_score(ref self: TContractState, token_id: u64, score: u32);
        fn set_game_over(ref self: TContractState, token_id: u64, game_over: bool);
    }

    // Public interface implementation for testing
    #[abi(embed_v0)]
    impl MockMinigameSetterImpl of IMockMinigameSetter<ContractState> {
        fn set_score(ref self: ContractState, token_id: u64, score: u32) {
            self.token_scores.write(token_id, score);
        }

        fn set_game_over(ref self: ContractState, token_id: u64, game_over: bool) {
            self.token_game_over.write(token_id, game_over);
        }
    }

    // Helper functions for testing
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn set_objective_completed(
            ref self: ContractState, token_id: u64, objective_id: u32, completed: bool,
        ) {
            self.objectives_completed.write((token_id, objective_id), completed);
        }

        fn set_should_fail_score(ref self: ContractState, should_fail: bool) {
            self.should_fail_score.write(should_fail);
        }

        fn set_should_fail_game_over(ref self: ContractState, should_fail: bool) {
            self.should_fail_game_over.write(should_fail);
        }

        fn is_objective_completed(self: @ContractState, token_id: u64, objective_id: u32) -> bool {
            self.objectives_completed.read((token_id, objective_id))
        }
    }
}
