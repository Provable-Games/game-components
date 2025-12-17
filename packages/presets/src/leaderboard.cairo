// SPDX-License-Identifier: BUSL-1.1

/// # Leaderboard Preset
<<<<<<< HEAD
///
/// A ready-to-deploy leaderboard contract for tournament management.
/// This preset provides a multi-tournament leaderboard with score submission,
/// ranking, and administrative controls.
///
/// ## Features
/// - Multi-tournament support (separate leaderboards per tournament_id)
/// - Score submission and automatic ranking
/// - Configurable leaderboard size and sorting per submission
=======
/// 
/// A ready-to-deploy leaderboard contract for tournament management.
/// This preset provides a simple, generic leaderboard with score submission,
/// ranking, and administrative controls.
///
/// ## Features
/// - Score submission and automatic ranking
/// - Configurable leaderboard size and sorting (ascending/descending)
>>>>>>> main
/// - Position queries and qualification checks
/// - Administrative controls (owner-only)
/// - Event emission for all major actions
/// - SRC5 interface support
///
/// ## Usage
<<<<<<< HEAD
/// Deploy this contract with an owner, then use it to manage
/// leaderboards for multiple tournaments by submitting scores with tournament_id.

#[starknet::contract]
mod LeaderboardPreset {
    use game_components_leaderboard::leaderboard_component::LeaderboardComponent;
    use game_components_leaderboard::leaderboard_component::LeaderboardComponent::{
        LeaderboardAdminImpl, LeaderboardImpl, LeaderboardInternalTrait,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: LeaderboardComponent, storage: leaderboard, event: LeaderboardEvent);
=======
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
>>>>>>> main
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Leaderboard Mixin
    #[abi(embed_v0)]
<<<<<<< HEAD
    impl LeaderboardMixinImpl =
        LeaderboardComponent::LeaderboardImpl<ContractState>;
    #[abi(embed_v0)]
    impl LeaderboardAdminMixinImpl =
        LeaderboardComponent::LeaderboardAdminImpl<ContractState>;
=======
    impl LeaderboardMixinImpl = leaderboard_component::LeaderboardImpl<ContractState>;
    #[abi(embed_v0)]
    impl LeaderboardAdminMixinImpl = leaderboard_component::LeaderboardAdminImpl<ContractState>;
>>>>>>> main

    // SRC5 Mixin
    #[abi(embed_v0)]
    impl SRC5MixinImpl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
<<<<<<< HEAD
        leaderboard: LeaderboardComponent::Storage,
=======
        leaderboard: leaderboard_component::Storage,
>>>>>>> main
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
<<<<<<< HEAD
        LeaderboardEvent: LeaderboardComponent::Event,
=======
        LeaderboardEvent: leaderboard_component::Event,
>>>>>>> main
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
<<<<<<< HEAD
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.leaderboard.initializer(owner);
    }
}
=======
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
>>>>>>> main
