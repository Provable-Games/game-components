// SPDX-License-Identifier: BUSL-1.1

/// Leaderboard Component
/// A reusable component for managing tournament leaderboards
#[starknet::component]
pub mod leaderboard_component {
    use crate::interface::{ILeaderboard, ILeaderboardAdmin};
    
    use crate::leaderboard::leaderboard::{
        LeaderboardEntry, LeaderboardResult, LeaderboardOperationsImpl,
        LeaderboardUtilsImpl,
    };
    use crate::leaderboard_store::{
        LeaderboardStoreConfig, LeaderboardStoreTrait, LeaderboardStoreImpl,
        LeaderboardStoreHelpersTrait, LeaderboardStoreHelpersImpl
    };
    use crate::models::Leaderboard;
    use crate::store::Store;
    
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map, StorageMapReadAccess, StorageMapWriteAccess};
    
    #[storage]
    pub struct Storage {
        tournament_id: u64,
        owner: ContractAddress,
        max_entries: u8,
        ascending: bool,
        game_address: ContractAddress,
        entries_count: u32,
        entries: Map<u32, u64>, // Map from position index to token ID
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ScoreSubmitted: ScoreSubmitted,
        ConfigUpdated: ConfigUpdated,
        LeaderboardCleared: LeaderboardCleared,
        OwnershipTransferred: OwnershipTransferred,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ScoreSubmitted {
        #[key]
        pub token_id: u64,
        pub score: u32,
        pub position: u8,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ConfigUpdated {
        pub max_entries: u8,
        pub ascending: bool,
        pub game_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LeaderboardCleared {
        pub tournament_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OwnershipTransferred {
        #[key]
        pub previous_owner: ContractAddress,
        #[key]
        pub new_owner: ContractAddress,
    }

    // Implement the Store trait for this component
    impl ComponentStore<
        TContractState, +HasComponent<TContractState>
    > of Store<ComponentState<TContractState>> {
        fn get_leaderboard(self: @ComponentState<TContractState>, tournament_id: u64) -> Span<u64> {
            assert!(tournament_id == self.tournament_id.read(), "Invalid tournament ID");
            
            let count = self.entries_count.read();
            let mut result = ArrayTrait::new();
            let mut i = 0_u32;
            
            loop {
                if i >= count {
                    break;
                }
                let token_id = self.entries.read(i);
                result.append(token_id);
                i += 1;
            };
            
            result.span()
        }

        fn set_leaderboard(ref self: ComponentState<TContractState>, leaderboard: @Leaderboard) {
            assert!(*leaderboard.tournament_id == self.tournament_id.read(), "Invalid tournament ID");
            
            // Clear existing entries
            let old_count = self.entries_count.read();
            let mut i = 0_u32;
            loop {
                if i >= old_count {
                    break;
                }
                self.entries.write(i, 0);
                i += 1;
            };
            
            // Write new entries
            let new_count = leaderboard.token_ids.len();
            self.entries_count.write(new_count);
            
            let mut j = 0_u32;
            loop {
                if j >= new_count {
                    break;
                }
                let token_id = *leaderboard.token_ids.at(j);
                self.entries.write(j, token_id);
                j += 1;
            };
        }
    }

    #[embeddable_as(LeaderboardImpl)]
    impl LeaderboardComponent<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ILeaderboard<ComponentState<TContractState>> {
        fn initialize(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            tournament_id: u64,
            max_entries: u8,
            ascending: bool,
            game_address: ContractAddress
        ) {
            assert!(self.tournament_id.read() == 0, "Already initialized");
            
            self.tournament_id.write(tournament_id);
            self.owner.write(owner);
            self.max_entries.write(max_entries);
            self.ascending.write(ascending);
            self.game_address.write(game_address);
            
            // Initialize empty entries
            self.entries_count.write(0);
            
            self.register_src5_interfaces();
        }

        fn submit_score(
            ref self: ComponentState<TContractState>,
            token_id: u64,
            score: u32,
            position: u8
        ) -> LeaderboardResult {
            let tournament_id = self.tournament_id.read();
            let config = LeaderboardStoreConfig {
                max_entries: self.max_entries.read(),
                ascending: self.ascending.read(),
                game_address: self.game_address.read()
            };
            
            let result = self.submit_score_to_leaderboard(
                tournament_id,
                token_id,
                score,
                position,
                config
            );
            
            match result {
                LeaderboardResult::Success => {
                    self.emit(ScoreSubmitted { token_id, score, position });
                },
                _ => {},
            }
            
            result
        }

        fn get_entries(self: @ComponentState<TContractState>) -> Array<LeaderboardEntry> {
            let tournament_id = self.tournament_id.read();
            let game_address = self.game_address.read();
            self.get_leaderboard_entries(tournament_id, game_address)
        }

        fn get_top_entries(self: @ComponentState<TContractState>, count: u32) -> Array<LeaderboardEntry> {
            let tournament_id = self.tournament_id.read();
            let game_address = self.game_address.read();
            let entries = self.get_leaderboard_entries(tournament_id, game_address);
            LeaderboardUtilsImpl::get_top_n(@entries, count)
        }

        fn get_position(self: @ComponentState<TContractState>, token_id: u64) -> Option<u8> {
            let tournament_id = self.tournament_id.read();
            self.get_entry_position(tournament_id, token_id)
        }

        fn qualifies(self: @ComponentState<TContractState>, score: u32) -> bool {
            let tournament_id = self.tournament_id.read();
            let config = LeaderboardStoreConfig {
                max_entries: self.max_entries.read(),
                ascending: self.ascending.read(),
                game_address: self.game_address.read()
            };
            self.qualifies_for_leaderboard(tournament_id, score, config)
        }

        fn is_full(self: @ComponentState<TContractState>) -> bool {
            let tournament_id = self.tournament_id.read();
            let max_entries = self.max_entries.read();
            self.is_leaderboard_full(tournament_id, max_entries)
        }

        fn get_config(self: @ComponentState<TContractState>) -> LeaderboardStoreConfig {
            LeaderboardStoreConfig {
                max_entries: self.max_entries.read(),
                ascending: self.ascending.read(),
                game_address: self.game_address.read()
            }
        }

        fn tournament_id(self: @ComponentState<TContractState>) -> u64 {
            self.tournament_id.read()
        }
    }

    #[embeddable_as(LeaderboardAdminImpl)]
    impl LeaderboardAdmin<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ILeaderboardAdmin<ComponentState<TContractState>> {
        fn update_config(
            ref self: ComponentState<TContractState>,
            max_entries: u8,
            ascending: bool,
            game_address: ContractAddress
        ) {
            self.assert_only_owner();
            
            self.max_entries.write(max_entries);
            self.ascending.write(ascending);
            self.game_address.write(game_address);
            
            self.emit(ConfigUpdated { max_entries, ascending, game_address });
        }

        fn clear_leaderboard(ref self: ComponentState<TContractState>) {
            self.assert_only_owner();
            
            self.entries_count.write(0);
            
            let tournament_id = self.tournament_id.read();
            self.emit(LeaderboardCleared { tournament_id });
        }

        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner.read()
        }

        fn transfer_ownership(ref self: ComponentState<TContractState>, new_owner: ContractAddress) {
            self.assert_only_owner();
            
            let previous_owner = self.owner.read();
            self.owner.write(new_owner);
            
            self.emit(OwnershipTransferred { previous_owner, new_owner });
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn register_src5_interfaces(ref self: ComponentState<TContractState>) {
            // SRC5 registration would be handled by the contract that uses this component
        }

        fn assert_only_owner(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert!(caller == owner, "Only owner can call this function");
        }
    }
}