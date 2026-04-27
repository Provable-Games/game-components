// SPDX-License-Identifier: BUSL-1.1

use core::num::traits::Zero;
use metagame_extensions_interfaces::entry_requirement_extension::{
    IENTRY_REQUIREMENT_EXTENSION_ID, IEntryRequirementExtensionDispatcher,
    IEntryRequirementExtensionDispatcherTrait,
};
use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait, IERC721_ID};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::{ContractAddress, get_caller_address, get_contract_address};
use crate::entry_requirement::entry_requirement::entry_requirement;
use crate::entry_requirement::store::Store;
use crate::entry_requirement::structs::{
    EntryRequirement, EntryRequirementMeta, EntryRequirementType, ExtensionConfig,
    QualificationEntries, QualificationProof,
};

/// Store bridge: composes Store<T> reads with pure lib and cross-contract calls
pub trait EntryRequirementStoreTrait<T> {
    /// Get entry requirement for a context
    fn get_entry_requirement(self: @T, context_id: u64) -> Option<EntryRequirement>;
    /// Set entry requirement for a context (no SRC5 validation - component layer handles that)
    fn set_entry_requirement(
        ref self: T, context_id: u64, entry_requirement: Option<EntryRequirement>,
    );
    /// Get qualification entries
    fn get_qualification_entries(
        self: @T, context_id: u64, proof: QualificationProof,
    ) -> QualificationEntries;
    /// Set qualification entries
    fn set_qualification_entries(ref self: T, entries: @QualificationEntries);
    /// Validate a qualification proof
    fn validate_qualification(
        self: @T,
        context_id: u64,
        entry_requirement: EntryRequirement,
        qualifier: QualificationProof,
    ) -> ContractAddress;
    /// Validate entry requirement configuration
    fn assert_valid_entry_requirement(self: @T, entry_requirement: EntryRequirement);
    /// Update qualification entries after entry
    fn update_qualification_entries(
        ref self: T,
        context_id: u64,
        qualifier: QualificationProof,
        entry_requirement: EntryRequirement,
    );
}

pub impl EntryRequirementStoreImpl<T, +Store<T>, +Drop<T>> of EntryRequirementStoreTrait<T> {
    fn get_entry_requirement(self: @T, context_id: u64) -> Option<EntryRequirement> {
        let meta = self.get_meta(context_id);
        if meta.req_type == entry_requirement::REQ_TYPE_NONE {
            return Option::None;
        }
        let entry_requirement_type = match meta.req_type {
            0 => {
                let token = self.get_token(context_id);
                EntryRequirementType::token(token)
            },
            1 => {
                let address = self.get_extension_address(context_id);
                let config = self.get_extension_config(context_id);
                EntryRequirementType::extension(ExtensionConfig { address, config })
            },
            _ => { return Option::None; },
        };
        Option::Some(EntryRequirement { entry_limit: meta.entry_limit, entry_requirement_type })
    }

    fn set_entry_requirement(
        ref self: T, context_id: u64, entry_requirement: Option<EntryRequirement>,
    ) {
        match entry_requirement {
            Option::Some(req) => {
                let (req_type, entry_limit) = match req.entry_requirement_type {
                    EntryRequirementType::token(token) => {
                        self.set_token(context_id, token);
                        (entry_requirement::REQ_TYPE_TOKEN, req.entry_limit)
                    },
                    EntryRequirementType::extension(config) => {
                        self.set_extension_address(context_id, config.address);
                        self.set_extension_config(context_id, config.config);
                        (entry_requirement::REQ_TYPE_EXTENSION, req.entry_limit)
                    },
                };
                let meta = EntryRequirementMeta { entry_limit, req_type };
                self.set_meta(context_id, meta);
            },
            Option::None => {
                let meta = EntryRequirementMeta {
                    entry_limit: 0, req_type: entry_requirement::REQ_TYPE_NONE,
                };
                self.set_meta(context_id, meta);
            },
        }
    }

    fn get_qualification_entries(
        self: @T, context_id: u64, proof: QualificationProof,
    ) -> QualificationEntries {
        let qualification_hash = entry_requirement::hash_qualification_proof(proof);
        let entry_count = Store::get_qualification_entries(self, context_id, qualification_hash);
        QualificationEntries { context_id, qualification_proof: proof, entry_count }
    }

