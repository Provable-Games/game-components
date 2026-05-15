use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use crate::entry_requirement::structs::{
    EntryRequirement, EntryRequirementType, ExtensionConfig, NFTQualification, QualificationEntries,
    QualificationProof,
};

fn make_address(value: felt252) -> starknet::ContractAddress {
    value.try_into().unwrap()
}

#[starknet::interface]
trait IEntryRequirementMock<TContractState> {
    // From component (embed_v0)
    fn get_entry_requirement(self: @TContractState, context_id: u64) -> Option<EntryRequirement>;
    fn get_qualification_entries(
        self: @TContractState, context_id: u64, proof: QualificationProof,
    ) -> QualificationEntries;
    // From mock external functions
    fn set_entry_requirement(
        ref self: TContractState, context_id: u64, entry_requirement: Option<EntryRequirement>,
    );
    fn set_qualification_entries(ref self: TContractState, entries: QualificationEntries);
    fn update_qualification_entries(
        ref self: TContractState,
        context_id: u64,
        qualifier: QualificationProof,
        entry_requirement: EntryRequirement,
    );
    fn validate_qualification(
        self: @TContractState,
        context_id: u64,
        entry_requirement: EntryRequirement,
        qualifier: QualificationProof,
        claimed_qualifier: Option<ContractAddress>,
    ) -> ContractAddress;
    fn assert_valid_entry_requirement(self: @TContractState, entry_requirement: EntryRequirement);
    fn hash_qualification_proof(self: @TContractState, proof: QualificationProof) -> felt252;
}

#[starknet::interface]
trait IERC721MockSetup<TContractState> {
    fn set_owner(ref self: TContractState, token_id: u256, owner: ContractAddress);
}

fn deploy_entry_requirement_mock() -> IEntryRequirementMockDispatcher {
    let contract_class = declare("EntryRequirementMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).expect('deploy failed');
    IEntryRequirementMockDispatcher { contract_address }
}

// ============================================================================
// get_entry_requirement tests
// ============================================================================

#[test]
fn test_get_entry_requirement_default_is_token_with_zero_address() {
    let mock = deploy_entry_requirement_mock();
    // Uninitialized storage has req_type=0 (TOKEN) with entry_limit=0 and zero address.
    // The component only returns None when req_type == 255 (REQ_TYPE_NONE).
    let result = mock.get_entry_requirement(1);
    assert!(result.is_some(), "default should be Some (req_type defaults to 0=TOKEN)");
    let req = result.unwrap();
    assert!(req.entry_limit == 0, "default entry_limit should be 0");
    match req.entry_requirement_type {
        EntryRequirementType::token(addr) => {
            let zero_addr: starknet::ContractAddress = 0.try_into().unwrap();
            assert!(addr == zero_addr, "default token address should be zero");
        },
        _ => { panic!("default should be token type"); },
    }
}

#[test]
fn test_get_entry_requirement_returns_none_after_explicit_set() {
    let mock = deploy_entry_requirement_mock();
    // Explicitly setting to None writes req_type=255
    mock.set_entry_requirement(1, Option::None);
    let result = mock.get_entry_requirement(1);
    assert!(result.is_none(), "should be None after explicit set");
}

#[test]
fn test_set_and_get_token_requirement() {
    let mock = deploy_entry_requirement_mock();
    let token_addr = deploy_erc721_mock();
    let context_id: u64 = 42;

    let req = EntryRequirement {
        entry_limit: 10, entry_requirement_type: EntryRequirementType::token(token_addr),
    };
    mock.set_entry_requirement(context_id, Option::Some(req));

    let result = mock.get_entry_requirement(context_id);
    assert!(result.is_some(), "should return Some");

    let retrieved = result.unwrap();
    assert!(retrieved.entry_limit == 10, "entry_limit mismatch");

    match retrieved.entry_requirement_type {
        EntryRequirementType::token(addr) => {
            assert!(addr == token_addr, "token address mismatch");
        },
        EntryRequirementType::extension(_) => { panic!("expected token type"); },
    }
}

#[test]
fn test_set_and_get_extension_requirement() {
    let mock = deploy_entry_requirement_mock();
    let owner = make_address(0x1);
    let ext_addr = deploy_entry_validator_mock(owner);
    let config_data: Array<felt252> = array![1, 2, 3];
    let context_id: u64 = 77;

    let req = EntryRequirement {
        entry_limit: 20,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: ext_addr, config: config_data.span() },
        ),
    };
    mock.set_entry_requirement(context_id, Option::Some(req));

    let result = mock.get_entry_requirement(context_id);
    assert!(result.is_some(), "should return Some");

    let retrieved = result.unwrap();
    assert!(retrieved.entry_limit == 20, "entry_limit mismatch");

    match retrieved.entry_requirement_type {
        EntryRequirementType::token(_) => { panic!("expected extension type"); },
        EntryRequirementType::extension(ext_config) => {
            assert!(ext_config.address == ext_addr, "extension address mismatch");
            assert!(ext_config.config.len() == 3, "config length mismatch");
            assert!(*ext_config.config.at(0) == 1, "config[0] mismatch");
            assert!(*ext_config.config.at(1) == 2, "config[1] mismatch");
            assert!(*ext_config.config.at(2) == 3, "config[2] mismatch");
        },
    }
}

