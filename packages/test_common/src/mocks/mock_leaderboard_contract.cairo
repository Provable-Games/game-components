/// Interface for additional mock leaderboard test functions
#[starknet::interface]
pub trait IMockLeaderboardTest<TContractState> {
    fn get_entry_count(self: @TContractState, context_id: u64) -> u32;
    /// Test-only wrapper around the internal submit_score (which lives on
    /// LeaderboardInternalTrait, not the public ILeaderboard). Real hosts
    /// wrap with their own validation; the mock exposes it raw.
    fn submit_score(
        ref self: TContractState, context_id: u64, token_id: felt252, score: u64, position: u32,
    ) -> game_components_interfaces::leaderboard::LeaderboardResult;
}

/// Mock leaderboard contract for testing LeaderboardComponent
/// This contract embeds the leaderboard component and provides test access
#[starknet::contract]
pub mod MockLeaderboardContract {
    #[allow(unused_imports)]
    use game_components_interfaces::leaderboard::{LeaderboardEntry, LeaderboardResult};
    #[allow(unused_imports)]
    use game_components_metagame::leaderboard::interface::ILeaderboard;
    use game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::{
        LeaderboardAdminImpl, LeaderboardImpl, LeaderboardInternalTrait,
    };
    use game_components_metagame::leaderboard::leaderboard_component::{
        LeaderboardComponent, LeaderboardHooksEmptyImpl,
    };
    #[allow(unused_imports)]
    use game_components_metagame::leaderboard::leaderboard_store::LeaderboardStoreConfig;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: LeaderboardComponent, storage: leaderboard, event: LeaderboardEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Empty hooks implementation (no-op for all hooks)
    impl LeaderboardHooks = LeaderboardHooksEmptyImpl<ContractState>;

    // Embed the leaderboard implementation
    #[abi(embed_v0)]
    impl LeaderboardMixinImpl =
        LeaderboardComponent::LeaderboardImpl<ContractState>;
    #[abi(embed_v0)]
    impl LeaderboardAdminMixinImpl =
        LeaderboardComponent::LeaderboardAdminImpl<ContractState>;

    // SRC5 implementation
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        leaderboard: LeaderboardComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        LeaderboardEvent: LeaderboardComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.leaderboard.initializer(owner);
    }

    #[abi(embed_v0)]
    impl MockLeaderboardTestImpl of super::IMockLeaderboardTest<ContractState> {
        fn get_entry_count(self: @ContractState, context_id: u64) -> u32 {
            self.leaderboard.get_leaderboard_length(context_id)
        }

        fn submit_score(
            ref self: ContractState, context_id: u64, token_id: felt252, score: u64, position: u32,
        ) -> LeaderboardResult {
            self.leaderboard.submit_score(context_id, token_id, score, position)
        }
    }
}
