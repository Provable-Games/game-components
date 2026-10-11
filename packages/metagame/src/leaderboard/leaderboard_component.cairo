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
    use crate::leaderboard::store::Store;

    #[storage]
    pub struct Storage {
        owner: ContractAddress,
        entries_count: Map<u64, u32>, // context_id -> count
        entries: Map<(u64, u32), felt252>, // (context_id, position) -> token_id
        scores: Map<(u64, u32), u64>, // (context_id, position) -> score
        token_positions: Map<
            (u64, felt252), u32,
        >, // (context_id, token_id) -> position+1 (0=absent)
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

    pub use crate::leaderboard::hooks::LeaderboardHooksTrait;

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

        // Direct storage accessors for optimized insertion
        fn get_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            self.entries_count.read(context_id)
        }

        fn set_count(ref self: ComponentState<TContractState>, context_id: u64, count: u32) {
            self.entries_count.write(context_id, count);
        }

        fn get_entry_at(
            self: @ComponentState<TContractState>, context_id: u64, position: u32,
        ) -> felt252 {
            self.entries.read((context_id, position))
        }

        fn set_entry_at(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            position: u32,
            token_id: felt252,
        ) {
            self.entries.write((context_id, position), token_id);
        }

        fn get_score_at(
            self: @ComponentState<TContractState>, context_id: u64, position: u32,
        ) -> u64 {
            self.scores.read((context_id, position))
        }

        fn set_score_at(
            ref self: ComponentState<TContractState>, context_id: u64, position: u32, score: u64,
        ) {
            self.scores.write((context_id, position), score);
        }

        fn get_token_position(
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> u32 {
            self.token_positions.read((context_id, token_id))
        }

        fn set_token_position(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            token_id: felt252,
            position: u32,
        ) {
            self.token_positions.write((context_id, token_id), position);
        }
    }

    impl StoredConfiguration<
        T, +HasComponent<T>,
    > of crate::leaderboard::api::Configuration<ComponentState<T>> {
        fn leaderboard_config(self: @ComponentState<T>, context_id: u64) -> LeaderboardStoreConfig {
            LeaderboardStoreConfig {
                max_entries: self.max_entries.read(context_id),
                ascending: self.ascending.read(context_id),
                game_address: self.game_address.read(context_id),
            }
        }
        fn leaderboard_game_address(self: @ComponentState<T>, context_id: u64) -> ContractAddress {
            self.game_address.read(context_id)
        }
        fn leaderboard_max_entries(self: @ComponentState<T>, context_id: u64) -> u32 {
            self.max_entries.read(context_id)
        }
    }

    impl ComponentHooks<
        T, +HasComponent<T>, +LeaderboardHooksTrait<T>, +Drop<T>,
    > of LeaderboardHooksTrait<ComponentState<T>> {
        fn on_score_submitted(
            ref self: ComponentState<T>,
            context_id: u64,
            token_id: felt252,
            score: u64,
            position: u32,
        ) {
            let mut host = self.get_contract_mut();
            LeaderboardHooksTrait::on_score_submitted(
                ref host, context_id, token_id, score, position,
            );
        }
        fn on_configured(
            ref self: ComponentState<T>,
            context_id: u64,
            max_entries: u32,
            ascending: bool,
            game_address: ContractAddress,
        ) {
            let mut host = self.get_contract_mut();
            LeaderboardHooksTrait::on_configured(
                ref host, context_id, max_entries, ascending, game_address,
            );
        }
        fn on_cleared(ref self: ComponentState<T>, context_id: u64) {
            let mut host = self.get_contract_mut();
            LeaderboardHooksTrait::on_cleared(ref host, context_id);
        }
        fn on_ownership_transferred(
            ref self: ComponentState<T>,
            previous_owner: ContractAddress,
            new_owner: ContractAddress,
        ) {
            let mut host = self.get_contract_mut();
            LeaderboardHooksTrait::on_ownership_transferred(ref host, previous_owner, new_owner);
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
        fn get_leaderboard_entries(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Array<LeaderboardEntry> {
            crate::leaderboard::api::LeaderboardImpl::get_leaderboard_entries(self, context_id)
        }

        fn get_leaderboard_entry(
            self: @ComponentState<TContractState>, context_id: u64, position: u32,
        ) -> LeaderboardEntry {
            crate::leaderboard::api::LeaderboardImpl::get_leaderboard_entry(
                self, context_id, position,
            )
        }

        fn get_top_leaderboard_entries(
            self: @ComponentState<TContractState>, context_id: u64, count: u32,
        ) -> Array<LeaderboardEntry> {
            crate::leaderboard::api::LeaderboardImpl::get_top_leaderboard_entries(
                self, context_id, count,
            )
        }

        fn get_position(
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> Option<u32> {
            crate::leaderboard::api::LeaderboardImpl::get_position(self, context_id, token_id)
        }

        fn qualifies(self: @ComponentState<TContractState>, context_id: u64, score: u64) -> bool {
            crate::leaderboard::api::LeaderboardImpl::qualifies(self, context_id, score)
        }

        fn is_full(self: @ComponentState<TContractState>, context_id: u64) -> bool {
            crate::leaderboard::api::LeaderboardImpl::is_full(self, context_id)
        }

        fn get_leaderboard_length(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            crate::leaderboard::api::LeaderboardImpl::get_leaderboard_length(self, context_id)
        }

        fn get_config(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> LeaderboardStoreConfig {
            crate::leaderboard::api::LeaderboardImpl::get_config(self, context_id)
        }

        fn find_position(
            self: @ComponentState<TContractState>, context_id: u64, score: u64, token_id: felt252,
        ) -> Option<u32> {
            crate::leaderboard::api::LeaderboardImpl::find_position(
                self, context_id, score, token_id,
            )
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

            // Clear all entries, scores, and token_positions for this context
            let count = self.entries_count.read(context_id);
            let mut i = 0_u32;
            loop {
                if i >= count {
                    break;
                }
                let token_id = self.entries.read((context_id, i));
                self.token_positions.write((context_id, token_id), 0);
                self.entries.write((context_id, i), 0);
                self.scores.write((context_id, i), 0);
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

        /// Submit a score at an explicit position. Internal-only — hosts
        /// must validate (phase gates, eligibility, banning, qualification
        /// proofs, etc.) before invoking. Returns the placement outcome
        /// (`Success` / `NotQualified` / etc.) for the host to surface as
        /// it sees fit.
        ///
        /// Lives on the internal trait rather than the public `ILeaderboard`
        /// because the component cannot enforce the host's validation
        /// constraints; exposing it publicly would let any caller bypass
        /// them. Hosts call `self.leaderboard.submit_score(...)` from
        /// their own validated entrypoint.
        fn submit_score(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            token_id: felt252,
            score: u64,
            position: u32,
        ) -> LeaderboardResult {
            crate::leaderboard::api::LeaderboardInternalImpl::submit_score(
                ref self, context_id, token_id, score, position,
            )
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
