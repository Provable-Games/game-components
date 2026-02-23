// Test file for token/libs/address_utils.cairo
// Tests pure address utility functions

use core::num::traits::Zero;
use starknet::ContractAddress;
use crate::token::token::address_utils::{
    address_to_option, addresses_equal, assert_not_zero_address, has_non_zero_address,
    is_non_zero_address, is_zero_address, unwrap_or_address, unwrap_or_zero,
};

// =============================================================================
// TEST HELPERS
// =============================================================================

fn ADDR_1() -> ContractAddress {
    0x123.try_into().unwrap()
}

fn ADDR_2() -> ContractAddress {
    0x456.try_into().unwrap()
}

fn ADDR_3() -> ContractAddress {
    0x789.try_into().unwrap()
}

fn MAX_ADDR() -> ContractAddress {
    // Use a large address value for edge case testing
    0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff.try_into().unwrap()
}

// =============================================================================
// ADDRESS_TO_OPTION TESTS
// =============================================================================

#[test]
fn test_address_to_option_zero_returns_none() {
    let zero: ContractAddress = Zero::zero();
    let result = address_to_option(zero);
    assert!(result.is_none(), "Zero address should return None");
}

#[test]
fn test_address_to_option_non_zero_returns_some() {
    let addr = ADDR_1();
    let result = address_to_option(addr);
    assert!(result.is_some(), "Non-zero address should return Some");
    assert!(result.unwrap() == addr, "Should return same address");
}

#[test]
fn test_address_to_option_various_addresses() {
    // Test with multiple different addresses
    let addr1 = ADDR_1();
    let addr2 = ADDR_2();
    let addr3 = ADDR_3();

    let result1 = address_to_option(addr1);
    let result2 = address_to_option(addr2);
    let result3 = address_to_option(addr3);

    assert!(result1.is_some() && result1.unwrap() == addr1, "ADDR_1 should return Some(ADDR_1)");
    assert!(result2.is_some() && result2.unwrap() == addr2, "ADDR_2 should return Some(ADDR_2)");
    assert!(result3.is_some() && result3.unwrap() == addr3, "ADDR_3 should return Some(ADDR_3)");
}

// =============================================================================
// IS_ZERO_ADDRESS TESTS
// =============================================================================

#[test]
fn test_is_zero_address_with_zero() {
    let zero: ContractAddress = Zero::zero();
    assert!(is_zero_address(zero), "Zero address should return true");
}

#[test]
fn test_is_zero_address_with_non_zero() {
    let addr = ADDR_1();
    assert!(!is_zero_address(addr), "Non-zero address should return false");
}

#[test]
fn test_is_zero_address_with_max_value() {
    let max_addr = MAX_ADDR();
    assert!(!is_zero_address(max_addr), "Max address should return false");
}

// =============================================================================
// IS_NON_ZERO_ADDRESS TESTS
// =============================================================================

#[test]
fn test_is_non_zero_address_with_zero() {
    let zero: ContractAddress = Zero::zero();
    assert!(!is_non_zero_address(zero), "Zero address should return false");
}

#[test]
fn test_is_non_zero_address_with_non_zero() {
    let addr = ADDR_1();
    assert!(is_non_zero_address(addr), "Non-zero address should return true");
}

#[test]
fn test_is_non_zero_address_with_max_value() {
    let max_addr = MAX_ADDR();
    assert!(is_non_zero_address(max_addr), "Max address should return true");
}

// =============================================================================
// ASSERT_NOT_ZERO_ADDRESS TESTS
// =============================================================================

#[test]
fn test_assert_not_zero_address_with_non_zero_passes() {
    let addr = ADDR_1();
    assert_not_zero_address(addr, 'Should not panic');
    // If we reach here, test passed
}

#[test]
#[should_panic(expected: 'Invalid address')]
fn test_assert_not_zero_address_with_zero_panics() {
    let zero: ContractAddress = Zero::zero();
    assert_not_zero_address(zero, 'Invalid address');
}