#[test]
fn test_set_entry_requirement_to_none() {
    let mock = deploy_entry_requirement_mock();
    let token_addr = deploy_erc721_mock();
    let context_id: u64 = 42;

    // First set a requirement
    let req = EntryRequirement {
        entry_limit: 10, entry_requirement_type: EntryRequirementType::token(token_addr),
    };
    mock.set_entry_requirement(context_id, Option::Some(req));
    assert!(mock.get_entry_requirement(context_id).is_some(), "should be set");

    // Now clear it
    mock.set_entry_requirement(context_id, Option::None);
    let result = mock.get_entry_requirement(context_id);
    assert!(result.is_none(), "should be None after clearing");
}

#[test]
fn test_set_requirement_overwrites_previous() {
    let mock = deploy_entry_requirement_mock();
    let context_id: u64 = 10;

    // Set token requirement
    let token_addr = deploy_erc721_mock();
    let req1 = EntryRequirement {
        entry_limit: 10, entry_requirement_type: EntryRequirementType::token(token_addr),
    };
    mock.set_entry_requirement(context_id, Option::Some(req1));

    // Overwrite with different token requirement
    let token_addr2 = deploy_erc721_mock();
    let req2 = EntryRequirement {
        entry_limit: 20, entry_requirement_type: EntryRequirementType::token(token_addr2),
    };
    mock.set_entry_requirement(context_id, Option::Some(req2));

    let result = mock.get_entry_requirement(context_id).unwrap();
    assert!(result.entry_limit == 20, "entry_limit should be updated");

    match result.entry_requirement_type {
        EntryRequirementType::token(addr) => {
            assert!(addr == token_addr2, "token address should be updated");
        },
        _ => { panic!("expected token type"); },
    }
}

#[test]
fn test_different_context_ids_are_independent() {
    let mock = deploy_entry_requirement_mock();

    let token_addr = deploy_erc721_mock();
    let req = EntryRequirement {
        entry_limit: 5, entry_requirement_type: EntryRequirementType::token(token_addr),
    };
    mock.set_entry_requirement(1, Option::Some(req));

    // Context 1 should have the token we set
    let result1 = mock.get_entry_requirement(1).unwrap();
    assert!(result1.entry_limit == 5, "context 1 entry_limit should be 5");
    match result1.entry_requirement_type {
        EntryRequirementType::token(addr) => {
            assert!(addr == token_addr, "context 1 token address mismatch");
        },
        _ => { panic!("context 1 should be token type"); },
    }

    // Context 2 was not explicitly set; its default token address should be zero
    let result2 = mock.get_entry_requirement(2).unwrap();
    assert!(result2.entry_limit == 0, "context 2 default entry_limit should be 0");
    match result2.entry_requirement_type {
        EntryRequirementType::token(addr) => {
            let zero_addr: starknet::ContractAddress = 0.try_into().unwrap();
            assert!(addr == zero_addr, "context 2 default token address should be zero");
        },
        _ => { panic!("context 2 default should be token type"); },
    }
}

