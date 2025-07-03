use core::num::traits::Zero;
use game_components_metagame::interface::{IMetagameDispatcher, IMetagameDispatcherTrait, IMETAGAME_ID};
use game_components_metagame::extensions::context::interface::IMETAGAME_CONTEXT_ID;
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use crate::common::constants;
use crate::common::helpers;

// INIT-01: Initialize with valid token address only
#[test]
fn test_initialize_with_token_only() {
    let token_address = constants::TOKEN_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let metagame = IMetagameDispatcher { contract_address };
    
    // Verify token address is set correctly
    assert(metagame.minigame_token_address() == token_address, 'Token address mismatch');
    
    // Verify context address is zero
    assert(metagame.context_address().is_zero(), 'Context should be zero');
}

// INIT-02: Initialize with token and context addresses
#[test]
fn test_initialize_with_token_and_context() {
    let token_address = constants::TOKEN_ADDRESS();
    let context_address = constants::CONTEXT_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(
        token_address, 
        Option::Some(context_address), 
        false
    );
    
    let metagame = IMetagameDispatcher { contract_address };
    
    // Verify both addresses are set correctly
    assert(metagame.minigame_token_address() == token_address, 'Token address mismatch');
    assert(metagame.context_address() == context_address, 'Context address mismatch');
}

// INIT-03: Initialize with zero token address should fail
#[test]
#[should_panic(expected: ('Calldata fail', ))]
fn test_initialize_with_zero_token_address() {
    // This test verifies that deployment fails with zero token address
    let zero_address = constants::ZERO_ADDRESS();
    helpers::deploy_mock_metagame(zero_address, Option::None, false);
}

// INIT-04: Query addresses after init
#[test]
fn test_query_addresses_after_init() {
    let token_address = constants::TOKEN_ADDRESS();
    let context_address = constants::CONTEXT_ADDRESS();
    
    // Test with both configurations
    let contract1 = helpers::deploy_mock_metagame(token_address, Option::None, false);
    let contract2 = helpers::deploy_mock_metagame(
        token_address, 
        Option::Some(context_address), 
        false
    );
    
    let metagame1 = IMetagameDispatcher { contract_address: contract1 };
    let metagame2 = IMetagameDispatcher { contract_address: contract2 };
    
    // Contract 1: token only
    assert(metagame1.minigame_token_address() == token_address, 'Token1 address mismatch');
    assert(metagame1.context_address().is_zero(), 'Context1 should be zero');
    
    // Contract 2: token and context
    assert(metagame2.minigame_token_address() == token_address, 'Token2 address mismatch');
    assert(metagame2.context_address() == context_address, 'Context2 address mismatch');
}

// INIT-05: Verify SRC5 registration
#[test]
fn test_src5_interface_registration() {
    let token_address = constants::TOKEN_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, false);
    
    let src5 = ISRC5Dispatcher { contract_address };
    
    // Verify IMETAGAME_ID is supported
    assert(src5.supports_interface(IMETAGAME_ID), 'IMETAGAME_ID not supported');
    
    // Verify ISRC5_ID is supported (standard interface)
    assert(src5.supports_interface(constants::ISRC5_ID), 'ISRC5_ID not supported');
    
    // Verify IMETAGAME_CONTEXT_ID is NOT supported by default
    assert(!src5.supports_interface(IMETAGAME_CONTEXT_ID), 'Context ID not supported');
}

// Additional test: Verify context interface registration when enabled
#[test]
fn test_context_interface_registration() {
    let token_address = constants::TOKEN_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(token_address, Option::None, true);
    
    let src5 = ISRC5Dispatcher { contract_address };
    
    // Verify both interfaces are supported
    assert(src5.supports_interface(IMETAGAME_ID), 'IMETAGAME_ID not supported');
    assert(src5.supports_interface(IMETAGAME_CONTEXT_ID), 'Context ID not supported');
}

// Additional test: Verify immutability of addresses
#[test]
fn test_addresses_are_immutable() {
    let token_address = constants::TOKEN_ADDRESS();
    let context_address = constants::CONTEXT_ADDRESS();
    let contract_address = helpers::deploy_mock_metagame(
        token_address, 
        Option::Some(context_address), 
        false
    );
    
    let metagame = IMetagameDispatcher { contract_address };
    
    // Read addresses multiple times to ensure they don't change
    let token1 = metagame.minigame_token_address();
    let context1 = metagame.context_address();
    
    // Advance block timestamp
    helpers::advance_block_timestamp(1000);
    
    let token2 = metagame.minigame_token_address();
    let context2 = metagame.context_address();
    
    // Verify addresses remain the same
    assert(token1 == token2, 'Token addresses changed');
    assert(context1 == context2, 'Context addresses changed');
    assert(token1 == token_address, 'Token address mismatch');
    assert(context1 == context_address, 'Context address mismatch');
}