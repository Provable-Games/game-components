// =============================================================================
// TEST: extensions/callback/callback.cairo
// =============================================================================
// Tests for MetagameCallbackComponent

use game_components_testing::constants::MAX_U64;
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use crate::metagame::extensions::callback::interface::{
    IMETAGAME_CALLBACK_ID, IMetagameCallbackDispatcher, IMetagameCallbackDispatcherTrait,
};

// =============================================================================
// HELPER INTERFACES
// =============================================================================

#[starknet::interface]
trait IMockCallbackView<TContractState> {
    fn score_update_count(self: @TContractState) -> u32;
    fn game_over_count(self: @TContractState) -> u32;
    fn objective_complete_count(self: @TContractState) -> u32;
    fn last_token_id(self: @TContractState) -> u256;
    fn last_score(self: @TContractState) -> u64;
    fn last_final_score(self: @TContractState) -> u64;
}

// =============================================================================
// DEPLOYMENT HELPERS
// =============================================================================

fn TOKEN_ADDRESS() -> ContractAddress {
    0x70CE0.try_into().unwrap()
}

fn deploy_callback_contract() -> (ContractAddress, IMetagameCallbackDispatcher, ContractAddress) {
    let token_address = TOKEN_ADDRESS();
    // Mock supports_interface so MetagameComponent::initializer passes SRC5 check
    mock_call(token_address, selector!("supports_interface"), true, 100);

    let contract = declare("MockCallbackContract").unwrap().contract_class();
    // Constructor args: Option::None for context_address, then default_token_address
    let mut calldata = array![];
    calldata.append(1); // Option::None
    calldata.append(token_address.into());
    let (address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IMetagameCallbackDispatcher { contract_address: address };
    (address, dispatcher, token_address)
}

fn deploy_empty_callback_contract() -> (ContractAddress, ContractAddress) {
    let token_address = TOKEN_ADDRESS();
    mock_call(token_address, selector!("supports_interface"), true, 100);

    let contract = declare("MockEmptyCallbackContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // Option::None
    calldata.append(token_address.into());
    let (address, _) = contract.deploy(@calldata).unwrap();
    (address, token_address)
}

// =============================================================================
// INITIALIZER TESTS
// =============================================================================

// CB-U-01: Initialize component registers SRC5 interface
#[test]
fn test_callback_initializer_registers_src5_interface() {
    let (address, _, _) = deploy_callback_contract();

    let src5_dispatcher = ISRC5Dispatcher { contract_address: address };
    assert!(
        src5_dispatcher.supports_interface(IMETAGAME_CALLBACK_ID),
        "Should support IMetagameCallback interface",
    );
}

// CB-U-02: Verify ISRC5 base interface also registered
#[test]
fn test_callback_supports_src5_base() {
    let (address, _, _) = deploy_callback_contract();

    let src5_dispatcher = ISRC5Dispatcher { contract_address: address };
    assert!(
        src5_dispatcher.supports_interface(openzeppelin_interfaces::introspection::ISRC5_ID),
        "Should support ISRC5 base interface",
    );
}

// =============================================================================
// ON_SCORE_UPDATE TESTS
// =============================================================================

// CB-U-03: on_score_update delegates to hooks trait
#[test]
fn test_on_score_update_delegates_to_hooks() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    dispatcher.on_score_update(1, 100);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.score_update_count() == 1, "Score update count should be 1");
    assert!(view.last_token_id() == 1, "Token ID should be 1");
    assert!(view.last_score() == 100, "Score should be 100");
}

// CB-U-04: on_score_update with zero score
#[test]
fn test_on_score_update_with_zero_score() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    dispatcher.on_score_update(5, 0);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.last_token_id() == 5, "Token ID should be 5");
    assert!(view.last_score() == 0, "Score should be 0");
}

// CB-U-05: on_score_update with max u64 score
#[test]
fn test_on_score_update_with_max_score() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    dispatcher.on_score_update(1, MAX_U64);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.last_score() == MAX_U64, "Should handle max u64 score");
}