#[test]
fn test_explicitly_cleared_context_is_none() {
    let mock = deploy_entry_requirement_mock();

    // Set then clear context 1
    let token_addr = deploy_erc721_mock();
    let req = EntryRequirement {
        entry_limit: 5, entry_requirement_type: EntryRequirementType::token(token_addr),
    };
    mock.set_entry_requirement(1, Option::Some(req));
    mock.set_entry_requirement(1, Option::None);

    // Set context 2
    mock.set_entry_requirement(2, Option::Some(req));

    assert!(mock.get_entry_requirement(1).is_none(), "context 1 should be None after clear");
    assert!(mock.get_entry_requirement(2).is_some(), "context 2 should still be Some");
}

// ============================================================================
// Qualification entries tests
// ============================================================================

#[test]
fn test_qualification_entries_default_zero() {
    let mock = deploy_entry_requirement_mock();
    let proof = QualificationProof::Extension(array![0x123].span());
    let entries = mock.get_qualification_entries(1, proof);
    assert!(entries.context_id == 1, "context_id mismatch");
    assert!(entries.entry_count == 0, "default entry_count should be 0");
}

#[test]
fn test_set_qualification_entries() {
    let mock = deploy_entry_requirement_mock();
    let proof = QualificationProof::Extension(array![0x123].span());

    let entries = QualificationEntries {
        context_id: 42, qualification_proof: proof, entry_count: 7,
    };
    mock.set_qualification_entries(entries);

    let result = mock.get_qualification_entries(42, proof);
    assert!(result.context_id == 42, "context_id mismatch");
    assert!(result.entry_count == 7, "entry_count mismatch");
}

#[test]
fn test_set_qualification_entries_nft_proof() {
    let mock = deploy_entry_requirement_mock();
    let proof = QualificationProof::NFT(NFTQualification { token_id: 999 });

    let entries = QualificationEntries {
        context_id: 10, qualification_proof: proof, entry_count: 3,
    };
    mock.set_qualification_entries(entries);

    let result = mock.get_qualification_entries(10, proof);
    assert!(result.entry_count == 3, "entry_count mismatch");
}

// ============================================================================
// update_qualification_entries tests (non-Extension paths)
// ============================================================================

#[test]
fn test_update_qualification_entries_increments() {
    let mock = deploy_entry_requirement_mock();
    let context_id: u64 = 50;
    let token_addr = make_address(0xABC);
    let proof = QualificationProof::Extension(array![0x123].span());

    let req = EntryRequirement {
        entry_limit: 3, entry_requirement_type: EntryRequirementType::token(token_addr),
    };

    // First update: 0 -> 1
    mock.update_qualification_entries(context_id, proof, req);
    let result = mock.get_qualification_entries(context_id, proof);
    assert!(result.entry_count == 1, "entry_count should be 1 after first update");

    // Second update: 1 -> 2
    mock.update_qualification_entries(context_id, proof, req);
    let result = mock.get_qualification_entries(context_id, proof);
    assert!(result.entry_count == 2, "entry_count should be 2 after second update");
}

#[test]
#[should_panic(expected: "EntryRequirement: Maximum qualified entries reached")]
fn test_update_qualification_entries_panics_at_limit() {
    let mock = deploy_entry_requirement_mock();
    let context_id: u64 = 50;
    let token_addr = make_address(0xABC);
    let proof = QualificationProof::Extension(array![0x123].span());

    let req = EntryRequirement {
        entry_limit: 1, entry_requirement_type: EntryRequirementType::token(token_addr),
    };

    // First update succeeds (0 < 1)
    mock.update_qualification_entries(context_id, proof, req);

    // Second update should panic (1 is not < 1)
    mock.update_qualification_entries(context_id, proof, req);
}

#[test]
fn test_update_qualification_entries_no_limit() {
    let mock = deploy_entry_requirement_mock();
    let context_id: u64 = 50;
    let token_addr = make_address(0xABC);
    let proof = QualificationProof::Extension(array![0x123].span());

    // entry_limit = 0 means unlimited
    let req = EntryRequirement {
        entry_limit: 0, entry_requirement_type: EntryRequirementType::token(token_addr),
    };

    // Should be able to update many times without panic
    let mut i: u32 = 0;
    loop {
        if i >= 10 {
            break;
        }
        mock.update_qualification_entries(context_id, proof, req);
        i += 1;
    }

    // With entry_limit=0, no entries are tracked (no-op)
    let result = mock.get_qualification_entries(context_id, proof);
    assert!(result.entry_count == 0, "entry_count should remain 0 when no limit");
}

