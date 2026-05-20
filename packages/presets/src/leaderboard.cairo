// SPDX-License-Identifier: BUSL-1.1

/// # Leaderboard Preset
///
/// A ready-to-deploy leaderboard contract for tournament management.
/// This preset provides a multi-tournament leaderboard with score submission,
/// ranking, and administrative controls.
///
/// ## Features
/// - Multi-tournament support (separate leaderboards per tournament_id)
/// - Score submission and automatic ranking
/// - Configurable leaderboard size and sorting per submission
/// - Position queries and qualification checks
/// - Administrative controls (owner-only)
/// - Event emission for all major actions
/// - SRC5 interface support
///
/// ## Usage
/// Deploy this contract with an owner, then use it to manage
/// leaderboards for multiple tournaments by submitting scores with tournament_id.
///
/// Note: `submit_score` is exposed publicly with NO validation — this is
/// a reference implementation. Production hosts (e.g. budokan) wrap
/// `LeaderboardInternalTrait::submit_score` in their own validated
/// entrypoint (phase gates, eligibility, banning, qualification proofs).
/// See `ILEADERBOARD_ID` in game_components_interfaces for the
/// rationale.

#[starknet::interface]
pub trait ILeaderboardPresetSubmit<TState> {
    fn submit_score(
        ref self: TState, context_id: u64, token_id: felt252, score: u64, position: u32,
    ) -> game_components_interfaces::leaderboard::LeaderboardResult;
}

#[starknet::contract]
mod LeaderboardPreset {
    use game_components_interfaces::leaderboard::LeaderboardResult;
    use game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::{
        LeaderboardAdminImpl, LeaderboardImpl, LeaderboardInternalTrait,
    };
    use game_components_metagame::leaderboard::leaderboard_component::{
        LeaderboardComponent, LeaderboardHooksEmptyImpl,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: LeaderboardComponent, storage: leaderboard, event: LeaderboardEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    impl LeaderboardHooks = LeaderboardHooksEmptyImpl<ContractState>;

    // Leaderboard Mixin
    #[abi(embed_v0)]
    impl LeaderboardMixinImpl =
        LeaderboardComponent::LeaderboardImpl<ContractState>;
    #[abi(embed_v0)]
    impl LeaderboardAdminMixinImpl =
        LeaderboardComponent::LeaderboardAdminImpl<ContractState>;

    // SRC5 Mixin
    #[abi(embed_v0)]
    impl SRC5MixinImpl = SRC5Component::SRC5Impl<ContractState>;

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

    /// Reference-impl public submit_score. Wraps the component's internal
    /// method with no extra validation — anyone can submit any score for
    /// any token_id. Real hosts must add their own validation.
    #[abi(embed_v0)]
    impl LeaderboardPresetSubmitImpl of super::ILeaderboardPresetSubmit<ContractState> {
        fn submit_score(
            ref self: ContractState, context_id: u64, token_id: felt252, score: u64, position: u32,
        ) -> LeaderboardResult {
            self.leaderboard.submit_score(context_id, token_id, score, position)
        }
    }
}
