/// Interface for setting scores in mock game
#[starknet::interface]
pub trait IMockGameDetailsAdmin<TContractState> {
    fn set_score(ref self: TContractState, token_id: felt252, score: u64);
    fn get_score(self: @TContractState, token_id: felt252) -> u64;
}

/// Mock game contract that implements IGameDetails for leaderboard testing
#[starknet::contract]
pub mod MockGameDetails {
    use game_components_leaderboard::interface::IGameDetails;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        scores: Map<felt252, u64>,
    }

    #[abi(embed_v0)]
    impl GameDetailsImpl of IGameDetails<ContractState> {
        fn score(self: @ContractState, token_id: felt252) -> u64 {
            self.scores.read(token_id)
        }
    }

    #[abi(embed_v0)]
    impl MockGameDetailsAdminImpl of super::IMockGameDetailsAdmin<ContractState> {
        fn set_score(ref self: ContractState, token_id: felt252, score: u64) {
            self.scores.write(token_id, score);
        }

        fn get_score(self: @ContractState, token_id: felt252) -> u64 {
            self.scores.read(token_id)
        }
    }
}
