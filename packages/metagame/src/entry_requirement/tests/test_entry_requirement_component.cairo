use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use crate::entry_requirement::models::{
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
    ) -> ContractAddress;
    fn assert_valid_entry_requirement(self: @TContractState, entry_requirement: EntryRequirement);
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
    let token_addr = make_address(0xABC);
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
        EntryRequirementType::allowlist(_) => { panic!("expected token type"); },
        EntryRequirementType::extension(_) => { panic!("expected token type"); },
    }
}

#[test]
fn test_set_and_get_allowlist_requirement() {
    let mock = deploy_entry_requirement_mock();
    let addr1 = make_address(0x111);
    let addr2 = make_address(0x222);
    let context_id: u64 = 99;

    let req = EntryRequirement {
        entry_limit: 5,
        entry_requirement_type: EntryRequirementType::allowlist(array![addr1, addr2].span()),
    };
    mock.set_entry_requirement(context_id, Option::Some(req));

    let result = mock.get_entry_requirement(context_id);
    assert!(result.is_some(), "should return Some");

    let retrieved = result.unwrap();
    assert!(retrieved.entry_limit == 5, "entry_limit mismatch");

    match retrieved.entry_requirement_type {
        EntryRequirementType::token(_) => { panic!("expected allowlist type"); },
        EntryRequirementType::allowlist(addresses) => {
            assert!(addresses.len() == 2, "should have 2 addresses");
            assert!(*addresses.at(0) == addr1, "first address mismatch");
            assert!(*addresses.at(1) == addr2, "second address mismatch");
        },
        EntryRequirementType::extension(_) => { panic!("expected allowlist type"); },
    }
}

#[test]
fn test_set_and_get_extension_requirement() {
    let mock = deploy_entry_requirement_mock();
    let owner = make_address(0x1);
    let ext_addr = deploy_entry_validator_mock(owner, false);
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
        EntryRequirementType::allowlist(_) => { panic!("expected extension type"); },
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
    let token_addr = make_address(0xABC);
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
    let token_addr = make_address(0xABC);
    let req1 = EntryRequirement {
        entry_limit: 10, entry_requirement_type: EntryRequirementType::token(token_addr),
    };
    mock.set_entry_requirement(context_id, Option::Some(req1));

    // Overwrite with different token requirement
    let token_addr2 = make_address(0xDEF);
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

    let token_addr = make_address(0xAAA);
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
    let token_addr = make_address(0xAAA);
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
    let proof = QualificationProof::Address(make_address(0x123));
    let entries = mock.get_qualification_entries(1, proof);
    assert!(entries.context_id == 1, "context_id mismatch");
    assert!(entries.entry_count == 0, "default entry_count should be 0");
}

#[test]
fn test_set_qualification_entries() {
    let mock = deploy_entry_requirement_mock();
    let proof = QualificationProof::Address(make_address(0x123));

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
    let proof = QualificationProof::Address(make_address(0x123));

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
    let proof = QualificationProof::Address(make_address(0x123));

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
    let proof = QualificationProof::Address(make_address(0x123));

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
    let proof1 = QualificationProof::Address(make_address(0x111));
    let proof2 = QualificationProof::Address(make_address(0x222));

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
fn test_update_qualification_entries_allowlist_type() {
    let mock = deploy_entry_requirement_mock();
    let context_id: u64 = 60;
    let addr1 = make_address(0x111);
    let proof = QualificationProof::Address(make_address(0x123));

    let req = EntryRequirement {
        entry_limit: 2,
        entry_requirement_type: EntryRequirementType::allowlist(array![addr1].span()),
    };

    // Update should work the same for allowlist type (non-Extension branch)
    mock.update_qualification_entries(context_id, proof, req);
    let result = mock.get_qualification_entries(context_id, proof);
    assert!(result.entry_count == 1, "entry_count should be 1");
}

#[test]
#[should_panic(expected: "EntryRequirement: Maximum qualified entries reached")]
fn test_update_qualification_entries_allowlist_panics_at_limit() {
    let mock = deploy_entry_requirement_mock();
    let context_id: u64 = 60;
    let addr1 = make_address(0x111);
    let proof = QualificationProof::Address(make_address(0x123));

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::allowlist(array![addr1].span()),
    };

    mock.update_qualification_entries(context_id, proof, req);
    mock.update_qualification_entries(context_id, proof, req);
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

fn deploy_entry_validator_mock(owner: ContractAddress, registration_only: bool) -> ContractAddress {
    let contract_class = declare("EntryValidatorMock").expect('declare failed').contract_class();
    let mut calldata = array![];
    owner.serialize(ref calldata);
    registration_only.serialize(ref calldata);
    let (contract_address, _) = contract_class.deploy(@calldata).expect('deploy failed');
    contract_address
}

fn deploy_rejecting_entry_validator_mock(
    owner: ContractAddress, registration_only: bool,
) -> ContractAddress {
    let contract_class = declare("RejectingEntryValidatorMock")
        .expect('declare failed')
        .contract_class();
    let mut calldata = array![];
    owner.serialize(ref calldata);
    registration_only.serialize(ref calldata);
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
        .validate_qualification(1, req, QualificationProof::NFT(NFTQualification { token_id }));
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

    // Pass Address proof for a token requirement
    mock.validate_qualification(1, req, QualificationProof::Address(make_address(0x123)));
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
            1, req, QualificationProof::NFT(NFTQualification { token_id: 999 }),
        );
}

