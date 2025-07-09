#[starknet::contract]
pub mod MockMinigame {
    use game_components_minigame::interface::{IMinigameTokenData, IMINIGAME_ID};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use openzeppelin_introspection::src5::{SRC5Component, SRC5Component::InternalTrait};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        scores: Map<u64, u64>,
        game_over_states: Map<u64, bool>,
        // For testing: configurable return values
        should_fail: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.src5.register_interface(IMINIGAME_ID);
    }

    #[abi(embed_v0)]
    impl MinigameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: u64) -> u64 {
            self.scores.read(token_id)
        }

        fn game_over(self: @ContractState, token_id: u64) -> bool {
            self.game_over_states.read(token_id)
        }
    }

    #[external(v0)]
    fn set_score(ref self: ContractState, token_id: u64, score: u64) {
        self.scores.write(token_id, score);
    }

    #[external(v0)]
    fn set_game_over(ref self: ContractState, token_id: u64, game_over: bool) {
        self.game_over_states.write(token_id, game_over);
    }

    #[external(v0)]
    fn set_should_fail(ref self: ContractState, should_fail: bool) {
        self.should_fail.write(should_fail);
    }
}