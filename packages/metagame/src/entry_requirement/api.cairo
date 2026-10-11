// SPDX-License-Identifier: BUSL-1.1
//! Storage-independent entry-requirement views and validated configuration writes.
use core::num::traits::Zero;
use game_components_interfaces::entry_requirement::{
    EntryRequirement, EntryRequirementType, IEntryRequirement, QualificationEntries,
    QualificationProof,
};
use metagame_extensions_interfaces::entry_requirement_extension::IENTRY_REQUIREMENT_EXTENSION_ID;
use openzeppelin_interfaces::erc721::IERC721_ID;
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
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
            // Preserve the standard component setter's validation and revert messages.
            match req.entry_requirement_type {
                EntryRequirementType::token(token) => {
                    let display_address: felt252 = token.into();
                    assert!(
                        ISRC5Dispatcher { contract_address: token }.supports_interface(IERC721_ID),
                        "EntryRequirement: Token {} does not support IERC721",
                        display_address,
                    );
                },
                EntryRequirementType::extension(config) => {
                    assert!(
                        !config.address.is_zero(),
                        "EntryRequirement: Extension address cannot be zero",
                    );
                    let display_address: felt252 = config.address.into();
                    assert!(
                        ISRC5Dispatcher { contract_address: config.address }
                            .supports_interface(IENTRY_REQUIREMENT_EXTENSION_ID),
                        "EntryRequirement: Extension {} does not support IEntryRequirementExtension",
                        display_address,
                    );
                },
            };
        }
        EntryRequirementStoreTrait::set_entry_requirement(ref self, context_id, requirement);
    }
}