// CB-U-06: on_score_update with large token_id
#[test]
fn test_on_score_update_with_large_token_id() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    let large_token_id: u256 = 0xFFFFFFFFFFFFFFFF; // max u64 as u256
    start_cheat_caller_address(address, token_addr);
    dispatcher.on_score_update(large_token_id, 50);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.last_token_id() == large_token_id, "Should handle large token ID");
}

// CB-U-multiple: Multiple score updates
#[test]
fn test_on_score_update_multiple_calls() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    dispatcher.on_score_update(1, 100);
    dispatcher.on_score_update(2, 200);
    dispatcher.on_score_update(3, 300);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.score_update_count() == 3, "Score update count should be 3");
    assert!(view.last_token_id() == 3, "Last token ID should be 3");
    assert!(view.last_score() == 300, "Last score should be 300");
}

// =============================================================================
// ON_GAME_OVER TESTS
// =============================================================================

// CB-U-07: on_game_over delegates to hooks trait
#[test]
fn test_on_game_over_delegates_to_hooks() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    dispatcher.on_game_over(1, 500);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.game_over_count() == 1, "Game over count should be 1");
    assert!(view.last_token_id() == 1, "Token ID should be 1");
    assert!(view.last_final_score() == 500, "Final score should be 500");
}

// CB-U-08: on_game_over with zero final_score
#[test]
fn test_on_game_over_with_zero_final_score() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    dispatcher.on_game_over(10, 0);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.last_token_id() == 10, "Token ID should be 10");
    assert!(view.last_final_score() == 0, "Final score should be 0");
}

// CB-U-09: on_game_over with max u64 final_score
#[test]
fn test_on_game_over_with_max_final_score() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    dispatcher.on_game_over(1, MAX_U64);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.last_final_score() == MAX_U64, "Should handle max u64 final score");
}

// CB-U-10: on_game_over called multiple times (idempotent handling)
#[test]
fn test_on_game_over_multiple_calls() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    dispatcher.on_game_over(1, 100);
    dispatcher.on_game_over(1, 100);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.game_over_count() == 2, "Should receive both calls");
}

// =============================================================================
// ON_OBJECTIVE_COMPLETE TESTS
// =============================================================================

// CB-U-11: on_objective_complete delegates to hooks trait
#[test]
fn test_on_objective_complete_delegates_to_hooks() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    dispatcher.on_objective_complete(42);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.objective_complete_count() == 1, "Objective complete count should be 1");
    assert!(view.last_token_id() == 42, "Token ID should be 42");
}

// CB-U-12: on_objective_complete with various token_ids
#[test]
fn test_on_objective_complete_various_token_ids() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    dispatcher.on_objective_complete(1);
    dispatcher.on_objective_complete(100);
    dispatcher.on_objective_complete(1000);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.objective_complete_count() == 3, "Should have 3 objective completions");
    assert!(view.last_token_id() == 1000, "Last token ID should be 1000");
}

// CB-U-13: on_objective_complete with large token_id
#[test]
fn test_on_objective_complete_with_large_token_id() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    let large_token_id: u256 = 0xFFFFFFFFFFFFFFFF;
    start_cheat_caller_address(address, token_addr);
    dispatcher.on_objective_complete(large_token_id);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.last_token_id() == large_token_id, "Should handle large token ID");
}

// =============================================================================
// EMPTY HOOKS IMPLEMENTATION TESTS
// =============================================================================

// CB-U-14: Empty hooks on_score_update is no-op
#[test]
fn test_empty_hooks_on_score_update() {
    let (address, token_addr) = deploy_empty_callback_contract();
    let dispatcher = IMetagameCallbackDispatcher { contract_address: address };

    start_cheat_caller_address(address, token_addr);
    // Should not panic
    dispatcher.on_score_update(1, 100);
    stop_cheat_caller_address(address);
}

// CB-U-15: Empty hooks on_game_over is no-op
#[test]
fn test_empty_hooks_on_game_over() {
    let (address, token_addr) = deploy_empty_callback_contract();
    let dispatcher = IMetagameCallbackDispatcher { contract_address: address };

    start_cheat_caller_address(address, token_addr);
    // Should not panic
    dispatcher.on_game_over(1, 500);
    stop_cheat_caller_address(address);
}

