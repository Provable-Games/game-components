// SPDX-License-Identifier: BUSL-1.1
//! Storage-independent entry-requirement views and validated configuration writes.
use game_components_interfaces::entry_requirement::{
    EntryRequirement, IEntryRequirement, QualificationEntries, QualificationProof,
};
use crate::entry_requirement::entry_requirement_store::{
    EntryRequirementStoreImpl, EntryRequirementStoreTrait,
};
use crate::entry_requirement::store::Store;

#[starknet::embeddable]
pub impl EntryRequirementImpl<
    TContractState, +Store<TContractState>, +Drop<TContractState>,
> of IEntryRequirement<TContractState> {
    fn get_entry_requirement(self: @TContractState, context_id: u64) -> Option<EntryRequirement> {
        EntryRequirementStoreTrait::get_entry_requirement(self, context_id)
    }
    fn get_qualification_entries(
        self: @TContractState, context_id: u64, proof: QualificationProof,
    ) -> QualificationEntries {
        EntryRequirementStoreTrait::get_qualification_entries(self, context_id, proof)
    }
}

#[generate_trait]
pub impl EntryRequirementInternalImpl<T, +Store<T>, +Drop<T>> of EntryRequirementInternalTrait<T> {
    /// Validate SRC5 support before persisting configuration. Internal only;
    /// access control and extension add_config remain the host's responsibility.
    fn set_entry_requirement(ref self: T, context_id: u64, requirement: Option<EntryRequirement>) {
        if let Option::Some(req) = requirement {
            EntryRequirementStoreTrait::assert_valid_entry_requirement(@self, req);
        }
        EntryRequirementStoreTrait::set_entry_requirement(ref self, context_id, requirement);
    }
}
