#[starknet::interface]
pub trait IMockGame<TContractState> {
    // Test helpers
    fn set_score(ref self: TContractState, token_id: felt252, score: u64);
    fn set_game_over(ref self: TContractState, token_id: felt252, game_over: bool);
}

#[starknet::contract]
pub mod MockGame {
    use game_components_embeddable_game_standard::minigame::interface::IMinigameTokenData;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        scores: Map<felt252, u64>,
        game_overs: Map<felt252, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl MinigameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: felt252) -> u64 {
            self.scores.read(token_id)
        }

        fn game_over(self: @ContractState, token_id: felt252) -> bool {
            self.game_overs.read(token_id)
        }

        fn score_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u64> {
            let mut results = array![];
            let mut index = 0;
            loop {
                if index >= token_ids.len() {
                    break;
                }
                results.append(self.score(*token_ids.at(index)));
                index += 1;
            }
            results
        }

        fn game_over_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut results = array![];
            let mut index = 0;
            loop {
                if index >= token_ids.len() {
                    break;
                }
                results.append(self.game_over(*token_ids.at(index)));
                index += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl MockGameImpl of super::IMockGame<ContractState> {
        fn set_score(ref self: ContractState, token_id: felt252, score: u64) {
            self.scores.write(token_id, score);
        }

        fn set_game_over(ref self: ContractState, token_id: felt252, game_over: bool) {
            self.game_overs.write(token_id, game_over);
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
}
