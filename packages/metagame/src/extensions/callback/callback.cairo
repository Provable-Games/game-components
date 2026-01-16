// ==============================================================================
// METAGAME CALLBACK COMPONENT
// ==============================================================================
// A reusable component for receiving callbacks from token contracts when game
// state changes (score updates, game over, objectives completed).
//
// Uses the hooks pattern: the component provides infrastructure and SRC5
// registration, while implementations define actual callback behavior via traits.

#[starknet::component]
pub mod MetagameCallbackComponent {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use crate::extensions::callback::interface::{IMETAGAME_CALLBACK_ID, IMetagameCallback};

    // ==========================================================================
    // STORAGE
    // ==========================================================================

    #[storage]
    pub struct Storage {}

    // ==========================================================================
    // HOOKS TRAIT
    // ==========================================================================
    // Allows the embedding contract to define custom callback behavior.
    // Implementers can aggregate scores, emit events, update leaderboards, etc.

    pub trait MetagameCallbackHooksTrait<TContractState> {
        /// Called when a token's score is updated.
        /// @param token_id The token ID (packed u256)
        /// @param score The new score value
        fn on_score_update(ref self: TContractState, token_id: u256, score: u32);

        /// Called when a game ends (game_over transitions to true).
        /// @param token_id The token ID (packed u256)
        /// @param final_score The final score when game ended
        fn on_game_over(ref self: TContractState, token_id: u256, final_score: u32);

        /// Called when all objectives are completed.
        /// @param token_id The token ID (packed u256)
        fn on_objective_complete(ref self: TContractState, token_id: u256);
    }

    // ==========================================================================
    // EMBEDDABLE IMPLEMENTATION
    // ==========================================================================
    // Implements IMetagameCallback by delegating to hooks.
    // Contracts must provide a MetagameCallbackHooksTrait implementation.

    #[embeddable_as(MetagameCallbackImpl)]
    impl MetagameCallback<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +MetagameCallbackHooksTrait<TContractState>,
    > of IMetagameCallback<ComponentState<TContractState>> {
        fn on_score_update(ref self: ComponentState<TContractState>, token_id: u256, score: u32) {
            let mut contract = self.get_contract_mut();
            MetagameCallbackHooksTrait::on_score_update(ref contract, token_id, score);
        }

        fn on_game_over(
            ref self: ComponentState<TContractState>, token_id: u256, final_score: u32,
        ) {
            let mut contract = self.get_contract_mut();
            MetagameCallbackHooksTrait::on_game_over(ref contract, token_id, final_score);
        }

        fn on_objective_complete(ref self: ComponentState<TContractState>, token_id: u256) {
            let mut contract = self.get_contract_mut();
            MetagameCallbackHooksTrait::on_objective_complete(ref contract, token_id);
        }
    }

    // ==========================================================================
    // INTERNAL IMPLEMENTATION
    // ==========================================================================

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the component by registering the SRC5 interface.
        /// Should be called in the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMETAGAME_CALLBACK_ID);
        }
    }
}

// ==============================================================================
// EMPTY HOOKS IMPLEMENTATION
// ==============================================================================
// Provides a no-op implementation for contracts that don't need custom behavior.
// Use this when you want to receive callbacks but don't need to process them.

pub impl MetagameCallbackHooksEmptyImpl<
    TContractState,
> of MetagameCallbackComponent::MetagameCallbackHooksTrait<TContractState> {
    fn on_score_update(ref self: TContractState, token_id: u256, score: u32) {// No-op: contracts can override for custom score handling
    }

    fn on_game_over(ref self: TContractState, token_id: u256, final_score: u32) {// No-op: contracts can override for custom game over handling
    }

    fn on_objective_complete(ref self: TContractState, token_id: u256) {// No-op: contracts can override for custom objectives handling
    }
}
