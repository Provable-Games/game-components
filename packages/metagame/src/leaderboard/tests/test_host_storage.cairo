use game_components_interfaces::leaderboard::{
    ILeaderboardDispatcher, ILeaderboardDispatcherTrait, LeaderboardResult,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

#[starknet::interface]
trait IHostLeaderboard<T> {
    fn configure(ref self: T, id: u64, max: u32, ascending: bool);
    fn submit(ref self: T, id: u64, token: felt252, score: u64, position: u32) -> LeaderboardResult;
    fn hook_count(self: @T) -> u32;
}

#[starknet::contract]
mod HostLeaderboard {
    use game_components_interfaces::leaderboard::{LeaderboardResult, LeaderboardStoreConfig};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::leaderboard::api::{Configuration, LeaderboardInternalImpl, LeaderboardInternalTrait};
    use crate::leaderboard::hooks::LeaderboardHooksTrait;
    use crate::leaderboard::store::Store;
    #[storage]
    struct Storage {
        packed_config: Map<u64, u64>,
        count: Map<u64, u32>,
        tokens: Map<(u64, u32), felt252>,
        points: Map<(u64, u32), u64>,
        positions: Map<(u64, felt252), u32>,
        hooks: u32,
    }
    #[abi(embed_v0)]
    impl Views = crate::leaderboard::api::LeaderboardImpl<ContractState>;
    impl Config of Configuration<ContractState> {
        fn leaderboard_config(self: @ContractState, context_id: u64) -> LeaderboardStoreConfig {
            let packed = self.packed_config.read(context_id);
            LeaderboardStoreConfig {
                max_entries: (packed & 0xffffffff).try_into().unwrap(),
                ascending: packed / 0x100000000 == 1,
                game_address: 0.try_into().unwrap(),
            }
        }
    }
    impl Hooks of LeaderboardHooksTrait<ContractState> {
        fn on_score_submitted(
            ref self: ContractState, context_id: u64, token_id: felt252, score: u64, position: u32,
        ) {
            self.hooks.write(self.hooks.read() + 1);
        }
        fn on_configured(
            ref self: ContractState,
            context_id: u64,
            max_entries: u32,
            ascending: bool,
            game_address: starknet::ContractAddress,
        ) {}
        fn on_cleared(ref self: ContractState, context_id: u64) {}
        fn on_ownership_transferred(
            ref self: ContractState,
            previous_owner: starknet::ContractAddress,
            new_owner: starknet::ContractAddress,
        ) {}
    }
    impl HostStore of Store<ContractState> {
        fn get_leaderboard(self: @ContractState, context_id: u64) -> Span<felt252> {
            let mut out = array![];
            for i in 0..self.count.read(context_id) {
                out.append(self.tokens.read((context_id, i)));
            }
            out.span()
        }
        fn get_count(self: @ContractState, context_id: u64) -> u32 {
            self.count.read(context_id)
        }
        fn set_count(ref self: ContractState, context_id: u64, count: u32) {
            self.count.write(context_id, count);
        }
        fn get_entry_at(self: @ContractState, context_id: u64, position: u32) -> felt252 {
            self.tokens.read((context_id, position))
        }
        fn set_entry_at(
            ref self: ContractState, context_id: u64, position: u32, token_id: felt252,
        ) {
            self.tokens.write((context_id, position), token_id);
        }
        fn get_score_at(self: @ContractState, context_id: u64, position: u32) -> u64 {
            self.points.read((context_id, position))
        }
        fn set_score_at(ref self: ContractState, context_id: u64, position: u32, score: u64) {
            self.points.write((context_id, position), score);
        }
        fn get_token_position(self: @ContractState, context_id: u64, token_id: felt252) -> u32 {
            self.positions.read((context_id, token_id))
        }
        fn set_token_position(
            ref self: ContractState, context_id: u64, token_id: felt252, position: u32,
        ) {
            self.positions.write((context_id, token_id), position);
        }
    }
    #[abi(embed_v0)]
    impl TestApi of super::IHostLeaderboard<ContractState> {
        fn configure(ref self: ContractState, id: u64, max: u32, ascending: bool) {
            self.packed_config.write(id, max.into() + if ascending {
                0x100000000
            } else {
                0
            });
        }
        fn submit(
            ref self: ContractState, id: u64, token: felt252, score: u64, position: u32,
        ) -> LeaderboardResult {
            LeaderboardInternalTrait::submit_score(ref self, id, token, score, position)
        }
        fn hook_count(self: @ContractState) -> u32 {
            self.hooks.read()
        }
    }
}
fn deploy() -> (IHostLeaderboardDispatcher, ILeaderboardDispatcher) {
    let cls = declare("HostLeaderboard").unwrap().contract_class();
    let (address, _) = cls.deploy(@array![]).unwrap();
    (
        IHostLeaderboardDispatcher { contract_address: address },
        ILeaderboardDispatcher { contract_address: address },
    )
}
#[test]
fn leaderboard_host_storage_uses_packed_config_and_shared_views() {
    let (host, board) = deploy();
    host.configure(1, 2, false);
    host.configure(2, 2, true);
    assert!(board.get_config(1).max_entries == 2 && !board.get_config(1).ascending);
    assert!(board.get_leaderboard_entries(1).is_empty());
    assert!(host.submit(1, 11, 50, 1) == LeaderboardResult::Success);
    assert!(host.submit(1, 12, 40, 2) == LeaderboardResult::Success);
    assert!(board.is_full(1) && board.get_leaderboard_length(1) == 2);
    assert!(!board.qualifies(1, 30) && board.qualifies(1, 60));
    assert!(board.find_position(1, 60, 13) == Option::Some(1));
    assert!(board.get_leaderboard_entry(1, 2).id == 12);
    assert!(board.get_top_leaderboard_entries(1, 100).len() == 2);
    assert!(board.get_top_leaderboard_entries(1, 0).is_empty());
    assert!(host.submit(1, 13, 60, 1) == LeaderboardResult::Success);
    assert!(board.get_position(1, 11).is_none() && board.get_position(1, 13) == Option::Some(1));
    assert!(host.submit(2, 21, 10, 1) == LeaderboardResult::Success);
    assert!(host.submit(2, 22, 20, 2) == LeaderboardResult::Success);
    assert!(board.find_position(2, 5, 23) == Option::Some(1));
    assert!(
        board.get_leaderboard_entries(1).len() == 2 && board.get_leaderboard_entries(2).len() == 2,
    );
    assert!(host.hook_count() == 5);
    assert!(host.submit(1, 13, 60, 1) == LeaderboardResult::DuplicateEntry);
    assert!(host.submit(1, 14, 1, 3) == LeaderboardResult::LeaderboardFull);
    assert!(host.submit(1, 14, 60, 0) == LeaderboardResult::InvalidPosition);
    assert!(host.hook_count() == 5, "failed submissions must not trigger hooks");
}
#[test]
#[should_panic(expected: "Leaderboard: position must be 1-indexed")]
fn leaderboard_host_storage_rejects_zero_position_view() {
    let (_, board) = deploy();
    board.get_leaderboard_entry(1, 0);
}
#[test]
#[should_panic(expected: "Leaderboard: position 1 out of range")]
fn leaderboard_host_storage_rejects_missing_position_view() {
    let (_, board) = deploy();
    board.get_leaderboard_entry(1, 1);
}

#[starknet::contract]
mod ComponentBackedLeaderboard {
    use game_components_interfaces::leaderboard::{
        ILeaderboard, LeaderboardResult, LeaderboardStoreConfig,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use crate::leaderboard::api::{
        Configuration, LeaderboardInternalImpl, LeaderboardInternalTrait as HostInternalTrait,
    };
    use crate::leaderboard::leaderboard_component::LeaderboardComponent::LeaderboardInternalTrait;
    use crate::leaderboard::leaderboard_component::{
        LeaderboardComponent, LeaderboardHooksEmptyImpl,
    };
    use crate::leaderboard::store::Store;
    component!(path: LeaderboardComponent, storage: leaderboard, event: LeaderboardEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    impl Hooks = LeaderboardHooksEmptyImpl<ContractState>;
    impl StorageAdapter = crate::leaderboard::storage_adapter::ComponentStore<ContractState>;
    #[abi(embed_v0)]
    impl Views = crate::leaderboard::api::LeaderboardImpl<ContractState>;
    impl Config of Configuration<ContractState> {
        fn leaderboard_config(self: @ContractState, context_id: u64) -> LeaderboardStoreConfig {
            ILeaderboard::get_config(self.leaderboard, context_id)
        }
    }
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
        LeaderboardEvent: LeaderboardComponent::Event,
        SRC5Event: SRC5Component::Event,
    }
    #[abi(embed_v0)]
    impl TestApi of super::IHostLeaderboard<ContractState> {
        fn configure(ref self: ContractState, id: u64, max: u32, ascending: bool) {
            self.leaderboard._configure(id, max, ascending, 0.try_into().unwrap());
        }
        fn submit(
            ref self: ContractState, id: u64, token: felt252, score: u64, position: u32,
        ) -> LeaderboardResult {
            HostInternalTrait::submit_score(ref self, id, token, score, position)
        }
        fn hook_count(self: @ContractState) -> u32 {
            Store::get_leaderboard(self, 1).len().try_into().unwrap()
        }
    }
}
#[test]
fn leaderboard_host_storage_component_adapter_preserves_component_maps() {
    let cls = declare("ComponentBackedLeaderboard").unwrap().contract_class();
    let (address, _) = cls.deploy(@array![]).unwrap();
    let host = IHostLeaderboardDispatcher { contract_address: address };
    let board = ILeaderboardDispatcher { contract_address: address };
    host.configure(1, 2, false);
    assert!(host.submit(1, 11, 50, 1) == LeaderboardResult::Success);
    assert!(host.submit(1, 12, 40, 2) == LeaderboardResult::Success);
    assert!(board.get_leaderboard_entry(1, 1).id == 11);
    assert!(board.get_leaderboard_entries(1).len() == 2);
    assert!(board.get_position(1, 12) == Option::Some(2));
    assert!(board.qualifies(1, 60) && board.is_full(1));
    assert!(host.hook_count() == 2);
}