#[test]
fn test_validate_qualification_allowlist_returns_address() {
    let mock = deploy_entry_requirement_mock();
    let addr1 = make_address(0x111);
    let addr2 = make_address(0x222);

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::allowlist(array![addr1, addr2].span()),
    };

    let result = mock.validate_qualification(1, req, QualificationProof::Address(addr2));
    assert!(result == addr2, "should return the qualifying address");
}

#[test]
#[should_panic(expected: "EntryRequirement: Qualifying address is not in allowlist")]
fn test_validate_qualification_allowlist_address_not_found() {
    let mock = deploy_entry_requirement_mock();
    let addr1 = make_address(0x111);

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::allowlist(array![addr1].span()),
    };

    // Address 0x999 is not in allowlist
    mock.validate_qualification(1, req, QualificationProof::Address(make_address(0x999)));
}

#[test]
#[should_panic(expected: "EntryRequirement: Provided qualification proof is not of type 'Address'")]
fn test_validate_qualification_allowlist_wrong_proof_type() {
    let mock = deploy_entry_requirement_mock();
    let addr1 = make_address(0x111);

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::allowlist(array![addr1].span()),
    };

    // Pass NFT proof for allowlist requirement
    mock.validate_qualification(1, req, QualificationProof::NFT(NFTQualification { token_id: 1 }));
}

#[test]
fn test_validate_qualification_extension_returns_caller() {
    let mock = deploy_entry_requirement_mock();
    let caller = make_address(0x555);
    let validator_addr = deploy_entry_validator_mock(caller, false);

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
        .validate_qualification(1, req, QualificationProof::Extension(array![].span()));
    assert!(result == caller, "should return the caller address");
}

#[test]
#[should_panic(expected: "EntryRequirement: Invalid entry according to extension")]
fn test_validate_qualification_extension_rejects() {
    let mock = deploy_entry_requirement_mock();
    let caller = make_address(0x555);
    let validator_addr = deploy_rejecting_entry_validator_mock(caller, false);

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    snforge_std::cheat_caller_address(
        mock.contract_address, caller, snforge_std::CheatSpan::TargetCalls(1),
    );
    mock.validate_qualification(1, req, QualificationProof::Extension(array![].span()));
}

#[test]
#[should_panic(
    expected: "EntryRequirement: Provided qualification proof is not of type 'Extension'",
)]
fn test_validate_qualification_extension_wrong_proof_type() {
    let mock = deploy_entry_requirement_mock();
    let caller = make_address(0x555);
    let validator_addr = deploy_entry_validator_mock(caller, false);

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    // Pass Address proof for extension requirement
    mock.validate_qualification(1, req, QualificationProof::Address(make_address(0x123)));
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
    let non_erc721_addr = deploy_entry_validator_mock(make_address(0x1), false);

    let req = EntryRequirement {
        entry_limit: 1, entry_requirement_type: EntryRequirementType::token(non_erc721_addr),
    };

    mock.assert_valid_entry_requirement(req);
}

#[test]
fn test_assert_valid_entry_requirement_allowlist_noop() {
    let mock = deploy_entry_requirement_mock();

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::allowlist(array![make_address(0x111)].span()),
    };

    // Should not panic
    mock.assert_valid_entry_requirement(req);
}

#[test]
fn test_assert_valid_entry_requirement_extension_valid() {
    let mock = deploy_entry_requirement_mock();
    let validator_addr = deploy_entry_validator_mock(make_address(0x1), false);

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: validator_addr, config: array![].span() },
        ),
    };

    // Should not panic - EntryValidatorMock supports IEntryValidator
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
    // Deploy an ERC721 mock (doesn't support IEntryValidator)
    let erc721_addr = deploy_erc721_mock();

    let req = EntryRequirement {
        entry_limit: 1,
        entry_requirement_type: EntryRequirementType::extension(
            ExtensionConfig { address: erc721_addr, config: array![].span() },
        ),
    };

    mock.assert_valid_entry_requirement(req);
}
