// SPDX-License-Identifier: BUSL-1.1

/// # Leaderboard Preset
/// 
/// A ready-to-deploy leaderboard contract for tournament management.
/// This preset provides a simple, generic leaderboard with score submission,
/// ranking, and administrative controls.
///
/// ## Features
/// - Score submission and automatic ranking
/// - Configurable leaderboard size and sorting (ascending/descending)
/// - Position queries and qualification checks
/// - Administrative controls (owner-only)
/// - Event emission for all major actions
/// - SRC5 interface support
///
/// ## Usage
/// Deploy this contract with initial configuration, then use it to manage
/// a tournament leaderboard by submitting scores and querying rankings.

#[starknet::contract]
mod LeaderboardPreset {
    use game_components_leaderboard::interface::{ILeaderboard};
    use game_components_leaderboard::leaderboard_component::{
        leaderboard_component, leaderboard_component::LeaderboardImpl, 
        leaderboard_component::LeaderboardAdminImpl
    };
    
    use starknet::ContractAddress;
    
    use openzeppelin_introspection::src5::SRC5Component;

    component!(path: leaderboard_component, storage: leaderboard, event: LeaderboardEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Leaderboard Mixin
    #[abi(embed_v0)]
    impl LeaderboardMixinImpl = leaderboard_component::LeaderboardImpl<ContractState>;
    #[abi(embed_v0)]
    impl LeaderboardAdminMixinImpl = leaderboard_component::LeaderboardAdminImpl<ContractState>;

    // SRC5 Mixin
    #[abi(embed_v0)]
    impl SRC5MixinImpl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        leaderboard: leaderboard_component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        LeaderboardEvent: leaderboard_component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        tournament_id: u64,
        max_entries: u8,
        ascending: bool,
        game_address: ContractAddress
    ) {
        self.leaderboard.initialize(owner, tournament_id, max_entries, ascending, game_address);
    }
}