#[test]
fn test_update_qualification_entries_different_proofs_independent() {
    let mock = deploy_entry_requirement_mock();
    let context_id: u64 = 50;
    let token_addr = make_address(0xABC);
    let proof1 = QualificationProof::Extension(array![0x111].span());
    let proof2 = QualificationProof::Extension(array![0x222].span());

    let req = EntryRequirement {
        entry_limit: 5, entry_requirement_type: EntryRequirementType::token(token_addr),
    };

    // Update with proof1 twice
    mock.update_qualification_entries(context_id, proof1, req);
    mock.update_qualification_entries(context_id, proof1, req);

    // Update with proof2 once
    mock.update_qualification_entries(context_id, proof2, req);

    let result1 = mock.get_qualification_entries(context_id, proof1);
    let result2 = mock.get_qualification_entries(context_id, proof2);
    assert!(result1.entry_count == 2, "proof1 entry_count should be 2");
    assert!(result2.entry_count == 1, "proof2 entry_count should be 1");
}

#[test]
fn test_update_qualification_entries_nft_proof() {
    let mock = deploy_entry_requirement_mock();
    let context_id: u64 = 70;
    let token_addr = make_address(0xABC);
    let proof = QualificationProof::NFT(NFTQualification { token_id: 42 });

    let req = EntryRequirement {
        entry_limit: 3, entry_requirement_type: EntryRequirementType::token(token_addr),
    };

    mock.update_qualification_entries(context_id, proof, req);
    let result = mock.get_qualification_entries(context_id, proof);
    assert!(result.entry_count == 1, "entry_count should be 1");
}

// ============================================================================
// Helper deploy functions for validation tests
// ============================================================================

fn deploy_erc721_mock() -> ContractAddress {
    let contract_class = declare("ERC721Mock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).expect('deploy failed');
    contract_address
}

fn deploy_entry_validator_mock(owner: ContractAddress) -> ContractAddress {
    let contract_class = declare("EntryValidatorMock").expect('declare failed').contract_class();
    let mut calldata = array![];
    owner.serialize(ref calldata);
    let (contract_address, _) = contract_class.deploy(@calldata).expect('deploy failed');
    contract_address
}

fn deploy_rejecting_entry_validator_mock(owner: ContractAddress) -> ContractAddress {
    let contract_class = declare("RejectingEntryValidatorMock")
        .expect('declare failed')
        .contract_class();
    let mut calldata = array![];
    owner.serialize(ref calldata);
    let (contract_address, _) = contract_class.deploy(@calldata).expect('deploy failed');
    contract_address
}

// ============================================================================
// validate_qualification tests
// ============================================================================

#[test]
fn test_validate_qualification_token_returns_owner() {
    let mock = deploy_entry_requirement_mock();
    let erc721_addr = deploy_erc721_mock();
    let owner = make_address(0x999);
    let token_id: u256 = 42;

    // Set the NFT owner
    IERC721MockSetupDispatcher { contract_address: erc721_addr }.set_owner(token_id, owner);

    let req = EntryRequirement {
        entry_limit: 1, entry_requirement_type: EntryRequirementType::token(erc721_addr),
    };

    let result = mock
        .validate_qualification(
            1, req, QualificationProof::NFT(NFTQualification { token_id }), Option::None,
        );
    assert!(result == owner, "should return the NFT owner");
}

#[test]
#[should_panic(expected: "EntryRequirement: Provided qualification proof is not of type 'NFT'")]
fn test_validate_qualification_token_wrong_proof_type() {
    let mock = deploy_entry_requirement_mock();
    let erc721_addr = deploy_erc721_mock();

    let req = EntryRequirement {
        entry_limit: 1, entry_requirement_type: EntryRequirementType::token(erc721_addr),
    };

    // Pass Extension proof for a token requirement — should panic
    mock
        .validate_qualification(
            1, req, QualificationProof::Extension(array![0x123].span()), Option::None,
        );
}

#[test]
#[should_panic(expected: "ERC721Mock: nonexistent token")]
fn test_validate_qualification_token_nonexistent_nft() {
    let mock = deploy_entry_requirement_mock();
    let erc721_addr = deploy_erc721_mock();

    let req = EntryRequirement {
        entry_limit: 1, entry_requirement_type: EntryRequirementType::token(erc721_addr),
    };

    // Token 999 was never minted
    mock
        .validate_qualification(
            1, req, QualificationProof::NFT(NFTQualification { token_id: 999 }), Option::None,
        );
}

#[test]
fn test_validate_qualification_extension_returns_caller() {
    let mock = deploy_entry_requirement_mock();
    let caller = make_address(0x555);
    let validator_addr = deploy_entry_validator_mock(caller);

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    // Set caller address for the test
    snforge_std::cheat_caller_address(
        mock.contract_address, caller, snforge_std::CheatSpan::TargetCalls(1),
    );
    let result = mock
        .validate_qualification(
            1, req, QualificationProof::Extension(array![].span()), Option::None,
        );
    assert!(result == caller, "should return the caller address");
}

#[test]
#[should_panic(expected: "EntryRequirement: Invalid entry according to extension")]
fn test_validate_qualification_extension_rejects() {
    let mock = deploy_entry_requirement_mock();
    let caller = make_address(0x555);
    let validator_addr = deploy_rejecting_entry_validator_mock(caller);

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    snforge_std::cheat_caller_address(
        mock.contract_address, caller, snforge_std::CheatSpan::TargetCalls(1),
    );
    mock
        .validate_qualification(
            1, req, QualificationProof::Extension(array![].span()), Option::None,
        );
}

#[test]
#[should_panic(
    expected: "EntryRequirement: Provided qualification proof is not of type 'Extension'",
)]
fn test_validate_qualification_extension_wrong_proof_type() {
    let mock = deploy_entry_requirement_mock();
    let caller = make_address(0x555);
    let validator_addr = deploy_entry_validator_mock(caller);

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    // Pass NFT proof for extension requirement — should panic
    mock
        .validate_qualification(
            1, req, QualificationProof::NFT(NFTQualification { token_id: 0x123 }), Option::None,
        );
}

