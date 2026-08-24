// ==============================================================================
// METAGAME CALLBACK COMPONENT
// ==============================================================================
// A reusable component for receiving callbacks from token contracts when game
// state changes (score updates, game over, objectives completed).
//
// Uses the hooks pattern: the component provides infrastructure and SRC5
// registration, while implementations define actual callback behavior via traits.
//
// Callbacks are a LEGACY-token concept: they fire from `update_game()`, which
// the standard self-bound token does not have. The component therefore stores
// its own legacy token address rather than reading one off MetagameComponent,
// which no longer carries a metagame-wide default token.

#[starknet::component]
pub mod MetagameCallbackComponent {
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::metagame::extensions::callback::interface::{
        IMETAGAME_CALLBACK_ID, IMetagameCallback,
    };

    // ==========================================================================
    // STORAGE
    // ==========================================================================

    #[storage]
    pub struct Storage {
        /// The legacy token contract allowed to invoke these callbacks.
        token_address: ContractAddress,
    }

    // ==========================================================================
    // HOOKS TRAIT
    // ==========================================================================
    // Allows the embedding contract to define custom callback behavior.
    // Implementers can aggregate scores, emit events, update leaderboards, etc.

    pub trait MetagameCallbackHooksTrait<TContractState> {
        /// Called on every update_game() call to notify the metagame of a game action.
        /// @param token_id The token ID (packed u256)
        /// @param score The current score value
        fn on_game_action(ref self: TContractState, token_id: u256, score: u64);

        /// Called when a game ends (game_over transitions to true).
        /// @param token_id The token ID (packed u256)
        /// @param final_score The final score when game ended
        fn on_game_over(ref self: TContractState, token_id: u256, final_score: u64);

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
        impl SRC5: SRC5Component::HasComponent<TContractState>,
    > of IMetagameCallback<ComponentState<TContractState>> {
        fn on_game_action(ref self: ComponentState<TContractState>, token_id: u256, score: u64) {
            self.assert_only_token();
            let mut contract = self.get_contract_mut();
            MetagameCallbackHooksTrait::on_game_action(ref contract, token_id, score);
        }

        fn on_game_over(
            ref self: ComponentState<TContractState>, token_id: u256, final_score: u64,
        ) {
            self.assert_only_token();
            let mut contract = self.get_contract_mut();
            MetagameCallbackHooksTrait::on_game_over(ref contract, token_id, final_score);
        }

        fn on_objective_complete(ref self: ComponentState<TContractState>, token_id: u256) {
            self.assert_only_token();
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
        /// Initializes the component by registering the SRC5 interface and
        /// binding the legacy token allowed to call back.
        /// Should be called in the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>, token_address: ContractAddress) {
            assert!(!token_address.is_zero(), "MetagameCallback: token address is zero");
            self.token_address.write(token_address);
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMETAGAME_CALLBACK_ID);
        }

        /// The legacy token contract bound at initialization.
        fn token_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.token_address.read()
        }

        /// Asserts that the caller is the bound token contract.
        fn assert_only_token(self: @ComponentState<TContractState>) {
            assert!(
                get_caller_address() == self.token_address.read(),
                "MetagameCallback: caller is not the token contract",
            );
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
    fn on_game_action(
        ref self: TContractState, token_id: u256, score: u64,
    ) { // No-op: contracts can override for custom game action handling
    }

    fn on_game_over(
        ref self: TContractState, token_id: u256, final_score: u64,
    ) { // No-op: contracts can override for custom game over handling
    }

    fn on_objective_complete(
        ref self: TContractState, token_id: u256,
    ) { // No-op: contracts can override for custom objectives handling
    }
}