    fn set_qualification_entries(ref self: T, entries: @QualificationEntries) {
        let qualification_hash = entry_requirement::hash_qualification_proof(
            *entries.qualification_proof,
        );
        Store::set_qualification_entries(
            ref self, *entries.context_id, qualification_hash, *entries.entry_count,
        );
    }

    // Cross-contract calls: validation dispatchers
    fn validate_qualification(
        self: @T,
        context_id: u64,
        entry_requirement: EntryRequirement,
        qualifier: QualificationProof,
    ) -> ContractAddress {
        match entry_requirement.entry_requirement_type {
            EntryRequirementType::token(token_address) => {
                let qualification = match qualifier {
                    QualificationProof::NFT(qual) => qual,
                    _ => panic!(
                        "EntryRequirement: Provided qualification proof is not of type 'NFT'",
                    ),
                };
                let erc721_dispatcher = IERC721Dispatcher { contract_address: token_address };
                erc721_dispatcher.owner_of(qualification.token_id)
            },
            EntryRequirementType::extension(extension_config) => {
                let qualification = match qualifier {
                    QualificationProof::Extension(qual) => qual,
                    _ => panic!(
                        "EntryRequirement: Provided qualification proof is not of type 'Extension'",
                    ),
                };
                let extension_dispatcher = IEntryRequirementExtensionDispatcher {
                    contract_address: extension_config.address,
                };
                let caller_address = get_caller_address();
                let context_owner = get_contract_address();
                let display_extension_address: felt252 = extension_config.address.into();
                assert!(
                    extension_dispatcher
                        .valid_entry(context_owner, context_id, caller_address, qualification),
                    "EntryRequirement: Invalid entry according to extension {}",
                    display_extension_address,
                );
                caller_address
            },
        }
    }

    fn assert_valid_entry_requirement(self: @T, entry_requirement: EntryRequirement) {
        match entry_requirement.entry_requirement_type {
            EntryRequirementType::token(token) => {
                let src5_dispatcher = ISRC5Dispatcher { contract_address: token };
                let display_address: felt252 = token.into();
                assert!(
                    src5_dispatcher.supports_interface(IERC721_ID),
                    "EntryRequirement: Token address {} does not support IERC721 interface",
                    display_address,
                );
            },
            EntryRequirementType::extension(extension_config) => {
                let extension_address = extension_config.address;
                assert!(
                    !extension_address.is_zero(),
                    "EntryRequirement: Extension address can't be zero",
                );
                let src5_dispatcher = ISRC5Dispatcher { contract_address: extension_address };
                let display_address: felt252 = extension_address.into();
                assert!(
                    src5_dispatcher.supports_interface(IENTRY_REQUIREMENT_EXTENSION_ID),
                    "EntryRequirement: Extension address {} does not support IEntryRequirementExtension interface",
                    display_address,
                );
            },
        }
    }

    /// Track a successful entry against the configured limit.
    ///
    /// For extension-typed requirements this is a no-op: extensions enforce both eligibility
    /// and remaining-entry quota inside their own `valid_entry` (already called by
    /// `validate_qualification`). The framework deliberately does NOT make a second
    /// `entries_left` cross-contract call here — it would walk the same on-chain state a
    /// second time. See `IEntryRequirementExtension` docs for the contract.
    fn update_qualification_entries(
        ref self: T,
        context_id: u64,
        qualifier: QualificationProof,
        entry_requirement: EntryRequirement,
    ) {
        match entry_requirement.entry_requirement_type {
            EntryRequirementType::extension(_) => {},
            _ => {
                let entry_limit = entry_requirement.entry_limit;
                if entry_limit != 0 {
                    let mut qualification_entries =
                        EntryRequirementStoreTrait::get_qualification_entries(
                        @self, context_id, qualifier,
                    );

                    assert!(
                        qualification_entries.entry_count.into() < entry_limit,
                        "EntryRequirement: Maximum qualified entries reached for context {}",
                        context_id,
                    );

                    qualification_entries.entry_count += 1;

                    EntryRequirementStoreTrait::set_qualification_entries(
                        ref self, @qualification_entries,
                    );
                }
            },
        }
    }
}