// CB-U-16: Empty hooks on_objective_complete is no-op
#[test]
fn test_empty_hooks_on_objective_complete() {
    let (address, token_addr) = deploy_empty_callback_contract();
    let dispatcher = IMetagameCallbackDispatcher { contract_address: address };

    start_cheat_caller_address(address, token_addr);
    // Should not panic
    dispatcher.on_objective_complete(1);
    stop_cheat_caller_address(address);
}

// =============================================================================
// CALLER VALIDATION / REJECTION TESTS
// =============================================================================

// CB-U-17: on_score_update rejects unauthorized caller
#[test]
#[should_panic(expected: "MetagameCallback: caller is not the token contract")]
fn test_on_score_update_rejects_unauthorized_caller() {
    let (_, dispatcher, _) = deploy_callback_contract();
    // Call without cheating caller — default caller is not the token address
    dispatcher.on_score_update(1, 100);
}

// CB-U-18: on_game_over rejects unauthorized caller
#[test]
#[should_panic(expected: "MetagameCallback: caller is not the token contract")]
fn test_on_game_over_rejects_unauthorized_caller() {
    let (_, dispatcher, _) = deploy_callback_contract();
    dispatcher.on_game_over(1, 500);
}

// CB-U-19: on_objective_complete rejects unauthorized caller
#[test]
#[should_panic(expected: "MetagameCallback: caller is not the token contract")]
fn test_on_objective_complete_rejects_unauthorized_caller() {
    let (_, dispatcher, _) = deploy_callback_contract();
    dispatcher.on_objective_complete(42);
}

// =============================================================================
// FUZZ TESTS
// =============================================================================

// CB-F-01: Fuzz on_score_update parameters
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_on_score_update(token_id: u64, score: u64) {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    // Convert u64 to u256 for the interface
    let token_id_u256: u256 = token_id.into();
    start_cheat_caller_address(address, token_addr);
    dispatcher.on_score_update(token_id_u256, score);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.last_token_id() == token_id_u256, "Token ID should match");
    assert!(view.last_score() == score, "Score should match");
}

// CB-F-02: Fuzz on_game_over parameters
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_on_game_over(token_id: u64, final_score: u64) {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    let token_id_u256: u256 = token_id.into();
    start_cheat_caller_address(address, token_addr);
    dispatcher.on_game_over(token_id_u256, final_score);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.last_token_id() == token_id_u256, "Token ID should match");
    assert!(view.last_final_score() == final_score, "Final score should match");
}

// CB-F-03: Fuzz on_objective_complete token_id
#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_on_objective_complete(token_id: u64) {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    let token_id_u256: u256 = token_id.into();
    start_cheat_caller_address(address, token_addr);
    dispatcher.on_objective_complete(token_id_u256);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.last_token_id() == token_id_u256, "Token ID should match");
}

// =============================================================================
// COMBINED CALLBACK TESTS
// =============================================================================

// Test multiple callback types in sequence
#[test]
fn test_multiple_callback_types() {
    let (address, dispatcher, token_addr) = deploy_callback_contract();

    start_cheat_caller_address(address, token_addr);
    // Score update
    dispatcher.on_score_update(1, 100);

    // Game over
    dispatcher.on_game_over(1, 500);

    // Objective complete
    dispatcher.on_objective_complete(1);
    stop_cheat_caller_address(address);

    let view = IMockCallbackViewDispatcher { contract_address: address };
    assert!(view.score_update_count() == 1, "Should have 1 score update");
    assert!(view.game_over_count() == 1, "Should have 1 game over");
    assert!(view.objective_complete_count() == 1, "Should have 1 objective complete");
}

// =============================================================================
// MOCK CONTRACTS
// =============================================================================

// Mock callback contract with tracking hooks
#[starknet::contract]
mod MockCallbackContract {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::metagame::extensions::callback::callback::MetagameCallbackComponent;
    use crate::metagame::metagame_component::MetagameComponent;
    use super::IMockCallbackView;

