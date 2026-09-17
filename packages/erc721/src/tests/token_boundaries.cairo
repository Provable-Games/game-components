use openzeppelin_interfaces::erc2981::{IERC2981Dispatcher, IERC2981DispatcherTrait};
use openzeppelin_interfaces::erc721::{
    ERC721ABIDispatcher, ERC721ABIDispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait,
    IERC721EnumerableDispatcher, IERC721EnumerableDispatcherTrait, IERC721MetadataDispatcher,
    IERC721MetadataDispatcherTrait, IERC721MetadataSafeDispatcher,
    IERC721MetadataSafeDispatcherTrait, IERC721SafeDispatcher, IERC721SafeDispatcherTrait,
    IERC721_ID,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use super::extension_host::{
    IExtensionControlsDispatcher, IExtensionControlsDispatcherTrait,
    IExtensionControlsSafeDispatcher, IExtensionControlsSafeDispatcherTrait,
};
use super::reentrant_receiver::IReceiverStateDispatcherTrait;
use super::safety_helpers::{context, expect_error};
const P: u256 = 0x800000000000011000000000000000000000000000000000000000000000001;
fn account(id: felt252) -> ContractAddress {
    id.try_into().unwrap()
}
fn deploy() -> ContractAddress {
    declare("ExtensionHost").unwrap().contract_class().deploy(@array![]).unwrap().0
}

#[test]
#[feature("safe_dispatcher")]
fn full_felt_domain_owner_approval_uri_enumeration_isolation() {
    let address = deploy();
    let raw = IExtensionControlsDispatcher { contract_address: address };
    let safe = IExtensionControlsSafeDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    let ns = IERC721SafeDispatcher { contract_address: address };
    let uri = IERC721MetadataDispatcher { contract_address: address };
    let us = IERC721MetadataSafeDispatcher { contract_address: address };
    let enumeration = IERC721EnumerableDispatcher { contract_address: address };
    let ids = array![
        0_u256, 1, 0x100000000000000000000000000000000,
        0x800000000000000000000000000000000000000000000000000000000000000, P - 1,
    ];
    let owner = account(201);
    context(address, 201, 0, 0);
    for i in 0_u32..5 {
        let id = *ids.at(i);
        raw.mint(owner, id);
        raw.set_uri(id, format!("uri-{}", i));
        nft.approve(account(210 + i.into()), id);
    }
    for i in 0_u32..5 {
        let id = *ids.at(i);
        assert_eq!(nft.owner_of(id), owner);
        assert_eq!(nft.get_approved(id), account(210 + i.into()));
        assert_eq!(uri.token_uri(id), format!("uri-{}", i));
        assert_eq!(enumeration.token_of_owner_by_index(owner, i.into()), id);
        assert_eq!(enumeration.token_by_index(i.into()), id);
    }
    for id in array![P, P + 1, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff] {
        expect_error(ns.owner_of(id), 'ERC721: invalid token ID');
        expect_error(ns.get_approved(id), 'ERC721: invalid token ID');
        expect_error(ns.approve(account(202), id), 'ERC721: invalid token ID');
        expect_error(ns.transfer_from(owner, account(202), id), 'ERC721: invalid token ID');
        expect_error(us.token_uri(id), 'ERC721: invalid token ID');
        expect_error(safe.set_uri(id, "BAD"), 'ERC721: invalid token ID');
        expect_error(safe.mint(owner, id), 'ERC721: invalid token ID');
        expect_error(safe.burn(id), 'ERC721: invalid token ID');
    }
    assert_eq!(enumeration.total_supply(), 5);
    assert_eq!(nft.balance_of(owner), 5);
    for i in 0_u32..5 {
        let id = *ids.at(i);
        assert_eq!(nft.get_approved(id), account(210 + i.into()));
        assert_eq!(uri.token_uri(id), format!("uri-{}", i));
    }
    raw.burn(P - 1);
    assert_eq!(enumeration.total_supply(), 4);
    raw.mint(owner, P - 1);
    assert_eq!(nft.get_approved(P - 1), account(0));
    assert_eq!(uri.token_uri(P - 1), "");
    assert_eq!(enumeration.total_supply(), 5);
}

#[test]
#[feature("safe_dispatcher")]
fn late_batch_failure_restores_every_extension_and_hooks() {
    let address = deploy();
    let raw = IExtensionControlsDispatcher { contract_address: address };
    let safe = IExtensionControlsSafeDispatcher { contract_address: address };
    let owner = account(201);
    raw.mint(owner, 2);
    let nft = IERC721Dispatcher { contract_address: address };
    let enumeration = IERC721EnumerableDispatcher { contract_address: address };
    let royalties = IERC2981Dispatcher { contract_address: address };
    context(address, 201, 0, 0);
    nft.approve(account(202), 2);
    let counts = raw.hook_counts();
    expect_error(safe.mint_pair(owner, 1, 2), 'ERC721: token already minted');
    assert_eq!(nft.balance_of(owner), 1);
    assert_eq!(nft.get_approved(2), account(202));
    assert_eq!(enumeration.total_supply(), 1);
    assert_eq!(enumeration.token_by_index(0), 2);
    assert_eq!(raw.hook_counts(), counts);
    assert_eq!(royalties.royalty_info(1, 10000), (owner, 100));
    raw.mint(owner, 1);
    assert_eq!(IERC721MetadataDispatcher { contract_address: address }.token_uri(1), "");
}

#[test]
#[feature("safe_dispatcher")]
fn before_hook_precedes_id_validation_and_after_hook_rollback_restores_uri() {
    let address = deploy();
    let raw = IExtensionControlsDispatcher { contract_address: address };
    let safe = IExtensionControlsSafeDispatcher { contract_address: address };
    let owner = account(201);
    raw.set_hook_mode(1);
    expect_error(safe.mint(owner, P), 'BEFORE_REJECT');
    assert_eq!(raw.hook_counts(), (0, 0));
    raw.set_hook_mode(0);
    raw.mint(owner, 0);
    raw.set_uri(0, "KEEP");
    raw.set_hook_mode(2);
    let counts = raw.hook_counts();
    expect_error(safe.burn(0), 'AFTER_REJECT');
    assert_eq!(IERC721Dispatcher { contract_address: address }.owner_of(0), owner);
    assert_eq!(IERC721MetadataDispatcher { contract_address: address }.token_uri(0), "KEEP");
    assert_eq!(raw.hook_counts(), counts);
    assert_eq!(IERC721EnumerableDispatcher { contract_address: address }.total_supply(), 1);
}

#[test]
fn nested_before_hook_mint_preserves_both_tokens_and_enumeration() {
    let address = deploy();
    let raw = IExtensionControlsDispatcher { contract_address: address };
    let owner = account(201);
    raw.set_hook_mode(3);
    raw.mint(owner, 9);
    let nft = IERC721Dispatcher { contract_address: address };
    assert_eq!(nft.owner_of(9), owner);
    assert_eq!(nft.owner_of(10), owner);
    assert_eq!(nft.balance_of(owner), 2);
    assert_eq!(raw.hook_counts(), (2, 2));
    let enumeration = IERC721EnumerableDispatcher { contract_address: address };
    assert_eq!(enumeration.total_supply(), 2);
    assert_eq!(enumeration.token_by_index(0), 10);
    assert_eq!(enumeration.token_by_index(1), 9);
}

#[test]
#[feature("safe_dispatcher")]
fn receiver_reentry_commits_nested_state_and_events() {
    let address = deploy();
    let raw = IExtensionControlsDispatcher { contract_address: address };
    let (receiver, _) = declare("ReentrantReceiver")
        .unwrap()
        .contract_class()
        .deploy(@array![address.into(), 0])
        .unwrap();
    let mut spy = snforge_std::spy_events();
    raw.safe_mint(receiver, 5, array![].span());
    let nft = IERC721Dispatcher { contract_address: address };
    let uri = IERC721MetadataDispatcher { contract_address: address };
    let enumeration = IERC721EnumerableDispatcher { contract_address: address };
    assert_eq!(nft.owner_of(5), receiver);
    assert_eq!(nft.owner_of(6), receiver);
    assert_eq!(nft.balance_of(receiver), 2);
    assert_eq!(nft.get_approved(5), account(209));
    assert_eq!(uri.token_uri(5), "RECEIVER");
    assert_eq!(enumeration.total_supply(), 2);
    assert_eq!(
        IERC2981Dispatcher { contract_address: address }.royalty_info(5, 10000), (receiver, 333),
    );
    assert_eq!(
        super::reentrant_receiver::IReceiverStateDispatcher { contract_address: receiver }
            .callbacks(),
        1,
    );
    let events = snforge_std::EventSpyTrait::get_events(ref spy);
    let mut transfers = 0;
    for (emitter, event) in events.events.span() {
        if *emitter == address && *event.keys.at(0) == selector!("Transfer") {
            transfers += 1;
        }
    }
    assert_eq!(transfers, 2);
}

#[test]
#[feature("safe_dispatcher")]
fn receiver_reject_rolls_back_nested_owner_approval_uri_royalty_and_enumeration() {
    let address = deploy();
    let raw = IExtensionControlsDispatcher { contract_address: address };
    let owner = account(201);
    let (receiver, _) = declare("ReentrantReceiver")
        .unwrap()
        .contract_class()
        .deploy(@array![address.into(), 1])
        .unwrap();
    raw.mint(owner, 5);
    raw.set_uri(5, "ORIGINAL");
    context(address, 201, 0, 0);
    let nft = IERC721Dispatcher { contract_address: address };
    nft.approve(account(202), 5);
    let counts = raw.hook_counts();
    // Impersonate only the outer transfer: receiver reentry must retain its real caller.
    snforge_std::cheat_caller_address(address, owner, snforge_std::CheatSpan::TargetCalls(1));
    let error = IERC721SafeDispatcher { contract_address: address }
        .safe_transfer_from(owner, receiver, 5, array![].span())
        .unwrap_err();
    assert_eq!(error, array!['RECEIVER_REJECT', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED']);
    assert_eq!(nft.owner_of(5), owner);
    assert_eq!(nft.get_approved(5), account(202));
    assert_eq!(nft.balance_of(owner), 1);
    assert_eq!(nft.balance_of(receiver), 0);
    expect_error(
        IERC721SafeDispatcher { contract_address: address }.owner_of(6), 'ERC721: invalid token ID',
    );
    assert_eq!(IERC721MetadataDispatcher { contract_address: address }.token_uri(5), "ORIGINAL");
    assert_eq!(IERC721EnumerableDispatcher { contract_address: address }.total_supply(), 1);
    assert_eq!(raw.hook_counts(), counts);
    assert_eq!(
        IERC2981Dispatcher { contract_address: address }.royalty_info(5, 10000), (owner, 100),
    );
    assert_eq!(
        super::reentrant_receiver::IReceiverStateDispatcher { contract_address: receiver }
            .callbacks(),
        0,
    );
}

#[test]
fn full_mixin_public_aliases_preserve_state_and_metadata() {
    let address = deploy();
    let raw = IExtensionControlsDispatcher { contract_address: address };
    let owner = account(201);
    let next = account(202);
    let nft = ERC721ABIDispatcher { contract_address: address };
    raw.mint(owner, 0);
    raw.set_uri(0, "ALIAS");
    context(address, 201, 0, 0);
    assert_eq!(nft.name(), "Felt");
    assert_eq!(nft.symbol(), "FELT");
    assert_eq!(nft.tokenURI(0), "ALIAS");
    assert!(nft.supports_interface(IERC721_ID));
    assert_eq!(nft.ownerOf(0), owner);
    assert_eq!(nft.balanceOf(owner), 1);
    nft.setApprovalForAll(next, true);
    assert!(nft.isApprovedForAll(owner, next));
    assert!(nft.is_approved_for_all(owner, next));
    nft.set_approval_for_all(next, false);
    nft.approve(next, 0);
    assert_eq!(nft.getApproved(0), next);
    nft.transferFrom(owner, next, 0);
    assert_eq!(nft.getApproved(0), account(0));
    let (receiver, _) = declare("DualCaseAccountMock")
        .unwrap()
        .contract_class()
        .deploy(@array![1234])
        .unwrap();
    context(address, 202, 0, 0);
    nft.safeTransferFrom(next, receiver, 0, array![].span());
    assert_eq!(nft.ownerOf(0), receiver);
}