// ============================================================================
// validate_qualification with claimed_qualifier (delegated path)
// ============================================================================

#[test]
fn test_validate_qualification_token_with_claimed_owner_succeeds() {
    // Some(addr) where addr == owner_of(token_id) — protocol verifies via owner_of,
    // returns the owner. Caller can be any third party.
    let mock = deploy_entry_requirement_mock();
    let erc721_addr = deploy_erc721_mock();
    let token_id = 0x1234;
    let owner = make_address(0xABCDEF);

    IERC721MockSetupDispatcher { contract_address: erc721_addr }.set_owner(token_id, owner);

    let req = EntryRequirement {
        entry_limit: 1, entry_requirement_type: EntryRequirementType::token(erc721_addr),
    };

    let result = mock
        .validate_qualification(
            1, req, QualificationProof::NFT(NFTQualification { token_id }), Option::Some(owner),
        );
    assert!(result == owner, "should return the resolved owner");
}

#[test]
#[should_panic(expected: "EntryRequirement: claimed qualifier does not own the gating NFT")]
fn test_validate_qualification_token_with_wrong_claimed_panics() {
    // Some(addr) where addr != owner_of(token_id) — protocol panics. Protects
    // against forged claims for NFT-gated requirements.
    let mock = deploy_entry_requirement_mock();
    let erc721_addr = deploy_erc721_mock();
    let token_id = 0x1234;
    let owner = make_address(0xABCDEF);
    let wrong = make_address(0xDEADBEEF);

    IERC721MockSetupDispatcher { contract_address: erc721_addr }.set_owner(token_id, owner);

    let req = EntryRequirement {
        entry_limit: 1, entry_requirement_type: EntryRequirementType::token(erc721_addr),
    };

    mock
        .validate_qualification(
            1, req, QualificationProof::NFT(NFTQualification { token_id }), Option::Some(wrong),
        );
}

#[test]
#[should_panic(expected: "EntryRequirement: claimed qualifier does not own the gating NFT")]
fn test_validate_qualification_token_with_zero_claimed_panics() {
    // Claiming the zero address on a minted token cannot match owner_of — falls
    // out of the same assert as the wrong-owner case. (No separate "zero" path
    // exists for token gates: the protocol can rely on owner_of returning a real
    // address for minted tokens.)
    let mock = deploy_entry_requirement_mock();
    let erc721_addr = deploy_erc721_mock();
    let token_id = 0x1234;
    let owner = make_address(0xABCDEF);
    let zero: starknet::ContractAddress = 0.try_into().unwrap();

    IERC721MockSetupDispatcher { contract_address: erc721_addr }.set_owner(token_id, owner);

    let req = EntryRequirement {
        entry_limit: 1, entry_requirement_type: EntryRequirementType::token(erc721_addr),
    };

    mock
        .validate_qualification(
            1, req, QualificationProof::NFT(NFTQualification { token_id }), Option::Some(zero),
        );
}

