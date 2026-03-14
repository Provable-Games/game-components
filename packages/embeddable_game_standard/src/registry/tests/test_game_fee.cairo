// ==============================================================================
// GAME FEE TESTS
// ==============================================================================
// Tests for the game fee functionality (ERC2981-inspired default + override).

use game_components_embeddable_game_standard::registry::interface::{
    DEFAULT_GAME_FEE_BPS, FEE_DENOMINATOR, IMinigameRegistryDispatcher,
    IMinigameRegistryDispatcherTrait, default_license,
};
use game_components_embeddable_game_standard::registry::registry_component::MinigameRegistryComponent;
use game_components_testing::constants::CREATOR;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, mock_call, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

// ==============================================================================
// HELPERS
// ==============================================================================

fn deploy_mock_registry_with_erc721() -> IMinigameRegistryDispatcher {
    let contract = declare("MockRegistryWithERC721").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    IMinigameRegistryDispatcher { contract_address }
}

fn deploy_mock_minigame_for_registration() -> ContractAddress {
    let contract = declare("registry_minigame_mock").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

fn register_game(registry: IMinigameRegistryDispatcher, game_address: ContractAddress) -> u64 {
    mock_call(game_address, selector!("supports_interface"), true, 10);
    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Test Game",
            "Description",
            "Developer",
            "Publisher",
            "Genre",
            "Image",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            1,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);
    game_id
}

// ==============================================================================
// DEFAULT FEE INITIALIZATION
// ==============================================================================

#[test]
fn test_default_game_fee_initialized() {
    let registry = deploy_mock_registry_with_erc721();
    let info = registry.default_game_fee_info();

    assert!(info.fee_numerator == DEFAULT_GAME_FEE_BPS, "Default fee should be 500 bps");
    assert!(info.license == default_license(), "Default license should match");
}

#[test]
fn test_game_fee_info_returns_default_when_no_override() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    let info = registry.game_fee_info(game_id);
    assert!(info.fee_numerator == DEFAULT_GAME_FEE_BPS, "Should return default fee");
    assert!(info.license == default_license(), "Should return default license");
}

// ==============================================================================
// SET DEFAULT GAME FEE
// ==============================================================================

#[test]
fn test_set_default_game_fee() {
    let registry = deploy_mock_registry_with_erc721();

    registry.set_default_game_fee("Custom License", 1000);

    let info = registry.default_game_fee_info();
    assert!(info.fee_numerator == 1000, "Default fee should be updated to 1000");
    assert!(info.license == "Custom License", "Default license should be updated");
}

#[test]
fn test_set_default_game_fee_emits_event() {
    let registry = deploy_mock_registry_with_erc721();

    let mut spy = spy_events();

    registry.set_default_game_fee("New License", 750);

    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    MinigameRegistryComponent::Event::DefaultGameFeeUpdate(
                        MinigameRegistryComponent::DefaultGameFeeUpdate {
                            license: "New License", fee_numerator: 750,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic]
fn test_set_default_game_fee_exceeds_denominator() {
    let registry = deploy_mock_registry_with_erc721();
    registry.set_default_game_fee("License", FEE_DENOMINATOR + 1);
}

#[test]
fn test_set_default_game_fee_to_zero() {
    let registry = deploy_mock_registry_with_erc721();
    registry.set_default_game_fee("Free License", 0);

    let info = registry.default_game_fee_info();
    assert!(info.fee_numerator == 0, "Fee should be 0");
    assert!(info.license == "Free License", "License should be set");
}

#[test]
fn test_set_default_game_fee_max_value() {
    let registry = deploy_mock_registry_with_erc721();
    registry.set_default_game_fee("Max License", FEE_DENOMINATOR);

    let info = registry.default_game_fee_info();
    assert!(info.fee_numerator == FEE_DENOMINATOR, "Fee should be max");
}

// ==============================================================================
// SET GAME FEE (PER-GAME OVERRIDE)
// ==============================================================================

#[test]
fn test_set_game_fee_override() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(game_id, "Custom Game License", 300);
    stop_cheat_caller_address(registry.contract_address);

    let info = registry.game_fee_info(game_id);
    assert!(info.fee_numerator == 300, "Game fee should be overridden to 300");
    assert!(info.license == "Custom Game License", "Game license should be overridden");
}

#[test]
fn test_set_game_fee_does_not_affect_default() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(game_id, "Game License", 200);
    stop_cheat_caller_address(registry.contract_address);

    // Default should remain unchanged
    let default_info = registry.default_game_fee_info();
    assert!(default_info.fee_numerator == DEFAULT_GAME_FEE_BPS, "Default fee unchanged");
}

