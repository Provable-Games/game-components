// SPDX-License-Identifier: BUSL-1.1

/// Leaderboard Component
/// A reusable component for managing leaderboards
/// Supports multiple contexts with separate leaderboards per context_id
#[starknet::component]
pub mod LeaderboardComponent {
    use core::num::traits::Zero;
    use game_components_interfaces::leaderboard::{
        ILEADERBOARD_ID, ILeaderboard, ILeaderboardAdmin, LeaderboardEntry, LeaderboardResult,
        LeaderboardStoreConfig,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::leaderboard::leaderboard::leaderboard::{
        LeaderboardOperationsImpl, LeaderboardUtilsImpl,
    };
    use crate::leaderboard::leaderboard_store::{
        LeaderboardStoreHelpersImpl, LeaderboardStoreHelpersTrait, LeaderboardStoreImpl,
        LeaderboardStoreTrait,
    };
    use crate::leaderboard::store::Store;
    use crate::leaderboard::structs::Leaderboard;

    #[storage]
    pub struct Storage {
        owner: ContractAddress,
        entries_count: Map<u64, u32>, // context_id -> count
        entries: Map<(u64, u32), felt252>, // (context_id, position) -> token_id
        max_entries: Map<u64, u32>, // context_id -> max_entries
        ascending: Map<u64, bool>, // context_id -> ascending
        game_address: Map<u64, ContractAddress> // context_id -> game_address
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    // ==========================================================================
    // HOOKS TRAIT
    // ==========================================================================
    // Allows the embedding contract to define custom behavior on leaderboard
    // operations. Implementers can emit events, update state, etc.

    pub trait LeaderboardHooksTrait<TContractState> {
        /// Called after a score is successfully submitted
        fn on_score_submitted(
            ref self: TContractState, context_id: u64, token_id: felt252, score: u64, position: u32,
        );

        /// Called after a leaderboard context is configured
        fn on_configured(
            ref self: TContractState,
            context_id: u64,
            max_entries: u32,
            ascending: bool,
            game_address: ContractAddress,
        );

        /// Called after a leaderboard is cleared
        fn on_cleared(ref self: TContractState, context_id: u64);

        /// Called after ownership is transferred
        fn on_ownership_transferred(
            ref self: TContractState, previous_owner: ContractAddress, new_owner: ContractAddress,
        );
    }

    // Implement the Store trait for this component
    impl ComponentStore<
        TContractState, +HasComponent<TContractState>,
    > of Store<ComponentState<TContractState>> {
        fn get_leaderboard(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Span<felt252> {
            let count = self.entries_count.read(context_id);
            let mut result = ArrayTrait::new();
            let mut i = 0_u32;

            loop {
                if i >= count {
                    break;
                }
                let token_id = self.entries.read((context_id, i));
                result.append(token_id);
                i += 1;
            }

            result.span()
        }

        fn set_leaderboard(ref self: ComponentState<TContractState>, leaderboard: @Leaderboard) {
            let context_id = *leaderboard.context_id;

            // Clear existing entries
            let old_count = self.entries_count.read(context_id);
            let mut i = 0_u32;
            loop {
                if i >= old_count {
                    break;
                }
                self.entries.write((context_id, i), 0);
                i += 1;
            }

            // Write new entries
            let new_count = leaderboard.token_ids.len();
            self.entries_count.write(context_id, new_count);

            let mut j = 0_u32;
            loop {
                if j >= new_count {
                    break;
                }
                let token_id = *leaderboard.token_ids.at(j);
                self.entries.write((context_id, j), token_id);
                j += 1;
            };
        }
    }

    #[embeddable_as(LeaderboardImpl)]
    impl LeaderboardComponent<
        TContractState,
        +HasComponent<TContractState>,
        +LeaderboardHooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ILeaderboard<ComponentState<TContractState>> {
        fn submit_score(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            token_id: felt252,
            score: u64,
            position: u32,
        ) -> LeaderboardResult {
            let config = LeaderboardStoreConfig {
                max_entries: self.max_entries.read(context_id),
                ascending: self.ascending.read(context_id),
                game_address: self.game_address.read(context_id),
            };

            let result = self
                .submit_score_to_leaderboard(context_id, token_id, score, position, config);

            match result {
                LeaderboardResult::Success => {
                    let mut contract = self.get_contract_mut();
                    LeaderboardHooksTrait::on_score_submitted(
                        ref contract, context_id, token_id, score, position,
                    );
                },
                _ => {},
            }

            result
        }

        fn get_entries(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Array<LeaderboardEntry> {
            let game_address = self.game_address.read(context_id);
            self.get_leaderboard_entries(context_id, game_address)
        }

        fn get_top_entries(
            self: @ComponentState<TContractState>, context_id: u64, count: u32,
        ) -> Array<LeaderboardEntry> {
            let game_address = self.game_address.read(context_id);
            let entries = self.get_leaderboard_entries(context_id, game_address);
            LeaderboardUtilsImpl::get_top_n(@entries, count)
        }

        fn get_position(
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> Option<u32> {
            self.get_entry_position(context_id, token_id)
        }

        fn qualifies(self: @ComponentState<TContractState>, context_id: u64, score: u64) -> bool {
            let config = LeaderboardStoreConfig {
                max_entries: self.max_entries.read(context_id),
                ascending: self.ascending.read(context_id),
                game_address: self.game_address.read(context_id),
            };
            self.qualifies_for_leaderboard(context_id, score, config)
        }

        fn is_full(self: @ComponentState<TContractState>, context_id: u64) -> bool {
            let max_entries = self.max_entries.read(context_id);
            self.is_leaderboard_full(context_id, max_entries)
        }

        fn get_leaderboard_length(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            self.entries_count.read(context_id)
        }

        fn get_config(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> LeaderboardStoreConfig {
            LeaderboardStoreConfig {
                max_entries: self.max_entries.read(context_id),
                ascending: self.ascending.read(context_id),
                game_address: self.game_address.read(context_id),
            }
        }
    }

    #[embeddable_as(LeaderboardAdminImpl)]
    impl LeaderboardAdmin<
        TContractState,
        +HasComponent<TContractState>,
        +LeaderboardHooksTrait<TContractState>,
        +Drop<TContractState>,
    > of ILeaderboardAdmin<ComponentState<TContractState>> {
        fn configure(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            max_entries: u32,
            ascending: bool,
            game_address: ContractAddress,
        ) {
            self.assert_only_owner();

            self.max_entries.write(context_id, max_entries);
            self.ascending.write(context_id, ascending);
            self.game_address.write(context_id, game_address);

            let mut contract = self.get_contract_mut();
            LeaderboardHooksTrait::on_configured(
                ref contract, context_id, max_entries, ascending, game_address,
            );
        }

        fn clear(ref self: ComponentState<TContractState>, context_id: u64) {
            self.assert_only_owner();

            // Clear all entries for this context
            let count = self.entries_count.read(context_id);
            let mut i = 0_u32;
            loop {
                if i >= count {
                    break;
                }
                self.entries.write((context_id, i), 0);
                i += 1;
            }
            self.entries_count.write(context_id, 0);

            let mut contract = self.get_contract_mut();
            LeaderboardHooksTrait::on_cleared(ref contract, context_id);
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

            let mut contract = self.get_contract_mut();
            LeaderboardHooksTrait::on_ownership_transferred(
                ref contract, previous_owner, new_owner,
            );
        }
    }

    #[generate_trait]
    pub impl LeaderboardInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +LeaderboardHooksTrait<TContractState>,
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

        /// Internal method to configure a context (no owner check)
        /// Used by owning contract to set up leaderboard contexts
        fn _configure(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            max_entries: u32,
            ascending: bool,
            game_address: ContractAddress,
        ) {
            self.max_entries.write(context_id, max_entries);
            self.ascending.write(context_id, ascending);
            self.game_address.write(context_id, game_address);

            let mut contract = self.get_contract_mut();
            LeaderboardHooksTrait::on_configured(
                ref contract, context_id, max_entries, ascending, game_address,
            );
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

// ==============================================================================
// EMPTY HOOKS IMPLEMENTATION
// ==============================================================================
// Provides a no-op implementation for contracts that don't need custom behavior.

pub impl LeaderboardHooksEmptyImpl<
    TContractState,
> of LeaderboardComponent::LeaderboardHooksTrait<TContractState> {
    fn on_score_submitted(
        ref self: TContractState, context_id: u64, token_id: felt252, score: u64, position: u32,
    ) {}

    fn on_configured(
        ref self: TContractState,
        context_id: u64,
        max_entries: u32,
        ascending: bool,
        game_address: starknet::ContractAddress,
    ) {}

    fn on_cleared(ref self: TContractState, context_id: u64) {}

    fn on_ownership_transferred(
        ref self: TContractState,
        previous_owner: starknet::ContractAddress,
        new_owner: starknet::ContractAddress,
    ) {}
}
