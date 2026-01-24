// Test file for token/config.cairo
// Tests compile-time feature flag constants

use crate::config;

// =============================================================================
// CORE FEATURE TESTS
// =============================================================================

#[test]
fn test_core_token_enabled_is_true() {
    assert!(config::CORE_TOKEN_ENABLED == true, "CORE_TOKEN_ENABLED should be true");
}

#[test]
fn test_erc721_enabled_is_true() {
    assert!(config::ERC721_ENABLED == true, "ERC721_ENABLED should be true");
}

#[test]
fn test_src5_enabled_is_true() {
    assert!(config::SRC5_ENABLED == true, "SRC5_ENABLED should be true");
}

// =============================================================================
// OPTIONAL FEATURE TESTS
// =============================================================================

#[test]
fn test_minter_enabled_is_true() {
    assert!(config::MINTER_ENABLED == true, "MINTER_ENABLED should be true");
}

#[test]
fn test_multi_game_enabled_is_true() {
    assert!(config::MULTI_GAME_ENABLED == true, "MULTI_GAME_ENABLED should be true");
}

#[test]
fn test_objectives_enabled_is_true() {
    assert!(config::OBJECTIVES_ENABLED == true, "OBJECTIVES_ENABLED should be true");
}

#[test]
fn test_settings_enabled_is_true() {
    assert!(config::SETTINGS_ENABLED == true, "SETTINGS_ENABLED should be true");
}

#[test]
fn test_soulbound_enabled_is_true() {
    assert!(config::SOULBOUND_ENABLED == true, "SOULBOUND_ENABLED should be true");
}

#[test]
fn test_context_enabled_is_true() {
    assert!(config::CONTEXT_ENABLED == true, "CONTEXT_ENABLED should be true");
}

#[test]
fn test_renderer_enabled_is_true() {
    assert!(config::RENDERER_ENABLED == true, "RENDERER_ENABLED should be true");
}

// =============================================================================
// ADVANCED FEATURE TESTS
// =============================================================================

#[test]
fn test_lifecycle_enabled_is_true() {
    assert!(config::LIFECYCLE_ENABLED == true, "LIFECYCLE_ENABLED should be true");
}

#[test]
fn test_playability_enabled_is_true() {
    assert!(config::PLAYABILITY_ENABLED == true, "PLAYABILITY_ENABLED should be true");
}

// =============================================================================
// OPTIMIZATION TESTS
// =============================================================================

#[test]
fn test_compile_time_interfaces_is_true() {
    assert!(config::COMPILE_TIME_INTERFACES == true, "COMPILE_TIME_INTERFACES should be true");
}

// =============================================================================
// CONSISTENCY TESTS
// =============================================================================

#[test]
fn test_all_core_features_enabled() {
    // Verify all core features are enabled together
    assert!(
        config::CORE_TOKEN_ENABLED && config::ERC721_ENABLED && config::SRC5_ENABLED,
        "All core features should be enabled",
    );
}

#[test]
fn test_all_optional_features_enabled() {
    // Verify all optional features are enabled by default
    assert!(
        config::MINTER_ENABLED
            && config::MULTI_GAME_ENABLED
            && config::OBJECTIVES_ENABLED
            && config::SETTINGS_ENABLED
            && config::SOULBOUND_ENABLED
            && config::CONTEXT_ENABLED
            && config::RENDERER_ENABLED,
        "All optional features should be enabled by default",
    );
}

#[test]
fn test_all_advanced_features_enabled() {
    // Verify all advanced features are enabled by default
    assert!(
        config::LIFECYCLE_ENABLED && config::PLAYABILITY_ENABLED,
        "All advanced features should be enabled by default",
    );
}