#[test]
fn test_validate_qualification_extension_with_claimed_returns_claimed() {
    // Extension path: Some(addr) propagates `addr` to the extension as
    // `player_address` and (on success) returns it. Caller is unrelated to addr.
    let mock = deploy_entry_requirement_mock();
    let mock_caller = make_address(0xCAFE);
    let validator_addr = deploy_entry_validator_mock(mock_caller);
    let claimed = make_address(0x1234567);

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    snforge_std::cheat_caller_address(
        mock.contract_address, mock_caller, snforge_std::CheatSpan::TargetCalls(1),
    );
    let result = mock
        .validate_qualification(
            1, req, QualificationProof::Extension(array![].span()), Option::Some(claimed),
        );
    assert!(result == claimed, "extension path should return the claimed qualifier");
    assert!(result != mock_caller, "caller should not be the resolved qualifier when Some is set");
}

#[test]
#[should_panic(expected: "EntryRequirement: claimed qualifier cannot be zero")]
fn test_validate_qualification_extension_with_zero_claimed_panics() {
    // The framework rejects a zero claimed qualifier before calling the extension
    // so extensions never have to defend against `player_address == 0`.
    let mock = deploy_entry_requirement_mock();
    let mock_caller = make_address(0xCAFE);
    let validator_addr = deploy_entry_validator_mock(mock_caller);
    let zero: starknet::ContractAddress = 0.try_into().unwrap();

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    snforge_std::cheat_caller_address(
        mock.contract_address, mock_caller, snforge_std::CheatSpan::TargetCalls(1),
    );
    mock
        .validate_qualification(
            1, req, QualificationProof::Extension(array![].span()), Option::Some(zero),
        );
}

// ============================================================================
// assert_valid_entry_requirement tests
// ============================================================================

#[test]
fn test_assert_valid_entry_requirement_token_erc721() {
    let mock = deploy_entry_requirement_mock();
    let erc721_addr = deploy_erc721_mock();

    let req = EntryRequirement {
        entry_limit: 1, entry_requirement_type: EntryRequirementType::token(erc721_addr),
    };

    // Should not panic - ERC721Mock supports IERC721_ID
    mock.assert_valid_entry_requirement(req);
}

#[test]
#[should_panic(expected: "EntryRequirement: Token address")]
fn test_assert_valid_entry_requirement_token_not_erc721() {
    let mock = deploy_entry_requirement_mock();
    // Deploy an entry validator (which doesn't support IERC721)
    let non_erc721_addr = deploy_entry_validator_mock(make_address(0x1));

    let req = EntryRequirement {
        entry_limit: 1, entry_requirement_type: EntryRequirementType::token(non_erc721_addr),
    };

    mock.assert_valid_entry_requirement(req);
}

#[test]
fn test_assert_valid_entry_requirement_extension_valid() {
    let mock = deploy_entry_requirement_mock();
    let validator_addr = deploy_entry_validator_mock(make_address(0x1));

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    // Should not panic - EntryValidatorMock supports IEntryRequirementExtension
    mock.assert_valid_entry_requirement(req);
}

#[test]
#[should_panic(expected: "EntryRequirement: Extension address can't be zero")]
fn test_assert_valid_entry_requirement_extension_zero_address() {
    let mock = deploy_entry_requirement_mock();
    let zero: ContractAddress = 0.try_into().unwrap();

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: zero, config: array![].span() },
        ),
    };

    mock.assert_valid_entry_requirement(req);
}

#[test]
#[should_panic(expected: "EntryRequirement: Extension address")]
fn test_assert_valid_entry_requirement_extension_not_entry_validator() {
    let mock = deploy_entry_requirement_mock();
    // Deploy an ERC721 mock (doesn't support IEntryRequirementExtension)
    let erc721_addr = deploy_erc721_mock();

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: erc721_addr, config: array![].span() },
        ),
    };

    mock.assert_valid_entry_requirement(req);
}

// ============================================================================
// Helper deploy function for AcceptingLimitedEntryValidatorMock
// ============================================================================