#[test]
fn test_set_game_fee_emits_event() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    let mut spy = spy_events();

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(game_id, "Event License", 400);
    stop_cheat_caller_address(registry.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    MinigameRegistryComponent::Event::GameFeeUpdate(
                        MinigameRegistryComponent::GameFeeUpdate {
                            game_id, license: "Event License", fee_numerator: 400,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic]
fn test_set_game_fee_fails_non_owner() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    let non_owner: ContractAddress = 0x999.try_into().unwrap();
    start_cheat_caller_address(registry.contract_address, non_owner);
    registry.set_game_fee(game_id, "Bad License", 100);
    stop_cheat_caller_address(registry.contract_address);
}

#[test]
#[should_panic]
fn test_set_game_fee_invalid_game_id() {
    let registry = deploy_mock_registry_with_erc721();

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(999, "License", 100);
    stop_cheat_caller_address(registry.contract_address);
}

#[test]
#[should_panic]
fn test_set_game_fee_exceeds_denominator() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(game_id, "License", FEE_DENOMINATOR + 1);
    stop_cheat_caller_address(registry.contract_address);
}

// ==============================================================================
// RESET GAME FEE
// ==============================================================================

#[test]
fn test_reset_game_fee_returns_to_default() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    // Set override
    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(game_id, "Custom License", 100);

    // Verify override
    let info = registry.game_fee_info(game_id);
    assert!(info.fee_numerator == 100, "Should have override");

    // Reset
    registry.reset_game_fee(game_id);
    stop_cheat_caller_address(registry.contract_address);

    // Should return default
    let info = registry.game_fee_info(game_id);
    assert!(info.fee_numerator == DEFAULT_GAME_FEE_BPS, "Should return default after reset");
    assert!(info.license == default_license(), "Should return default license after reset");
}

#[test]
fn test_reset_game_fee_emits_event_with_default_values() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(game_id, "Custom", 100);

    let mut spy = spy_events();
    registry.reset_game_fee(game_id);
    stop_cheat_caller_address(registry.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    MinigameRegistryComponent::Event::GameFeeUpdate(
                        MinigameRegistryComponent::GameFeeUpdate {
                            game_id,
                            license: default_license(),
                            fee_numerator: DEFAULT_GAME_FEE_BPS,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic]
fn test_reset_game_fee_fails_non_owner() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    let non_owner: ContractAddress = 0x999.try_into().unwrap();
    start_cheat_caller_address(registry.contract_address, non_owner);
    registry.reset_game_fee(game_id);
    stop_cheat_caller_address(registry.contract_address);
}

// ==============================================================================
// GAME FEE QUERY (FALLBACK LOGIC)
// ==============================================================================

#[test]
fn test_game_fee_info_override_takes_precedence() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(game_id, "Override License", 200);
    stop_cheat_caller_address(registry.contract_address);

    let info = registry.game_fee_info(game_id);
    assert!(info.fee_numerator == 200, "Override should take precedence");
    assert!(info.license == "Override License", "Override license should be returned");
}

#[test]
fn test_game_fee_info_different_games_independent() {
    let registry = deploy_mock_registry_with_erc721();

    let game_address1 = deploy_mock_minigame_for_registration();
    let game_id1 = register_game(registry, game_address1);

    let game_address2 = deploy_mock_minigame_for_registration();
    let game_id2 = register_game(registry, game_address2);

    // Override only game 1
    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(game_id1, "Game 1 License", 100);
    stop_cheat_caller_address(registry.contract_address);

    // Game 1 should have override
    let info1 = registry.game_fee_info(game_id1);
    assert!(info1.fee_numerator == 100, "Game 1 should have override");

    // Game 2 should have default
    let info2 = registry.game_fee_info(game_id2);
    assert!(info2.fee_numerator == DEFAULT_GAME_FEE_BPS, "Game 2 should have default");
}

#[test]
fn test_set_default_affects_games_without_override() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    // Change default
    registry.set_default_game_fee("New Default", 800);

    // Game with no override should reflect new default
    let info = registry.game_fee_info(game_id);
    assert!(info.fee_numerator == 800, "Should reflect updated default");
    assert!(info.license == "New Default", "Should reflect updated default license");
}

#[test]
fn test_set_default_does_not_affect_overridden_games() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    // Set override
    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(game_id, "Override", 300);
    stop_cheat_caller_address(registry.contract_address);

    // Change default
    registry.set_default_game_fee("New Default", 900);

    // Game with override should still have override
    let info = registry.game_fee_info(game_id);
    assert!(info.fee_numerator == 300, "Override should be unaffected by default change");
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer(runs: 256)]
fn test_fuzz_set_game_fee_valid_range(fee_numerator: u16) {
    if fee_numerator > FEE_DENOMINATOR {
        return;
    }

    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();
    let game_id = register_game(registry, game_address);

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_fee(game_id, "License", fee_numerator);
    stop_cheat_caller_address(registry.contract_address);

    let info = registry.game_fee_info(game_id);
    assert!(info.fee_numerator == fee_numerator, "Fee should match set value");
}