    component!(path: MetagameCallbackComponent, storage: callback, event: CallbackEvent);
    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Custom hooks implementation that tracks calls
    impl CallbackHooksImpl of MetagameCallbackComponent::MetagameCallbackHooksTrait<ContractState> {
        fn on_score_update(ref self: ContractState, token_id: u256, score: u64) {
            self.score_update_count.write(self.score_update_count.read() + 1);
            self.last_token_id.write(token_id);
            self.cb_last_score.write(score);
        }

        fn on_game_over(ref self: ContractState, token_id: u256, final_score: u64) {
            self.game_over_count.write(self.game_over_count.read() + 1);
            self.last_token_id.write(token_id);
            self.cb_last_final_score.write(final_score);
        }

        fn on_objective_complete(ref self: ContractState, token_id: u256) {
            self.objective_complete_count.write(self.objective_complete_count.read() + 1);
            self.last_token_id.write(token_id);
        }
    }

    #[abi(embed_v0)]
    impl MetagameCallbackImpl =
        MetagameCallbackComponent::MetagameCallbackImpl<ContractState>;
    impl CallbackInternalImpl = MetagameCallbackComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl MetagameImpl = MetagameComponent::MetagameImpl<ContractState>;
    impl MetagameInternalImpl = MetagameComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        callback: MetagameCallbackComponent::Storage,
        #[substorage(v0)]
        metagame: MetagameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Tracking storage
        score_update_count: u32,
        game_over_count: u32,
        objective_complete_count: u32,
        last_token_id: u256,
        cb_last_score: u64,
        cb_last_final_score: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        CallbackEvent: MetagameCallbackComponent::Event,
        #[flat]
        MetagameEvent: MetagameComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        context_address: Option<ContractAddress>,
        default_token_address: ContractAddress,
    ) {
        self.metagame.initializer(context_address, default_token_address);
        self.callback.initializer();
    }

    // View functions for test assertions
    #[abi(embed_v0)]
    impl MockCallbackViewImpl of IMockCallbackView<ContractState> {
        fn score_update_count(self: @ContractState) -> u32 {
            self.score_update_count.read()
        }

        fn game_over_count(self: @ContractState) -> u32 {
            self.game_over_count.read()
        }

        fn objective_complete_count(self: @ContractState) -> u32 {
            self.objective_complete_count.read()
        }

        fn last_token_id(self: @ContractState) -> u256 {
            self.last_token_id.read()
        }

        fn last_score(self: @ContractState) -> u64 {
            self.cb_last_score.read()
        }

        fn last_final_score(self: @ContractState) -> u64 {
            self.cb_last_final_score.read()
        }
    }
}

// Mock callback contract using empty hooks implementation
#[starknet::contract]
mod MockEmptyCallbackContract {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::metagame::extensions::callback::callback::{
        MetagameCallbackComponent, MetagameCallbackHooksEmptyImpl,
    };
    use crate::metagame::metagame_component::MetagameComponent;

    component!(path: MetagameCallbackComponent, storage: callback, event: CallbackEvent);
    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Use the empty hooks implementation
    impl CallbackHooksImpl = MetagameCallbackHooksEmptyImpl<ContractState>;

    #[abi(embed_v0)]
    impl MetagameCallbackImpl =
        MetagameCallbackComponent::MetagameCallbackImpl<ContractState>;
    impl CallbackInternalImpl = MetagameCallbackComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl MetagameImpl = MetagameComponent::MetagameImpl<ContractState>;
    impl MetagameInternalImpl = MetagameComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        callback: MetagameCallbackComponent::Storage,
        #[substorage(v0)]
        metagame: MetagameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        CallbackEvent: MetagameCallbackComponent::Event,
        #[flat]
        MetagameEvent: MetagameComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        context_address: Option<ContractAddress>,
        default_token_address: ContractAddress,
    ) {
        self.metagame.initializer(context_address, default_token_address);
        self.callback.initializer();
    }
}