#[test]
#[should_panic(expected: 'Custom error')]
fn test_assert_not_zero_address_custom_error_message() {
    let zero: ContractAddress = Zero::zero();
    assert_not_zero_address(zero, 'Custom error');
}

// =============================================================================
// UNWRAP_OR_ADDRESS TESTS
// =============================================================================

#[test]
fn test_unwrap_or_address_some_returns_value() {
    let addr1 = ADDR_1();
    let addr2 = ADDR_2();
    let result = unwrap_or_address(Option::Some(addr1), addr2);
    assert!(result == addr1, "Should return the wrapped value");
}

#[test]
fn test_unwrap_or_address_none_returns_default() {
    let addr2 = ADDR_2();
    let result = unwrap_or_address(Option::None, addr2);
    assert!(result == addr2, "Should return the default value");
}

#[test]
fn test_unwrap_or_address_none_with_zero_default() {
    let zero: ContractAddress = Zero::zero();
    let result = unwrap_or_address(Option::None, zero);
    assert!(result == zero, "Should return zero when default is zero");
}

#[test]
fn test_unwrap_or_address_some_ignores_default() {
    let addr1 = ADDR_1();
    let zero: ContractAddress = Zero::zero();
    let result = unwrap_or_address(Option::Some(addr1), zero);
    assert!(result == addr1, "Should ignore default when Some");
}

// =============================================================================
// UNWRAP_OR_ZERO TESTS
// =============================================================================

#[test]
fn test_unwrap_or_zero_some_returns_value() {
    let addr = ADDR_1();
    let result = unwrap_or_zero(Option::Some(addr));
    assert!(result == addr, "Should return the wrapped value");
}

#[test]
fn test_unwrap_or_zero_none_returns_zero() {
    let result = unwrap_or_zero(Option::None);
    let zero: ContractAddress = Zero::zero();
    assert!(result == zero, "Should return zero address for None");
}

#[test]
fn test_unwrap_or_zero_some_zero_returns_zero() {
    let zero: ContractAddress = Zero::zero();
    let result = unwrap_or_zero(Option::Some(zero));
    assert!(result == zero, "Should return zero when wrapped value is zero");
}

// =============================================================================
// ADDRESSES_EQUAL TESTS
// =============================================================================

#[test]
fn test_addresses_equal_same_address() {
    let addr = ADDR_1();
    assert!(addresses_equal(addr, addr), "Same address should be equal");
}

#[test]
fn test_addresses_equal_different_addresses() {
    let addr1 = ADDR_1();
    let addr2 = ADDR_2();
    assert!(!addresses_equal(addr1, addr2), "Different addresses should not be equal");
}

#[test]
fn test_addresses_equal_both_zero() {
    let zero1: ContractAddress = Zero::zero();
    let zero2: ContractAddress = Zero::zero();
    assert!(addresses_equal(zero1, zero2), "Both zero addresses should be equal");
}

#[test]
fn test_addresses_equal_symmetry() {
    let addr1 = ADDR_1();
    let addr2 = ADDR_2();
    // Test symmetric property: a == b iff b == a
    assert!(
        addresses_equal(addr1, addr2) == addresses_equal(addr2, addr1),
        "addresses_equal should be symmetric",
    );
}

// =============================================================================
// HAS_NON_ZERO_ADDRESS TESTS
// =============================================================================

#[test]
fn test_has_non_zero_address_empty_array() {
    let addresses: Array<ContractAddress> = array![];
    assert!(!has_non_zero_address(@addresses), "Empty array should return false");
}

#[test]
fn test_has_non_zero_address_all_zero() {
    let zero: ContractAddress = Zero::zero();
    let addresses: Array<ContractAddress> = array![zero, zero, zero];
    assert!(!has_non_zero_address(@addresses), "All zero addresses should return false");
}

