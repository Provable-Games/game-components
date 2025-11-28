// Pure Cairo library for address utilities
// Contains common address manipulation and validation functions

use starknet::ContractAddress;
use core::num::traits::Zero;

/// Converts a contract address to an Option, returning None for zero address
///
/// # Arguments
/// * `address` - The contract address to convert
///
/// # Returns
/// * `Option<ContractAddress>` - Some(address) if non-zero, None if zero
#[inline(always)]
pub fn address_to_option(address: ContractAddress) -> Option<ContractAddress> {
    if is_zero_address(address) {
        Option::None
    } else {
        Option::Some(address)
    }
}

/// Checks if an address is the zero address
///
/// # Arguments
/// * `address` - The contract address to check
///
/// # Returns
/// * `bool` - True if zero address, false otherwise
#[inline(always)]
pub fn is_zero_address(address: ContractAddress) -> bool {
    address.is_zero()
}

/// Checks if an address is non-zero
///
/// # Arguments
/// * `address` - The contract address to check
///
/// # Returns
/// * `bool` - True if non-zero address, false otherwise
#[inline(always)]
pub fn is_non_zero_address(address: ContractAddress) -> bool {
    !address.is_zero()
}

/// Asserts that an address is not zero, panicking with a message if it is
///
/// # Arguments
/// * `address` - The contract address to check
/// * `error_message` - The error message to use if assertion fails
///
/// # Panics
/// * Panics with the provided message if address is zero
#[inline(always)]
pub fn assert_not_zero_address(address: ContractAddress, error_message: felt252) {
    assert(is_non_zero_address(address), error_message);
}

/// Returns the address from an Option or a default value
///
/// # Arguments
/// * `option_address` - The optional address
/// * `default` - The default address to return if None
///
/// # Returns
/// * `ContractAddress` - The address from the option or the default
#[inline(always)]
pub fn unwrap_or_address(
    option_address: Option<ContractAddress>, default: ContractAddress,
) -> ContractAddress {
    match option_address {
        Option::Some(address) => address,
        Option::None => default,
    }
}

/// Returns the address from an Option or zero address
///
/// # Arguments
/// * `option_address` - The optional address
///
/// # Returns
/// * `ContractAddress` - The address from the option or zero
#[inline(always)]
pub fn unwrap_or_zero(option_address: Option<ContractAddress>) -> ContractAddress {
    option_address.unwrap_or(Zero::zero())
}

/// Checks if two addresses are equal
///
/// # Arguments
/// * `address1` - First address
/// * `address2` - Second address
///
/// # Returns
/// * `bool` - True if addresses are equal, false otherwise
#[inline(always)]
pub fn addresses_equal(address1: ContractAddress, address2: ContractAddress) -> bool {
    address1 == address2
}

/// Validates that at least one address in an array is non-zero
///
/// # Arguments
/// * `addresses` - Array of addresses to check
///
/// # Returns
/// * `bool` - True if at least one address is non-zero, false otherwise
#[inline(always)]
pub fn has_non_zero_address(addresses: @Array<ContractAddress>) -> bool {
    let mut i: u32 = 0;
    let mut has_non_zero = false;

    while i < addresses.len() {
        if is_non_zero_address(*addresses.at(i)) {
            has_non_zero = true;
            break;
        }
        i += 1;
    };

    has_non_zero
}
