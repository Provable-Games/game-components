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
    /// Validate a qualification proof.
    ///
    /// `claimed_qualifier`:
    /// - `None` — behaviour is gate-dependent:
    ///     * Token gate: returns `IERC721.owner_of(token_id)` (the resolved
    ///       qualifier is the NFT owner, *not* the caller).
    ///     * Extension gate: `get_caller_address()` is treated as the qualifier
    ///       (legacy behaviour for extensions).
    /// - `Some(addr)` — the caller is claiming `addr` qualified. The protocol must
    ///   verify this independently:
    ///     * Token gate: asserts `IERC721.owner_of(token_id) == addr`.
    ///     * Extension: `addr` is passed to the extension as `player_address`; the
    ///       extension is responsible for verifying the delegation (e.g. signature,
    ///       merkle proof) inside `valid_entry`. A zero `addr` is rejected at the
    ///       framework boundary. Extensions that don't verify the claimed qualifier
    ///       MUST NOT be used in flows that pass `Some(_)` — anyone could otherwise
    ///       mint as anyone.
    ///
    /// Returns the resolved qualifier address.
    fn validate_qualification(
        self: @T,
        context_id: u64,
        entry_requirement: EntryRequirement,
        qualifier: QualificationProof,
        claimed_qualifier: Option<ContractAddress>,
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
        let entry_requirement_type = if meta.req_type == entry_requirement::REQ_TYPE_TOKEN {
            let token = self.get_token(context_id);
            EntryRequirementType::token(token)
        } else if meta.req_type == entry_requirement::REQ_TYPE_EXTENSION {
            // Config is not persisted — the extension contract is the
            // source of truth. Hosts that need to surface the original
            // config should source it from their own event stream
            // (e.g. the `TournamentCreated`-style event that carries
            // the full `EntryRequirement` payload supplied at creation).
            let address = self.get_extension_address(context_id);
            EntryRequirementType::extension(ExtensionConfig { address, config: array![].span() })
        } else {
            return Option::None;
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
                        // Address-only persistence — see get_entry_requirement.
                        self.set_extension_address(context_id, config.address);
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
        claimed_qualifier: Option<ContractAddress>,
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
                let owner = erc721_dispatcher.owner_of(qualification.token_id);
                // If the caller claims a delegated qualifier, the on-chain owner must match.
                // This protects against forged claims for NFT-gated requirements.
                if let Option::Some(claimed) = claimed_qualifier {
                    assert!(
                        owner == claimed,
                        "EntryRequirement: claimed qualifier does not own the gating NFT",
                    );
                }
                owner
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
                // Default: caller is qualifier (legacy). Delegated flow: caller claims
                // `claimed_qualifier`; the extension is responsible for verifying that
                // claim from `qualification` (e.g. signature recovery, merkle proof).
                //
                // A zero claimed qualifier is rejected at the framework boundary so
                // extensions never have to defend against `player_address == 0` (some
                // implementations would silently accept it and key state against the
                // zero address). `get_caller_address()` is non-zero by construction.
                let qualifier_address = match claimed_qualifier {
                    Option::Some(addr) => {
                        assert!(
                            !addr.is_zero(), "EntryRequirement: claimed qualifier cannot be zero",
                        );
                        addr
                    },
                    Option::None => get_caller_address(),
                };
                let context_owner = get_contract_address();
                let display_extension_address: felt252 = extension_config.address.into();
                assert!(
                    extension_dispatcher
                        .valid_entry(context_owner, context_id, qualifier_address, qualification),
                    "EntryRequirement: Invalid entry according to extension {}",
                    display_extension_address,
                );
                qualifier_address
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