#[test]
fn test_has_non_zero_address_first_non_zero() {
    let zero: ContractAddress = Zero::zero();
    let addr = ADDR_1();
    let addresses: Array<ContractAddress> = array![addr, zero, zero];
    assert!(has_non_zero_address(@addresses), "First non-zero should return true");
}

#[test]
fn test_has_non_zero_address_last_non_zero() {
    let zero: ContractAddress = Zero::zero();
    let addr = ADDR_1();
    let addresses: Array<ContractAddress> = array![zero, zero, addr];
    assert!(has_non_zero_address(@addresses), "Last non-zero should return true");
}

#[test]
fn test_has_non_zero_address_middle_non_zero() {
    let zero: ContractAddress = Zero::zero();
    let addr = ADDR_1();
    let addresses: Array<ContractAddress> = array![zero, addr, zero];
    assert!(has_non_zero_address(@addresses), "Middle non-zero should return true");
}

#[test]
fn test_has_non_zero_address_all_non_zero() {
    let addr1 = ADDR_1();
    let addr2 = ADDR_2();
    let addr3 = ADDR_3();
    let addresses: Array<ContractAddress> = array![addr1, addr2, addr3];
    assert!(has_non_zero_address(@addresses), "All non-zero should return true");
}

#[test]
fn test_has_non_zero_address_single_zero() {
    let zero: ContractAddress = Zero::zero();
    let addresses: Array<ContractAddress> = array![zero];
    assert!(!has_non_zero_address(@addresses), "Single zero should return false");
}

#[test]
fn test_has_non_zero_address_single_non_zero() {
    let addr = ADDR_1();
    let addresses: Array<ContractAddress> = array![addr];
    assert!(has_non_zero_address(@addresses), "Single non-zero should return true");
}

// =============================================================================
// FUZZ TESTS
// =============================================================================

#[test]
#[fuzzer]
fn test_address_to_option_fuzz(addr_felt: felt252) {
    let addr: ContractAddress = match addr_felt.try_into() {
        Option::Some(a) => a,
        Option::None => Zero::zero(),
    };
    let result = address_to_option(addr);

    if is_zero_address(addr) {
        assert!(result.is_none(), "Zero address should return None");
    } else {
        assert!(result.is_some(), "Non-zero address should return Some");
        assert!(result.unwrap() == addr, "Should return same address");
    }
}

#[test]
#[fuzzer]
fn test_is_zero_inverse_property(addr_felt: felt252) {
    let addr: ContractAddress = match addr_felt.try_into() {
        Option::Some(a) => a,
        Option::None => Zero::zero(),
    };
    assert!(
        is_non_zero_address(addr) == !is_zero_address(addr),
        "is_non_zero should be inverse of is_zero",
    );
}

#[test]
#[fuzzer]
fn test_addresses_equal_symmetric_fuzz(a_felt: felt252, b_felt: felt252) {
    let a: ContractAddress = match a_felt.try_into() {
        Option::Some(addr) => addr,
        Option::None => Zero::zero(),
    };
    let b: ContractAddress = match b_felt.try_into() {
        Option::Some(addr) => addr,
        Option::None => Zero::zero(),
    };
    assert!(addresses_equal(a, b) == addresses_equal(b, a), "addresses_equal should be symmetric");
}

#[test]
#[fuzzer]
fn test_unwrap_or_address_consistency_fuzz(addr_felt: felt252, default_felt: felt252) {
    let addr: ContractAddress = match addr_felt.try_into() {
        Option::Some(a) => a,
        Option::None => Zero::zero(),
    };
    let default: ContractAddress = match default_felt.try_into() {
        Option::Some(a) => a,
        Option::None => Zero::zero(),
    };

    let some_result = unwrap_or_address(Option::Some(addr), default);
    assert!(some_result == addr, "Some should return the wrapped value");

    let none_result = unwrap_or_address(Option::None, default);
    assert!(none_result == default, "None should return default");
}