fn deploy_accepting_limited_entry_validator_mock(owner: ContractAddress) -> ContractAddress {
    let contract_class = declare("AcceptingLimitedEntryValidatorMock")
        .expect('declare failed')
        .contract_class();
    let mut calldata = array![];
    owner.serialize(ref calldata);
    let (contract_address, _) = contract_class.deploy(@calldata).expect('deploy failed');
    contract_address
}

// ============================================================================
// update_qualification_entries - Extension path tests
// ============================================================================

#[test]
fn test_update_qualification_entries_extension_is_noop() {
    // The framework no longer cross-checks the extension's `entries_left` here — extensions
    // enforce both eligibility and remaining-entry quota inside their own `valid_entry`.
    // `update_qualification_entries` must therefore complete silently for any extension
    // requirement, regardless of what the extension would have reported.
    let mock = deploy_entry_requirement_mock();
    let caller = make_address(0x555);
    let validator_addr = deploy_entry_validator_mock(caller);
    let context_id: u64 = 80;

    let req = EntryRequirement {
        entry_limit: 10,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    snforge_std::cheat_caller_address(
        mock.contract_address, caller, snforge_std::CheatSpan::TargetCalls(1),
    );
    mock
        .update_qualification_entries(
            context_id, QualificationProof::Extension(array![].span()), req,
        );
}

#[test]
fn test_update_qualification_entries_extension_noop_even_when_extension_would_reject() {
    // Same as above with a rejecting/zero-entries-left mock. Pre-change this would have
    // panicked with "No entries left"; post-change the framework never asks the extension.
    let mock = deploy_entry_requirement_mock();
    let caller = make_address(0x555);
    let validator_addr = deploy_rejecting_entry_validator_mock(caller);
    let context_id: u64 = 82;

    let req = EntryRequirement {
        entry_limit: 10,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    snforge_std::cheat_caller_address(
        mock.contract_address, caller, snforge_std::CheatSpan::TargetCalls(1),
    );
    mock
        .update_qualification_entries(
            context_id, QualificationProof::Extension(array![].span()), req,
        );
}

#[test]
fn test_update_qualification_entries_extension_accepts_any_proof_type() {
    // Pre-change the framework destructured the qualifier inside the extension branch and
    // panicked on a non-Extension proof. Post-change the branch is a no-op, so any proof
    // shape is accepted (the qualifier is consumed by `validate_qualification`, which runs
    // earlier in `enter_tournament`).
    let mock = deploy_entry_requirement_mock();
    let caller = make_address(0x555);
    let validator_addr = deploy_entry_validator_mock(caller);
    let context_id: u64 = 83;

    let req = EntryRequirement {
        entry_limit: 10,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    snforge_std::cheat_caller_address(
        mock.contract_address, caller, snforge_std::CheatSpan::TargetCalls(1),
    );
    mock
        .update_qualification_entries(
            context_id, QualificationProof::NFT(NFTQualification { token_id: 0x123 }), req,
        );
}

// ============================================================================
// hash_qualification_proof tests
// ============================================================================

#[test]
fn test_hash_qualification_proof_deterministic() {
    let mock = deploy_entry_requirement_mock();
    let proof = QualificationProof::Extension(array![0x123].span());

    let hash1 = mock.hash_qualification_proof(proof);
    let hash2 = mock.hash_qualification_proof(proof);
    assert!(hash1 == hash2, "same proof should produce same hash");
    assert!(hash1 != 0, "hash should be non-zero");
}

#[test]
fn test_hash_qualification_proof_different_proofs_different_hashes() {
    let mock = deploy_entry_requirement_mock();
    let proof_ext_a = QualificationProof::Extension(array![0x123].span());
    let proof_nft = QualificationProof::NFT(NFTQualification { token_id: 42 });
    let proof_ext_b = QualificationProof::Extension(array![0x1].span());

    let hash_ext_a = mock.hash_qualification_proof(proof_ext_a);
    let hash_nft = mock.hash_qualification_proof(proof_nft);
    let hash_ext_b = mock.hash_qualification_proof(proof_ext_b);

    assert!(hash_ext_a != hash_nft, "extension and nft proofs should have different hashes");
    assert!(hash_ext_a != hash_ext_b, "different extension proofs should have different hashes");
    assert!(hash_nft != hash_ext_b, "nft and extension proofs should have different hashes");
}
