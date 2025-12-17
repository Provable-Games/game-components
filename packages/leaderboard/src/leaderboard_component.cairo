// SPDX-License-Identifier: BUSL-1.1

/// Leaderboard Component
/// A reusable component for managing tournament leaderboards
/// Supports multiple tournaments with separate leaderboards per tournament_id
#[starknet::component]
pub mod LeaderboardComponent {
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::interface::{ILEADERBOARD_ID, ILeaderboard, ILeaderboardAdmin};
    use crate::leaderboard::leaderboard::{
        LeaderboardEntry, LeaderboardOperationsImpl, LeaderboardResult, LeaderboardUtilsImpl,
    };
    use crate::leaderboard_store::{
        LeaderboardStoreConfig, LeaderboardStoreHelpersImpl, LeaderboardStoreHelpersTrait,
        LeaderboardStoreImpl, LeaderboardStoreTrait,
    };
    use crate::models::Leaderboard;
    use crate::store::Store;

    #[storage]
    pub struct Storage {
        owner: ContractAddress,
        // Per-tournament entry counts
        entries_count: Map<u64, u32>, // tournament_id -> count
        // Per-tournament entries: (tournament_id, position) -> token_id
        entries: Map<(u64, u32), u64>,
        // Per-tournament configuration
        max_entries: Map<u64, u32>, // tournament_id -> max_entries
        ascending: Map<u64, bool>, // tournament_id -> ascending
        game_address: Map<u64, ContractAddress> // tournament_id -> game_address
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TournamentConfigured: TournamentConfigured,
        ScoreSubmitted: ScoreSubmitted,
        LeaderboardCleared: LeaderboardCleared,
        LeaderboardOwnershipTransferred: LeaderboardOwnershipTransferred,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TournamentConfigured {
        #[key]
        pub tournament_id: u64,
        pub max_entries: u32,
        pub ascending: bool,
        pub game_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ScoreSubmitted {
        #[key]
        pub tournament_id: u64,
        #[key]
        pub token_id: u64,
        pub score: u32,
        pub position: u8,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LeaderboardCleared {
        #[key]
        pub tournament_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LeaderboardOwnershipTransferred {
        #[key]
        pub previous_owner: ContractAddress,
        #[key]
        pub new_owner: ContractAddress,
    }

    // Implement the Store trait for this component
    impl ComponentStore<
        TContractState, +HasComponent<TContractState>,
    > of Store<ComponentState<TContractState>> {
        fn get_leaderboard(self: @ComponentState<TContractState>, tournament_id: u64) -> Span<u64> {
            let count = self.entries_count.read(tournament_id);
            let mut result = ArrayTrait::new();
            let mut i = 0_u32;

            loop {
                if i >= count {
                    break;
                }
                let token_id = self.entries.read((tournament_id, i));
                result.append(token_id);
                i += 1;
            }

            result.span()
        }

        fn set_leaderboard(ref self: ComponentState<TContractState>, leaderboard: @Leaderboard) {
            let tournament_id = *leaderboard.tournament_id;

            // Clear existing entries
            let old_count = self.entries_count.read(tournament_id);
            let mut i = 0_u32;
            loop {
                if i >= old_count {
                    break;
                }
                self.entries.write((tournament_id, i), 0);
                i += 1;
            }

            // Write new entries
            let new_count = leaderboard.token_ids.len();
            self.entries_count.write(tournament_id, new_count);

            let mut j = 0_u32;
            loop {
                if j >= new_count {
                    break;
                }
                let token_id = *leaderboard.token_ids.at(j);
                self.entries.write((tournament_id, j), token_id);
                j += 1;
            };
        }
    }

    #[embeddable_as(LeaderboardImpl)]
    impl LeaderboardComponent<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ILeaderboard<ComponentState<TContractState>> {
        fn submit_score(
            ref self: ComponentState<TContractState>,
            tournament_id: u64,
            token_id: u64,
            score: u32,
            position: u8,
        ) -> LeaderboardResult {
            // Read config from storage
            let config = LeaderboardStoreConfig {
                max_entries: self.max_entries.read(tournament_id),
                ascending: self.ascending.read(tournament_id),
                game_address: self.game_address.read(tournament_id),
            };

            let result = self
                .submit_score_to_leaderboard(tournament_id, token_id, score, position, config);

            match result {
                LeaderboardResult::Success => {
                    self.emit(ScoreSubmitted { tournament_id, token_id, score, position });
                },
                _ => {},
            }

            result
        }

        fn get_entries(
            self: @ComponentState<TContractState>, tournament_id: u64,
        ) -> Array<LeaderboardEntry> {
            let game_address = self.game_address.read(tournament_id);
            self.get_leaderboard_entries(tournament_id, game_address)
        }

        fn get_top_entries(
            self: @ComponentState<TContractState>, tournament_id: u64, count: u32,
        ) -> Array<LeaderboardEntry> {
            let game_address = self.game_address.read(tournament_id);
            let entries = self.get_leaderboard_entries(tournament_id, game_address);
            LeaderboardUtilsImpl::get_top_n(@entries, count)
        }

        fn get_position(
            self: @ComponentState<TContractState>, tournament_id: u64, token_id: u64,
        ) -> Option<u8> {
            self.get_entry_position(tournament_id, token_id)
        }

        fn qualifies(
            self: @ComponentState<TContractState>, tournament_id: u64, score: u32,
        ) -> bool {
            let config = LeaderboardStoreConfig {
                max_entries: self.max_entries.read(tournament_id),
                ascending: self.ascending.read(tournament_id),
                game_address: self.game_address.read(tournament_id),
            };
            self.qualifies_for_leaderboard(tournament_id, score, config)
        }

        fn is_full(self: @ComponentState<TContractState>, tournament_id: u64) -> bool {
            let max_entries = self.max_entries.read(tournament_id);
            self.is_leaderboard_full(tournament_id, max_entries)
        }

        fn get_leaderboard_length(
            self: @ComponentState<TContractState>, tournament_id: u64,
        ) -> u32 {
            self.entries_count.read(tournament_id)
        }

        fn get_tournament_config(
            self: @ComponentState<TContractState>, tournament_id: u64,
        ) -> LeaderboardStoreConfig {
            LeaderboardStoreConfig {
                max_entries: self.max_entries.read(tournament_id),
                ascending: self.ascending.read(tournament_id),
                game_address: self.game_address.read(tournament_id),
            }
        }
    }

    #[embeddable_as(LeaderboardAdminImpl)]
    impl LeaderboardAdmin<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of ILeaderboardAdmin<ComponentState<TContractState>> {
        fn configure_tournament(
            ref self: ComponentState<TContractState>,
            tournament_id: u64,
            max_entries: u32,
            ascending: bool,
            game_address: ContractAddress,
        ) {
            self.assert_only_owner();

            self.max_entries.write(tournament_id, max_entries);
            self.ascending.write(tournament_id, ascending);
            self.game_address.write(tournament_id, game_address);

            self.emit(TournamentConfigured { tournament_id, max_entries, ascending, game_address });
        }

        fn clear_leaderboard(ref self: ComponentState<TContractState>, tournament_id: u64) {
            self.assert_only_owner();

            // Clear all entries for this tournament
            let count = self.entries_count.read(tournament_id);
            let mut i = 0_u32;
            loop {
                if i >= count {
                    break;
                }
                self.entries.write((tournament_id, i), 0);
                i += 1;
            }
            self.entries_count.write(tournament_id, 0);

            self.emit(LeaderboardCleared { tournament_id });
        }

        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner.read()
        }

        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress,
        ) {
            self.assert_only_owner();

            let previous_owner = self.owner.read();
            self.owner.write(new_owner);

            self.emit(LeaderboardOwnershipTransferred { previous_owner, new_owner });
        }
    }

    #[generate_trait]
    pub impl LeaderboardInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of LeaderboardInternalTrait<TContractState> {
        /// Initialize the leaderboard component
        /// Sets the owner and registers the SRC5 interface
        fn initializer(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            assert!(self.owner.read().is_zero(), "Already initialized");
            self.owner.write(owner);

            // Register SRC5 interface
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(ILEADERBOARD_ID);
        }

        /// Internal method to configure tournament (no owner check)
        /// Used by owning contract to set up tournaments
        fn _configure_tournament(
            ref self: ComponentState<TContractState>,
            tournament_id: u64,
            max_entries: u32,
            ascending: bool,
            game_address: ContractAddress,
        ) {
            self.max_entries.write(tournament_id, max_entries);
            self.ascending.write(tournament_id, ascending);
            self.game_address.write(tournament_id, game_address);

            self.emit(TournamentConfigured { tournament_id, max_entries, ascending, game_address });
        }
    }

    #[generate_trait]
    pub impl PrivateImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of PrivateTrait<TContractState> {
        fn assert_only_owner(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert!(caller == owner, "Only owner can call this function");
        }
    }
}
