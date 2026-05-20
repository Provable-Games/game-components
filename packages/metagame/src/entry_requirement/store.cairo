// SPDX-License-Identifier: BUSL-1.1

use starknet::ContractAddress;
use crate::entry_requirement::structs::EntryRequirementMeta;

/// Generic store trait for entry requirement operations
pub trait Store<T> {
    fn get_meta(self: @T, context_id: u64) -> EntryRequirementMeta;
    fn set_meta(ref self: T, context_id: u64, meta: EntryRequirementMeta);
    fn get_token(self: @T, context_id: u64) -> ContractAddress;
    fn set_token(ref self: T, context_id: u64, token: ContractAddress);
    fn get_extension_address(self: @T, context_id: u64) -> ContractAddress;
    fn set_extension_address(ref self: T, context_id: u64, address: ContractAddress);
    fn get_qualification_entries(self: @T, context_id: u64, hash: felt252) -> u32;
    fn set_qualification_entries(ref self: T, context_id: u64, hash: felt252, count: u32);
}
