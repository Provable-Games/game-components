#[starknet::interface]
pub trait IMockGame<TContractState> {
    // Test helpers
    fn set_score(ref self: TContractState, token_id: u64, score: u32);
    fn set_game_over(ref self: TContractState, token_id: u64, game_over: bool);
}

#[starknet::contract]
pub mod MockGame {
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use game_components_minigame::interface::IMinigameTokenData;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use game_components_minigame::interface::IMINIGAME_ID;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        scores: Map<u64, u32>,
        game_overs: Map<u64, bool>,
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
        fn score(self: @ContractState, token_id: u64) -> u32 {
            self.scores.read(token_id)
        }

        fn game_over(self: @ContractState, token_id: u64) -> bool {
            self.game_overs.read(token_id)
        }
    }

    #[abi(embed_v0)]
    impl MockGameImpl of super::IMockGame<ContractState> {
        fn set_score(ref self: ContractState, token_id: u64, score: u32) {
            self.scores.write(token_id, score);
        }

        fn set_game_over(ref self: ContractState, token_id: u64, game_over: bool) {
            self.game_overs.write(token_id, game_over);
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
}
