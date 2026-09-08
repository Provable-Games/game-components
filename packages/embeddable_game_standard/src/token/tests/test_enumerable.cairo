use openzeppelin_interfaces::erc721::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721SafeDispatcher, IERC721SafeDispatcherTrait,
    IERC721_ENUMERABLE_ID,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, test_address,
};
use starknet::ContractAddress;
use crate::token::extensions::enumerable::interface::{
    IENUMERABLE_OWNER_ID, IEnumerableOwnerDispatcher, IEnumerableOwnerDispatcherTrait,
    IEnumerableOwnerSafeDispatcher, IEnumerableOwnerSafeDispatcherTrait,
};
use super::enumerable_fixtures::{
    IEnumerationFixtureDispatcher, IEnumerationFixtureDispatcherTrait,
    IEnumerationFixtureSafeDispatcher, IEnumerationFixtureSafeDispatcherTrait,
};

pub fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

pub fn deploy(name: ByteArray) -> ContractAddress {
    let (address, _) = declare(name).unwrap().contract_class().deploy(@array![]).unwrap();
    address
}

fn expect_error<T, +Drop<T>>(result: Result<T, Array<felt252>>, error: felt252) {
    match result {
        Result::Err(data) => assert!(
            data == array![error, 'ENTRYPOINT_FAILED'], "Enumeration mismatch",
        ),
        Result::Ok(_) => panic!("Expected revert"),
    }
}

fn replace_owner(
    owners: Span<ContractAddress>, index: u32, owner: ContractAddress,
) -> Array<ContractAddress> {
    let mut updated = array![];
    for i in 0..owners.len() {
        updated.append(if i == index {
            owner
        } else {
            *owners.at(i)
        });
    }
    updated
}

// Independent oracle: ownership only, with no index or swap-and-pop algorithm.
#[feature("safe_dispatcher")]
pub fn assert_inventory(
    address: ContractAddress, ids: Span<felt252>, owners: Span<ContractAddress>,
) {
    let nft = IERC721Dispatcher { contract_address: address };
    let safe_nft = IERC721SafeDispatcher { contract_address: address };
    let enumeration = IEnumerableOwnerDispatcher { contract_address: address };
    let safe_enumeration = IEnumerableOwnerSafeDispatcher { contract_address: address };
    let fixture = IEnumerationFixtureDispatcher { contract_address: address };
    for i in 0..ids.len() {
        let id = *ids.at(i);
        let owner = *owners.at(i);
        if owner == addr(0) {
            expect_error(safe_nft.owner_of(id.into()), 'ERC721: invalid token ID');
            let (_, reverse) = fixture.stored_indexes(addr(201), 0, id);
            assert!(reverse == 0, "Burned reverse index not clear");
        } else {
            assert!(nft.owner_of(id.into()) == owner, "Enumeration mismatch");
        }
    }
    for value in 201_u32..204 {
        let owner = addr(value.into());
        let mut expected = 0_u32;
        for candidate in owners {
            if *candidate == owner {
                expected += 1;
            }
        }
        assert!(nft.balance_of(owner) == expected.into(), "Enumeration mismatch");
        let mut seen = array![];
        for index in 0..expected {
            let actual = enumeration.token_of_owner_by_index(owner, index.into());
            let mut found = false;
            for i in 0..ids.len() {
                if actual == (*ids.at(i)).into() && *owners.at(i) == owner {
                    found = true;
                }
            }
            assert!(found, "Unexpected inventory member");
            for earlier in seen.span() {
                assert!(actual != *earlier, "Enumeration mismatch");
            }
            assert!(
                fixture
                    .stored_indexes(
                        owner, index.into(), actual.try_into().unwrap(),
                    ) == (actual.try_into().unwrap(), index.into()),
                "Enumeration mismatch",
            );
            seen.append(actual);
        }
        assert!(fixture.all_tokens(owner) == seen.span(), "Enumeration mismatch");
        // Every vacated tail cell remains zero, even after transfers and burns.
        for index in expected..ids.len() {
            let (tail, _) = fixture.stored_indexes(owner, index.into(), 0);
            assert!(tail == 0, "Vacated tail not clear");
        }
        expect_error(
            safe_enumeration.token_of_owner_by_index(owner, expected.into()),
            'ERC721Enum: out of bounds index',
        );
    }
}

#[test]
#[fuzzer]
#[feature("safe_dispatcher")]
fn enumerable_random_ownership_sequences(seed: u256) {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let address = deploy(name);
        let fixture = IEnumerationFixtureDispatcher { contract_address: address };
        let nft = IERC721Dispatcher { contract_address: address };
        let mut ids = array![];
        let mut owners = array![];
        for i in 0_u32..8 {
            // Exercise both limbs without setting the standard's soulbound bit.
            let id = 0x100000000000000000000000000000000 + i.into();
            let owner = addr((201 + i % 3).into());
            fixture.mint(owner, id.into());
            ids.append(id);
            owners.append(owner);
        }
        let mut entropy = seed;
        for _step in 0_u32..24 {
            let digit: u32 = (entropy % 256).try_into().unwrap();
            entropy /= 256;
            let index = digit % 8;
            let operation = (digit / 8) % 4;
            let recipient = addr((201 + (digit / 32) % 3).into());
            let owner = *owners.at(index);
            let id = *ids.at(index);
            if owner == addr(0) {
                fixture.mint(recipient, id.into());
                owners = replace_owner(owners.span(), index, recipient);
            } else {
                start_cheat_caller_address(address, owner);
                if operation == 0 {
                    fixture.burn(id.into());
                    owners = replace_owner(owners.span(), index, addr(0));
                } else {
                    let to = if operation == 1 {
                        owner
                    } else {
                        recipient
                    };
                    nft.transfer_from(owner, to, id.into());
                    owners = replace_owner(owners.span(), index, to);
                }
            }
            assert_inventory(address, ids.span(), owners.span());
        }
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_transfer_to_empty_then_append_and_remove() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let address = deploy(name);
        let fixture = IEnumerationFixtureDispatcher { contract_address: address };
        let nft = IERC721Dispatcher { contract_address: address };
        fixture.mint(addr(201), 1);
        fixture.mint(addr(201), 2);
        start_cheat_caller_address(address, addr(201));
        nft.transfer_from(addr(201), addr(202), 2);
        fixture.mint(addr(202), 3);
        start_cheat_caller_address(address, addr(202));
        fixture.burn(2);
        assert_inventory(
            address, array![1, 2, 3].span(), array![addr(201), addr(0), addr(202)].span(),
        );
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_burn_nonzero_index_remint_then_append_and_remove() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let address = deploy(name);
        let fixture = IEnumerationFixtureDispatcher { contract_address: address };
        fixture.mint(addr(201), 1);
        fixture.mint(addr(201), 2);
        start_cheat_caller_address(address, addr(201));
        fixture.burn(2);
        fixture.mint(addr(202), 2);
        fixture.mint(addr(202), 3);
        start_cheat_caller_address(address, addr(202));
        fixture.burn(2);
        assert_inventory(
            address, array![1, 2, 3].span(), array![addr(201), addr(0), addr(202)].span(),
        );
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_swap_pop_self_transfer_and_empty_owner() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let address = deploy(name);
        let fixture = IEnumerationFixtureDispatcher { contract_address: address };
        let nft = IERC721Dispatcher { contract_address: address };
        for id in 0_u32..4 {
            fixture.mint(addr(201), id.into());
        }
        start_cheat_caller_address(address, addr(201));
        nft.transfer_from(addr(201), addr(201), 1);
        assert!(fixture.all_tokens(addr(201)) == array![0, 1, 2, 3].span(), "Enumeration mismatch");
        fixture.burn(1);
        assert!(fixture.all_tokens(addr(201)) == array![0, 3, 2].span(), "Enumeration mismatch");
        fixture.burn(3); // The token moved by the preceding removal.
        fixture.burn(2);
        fixture.burn(0);
        assert_inventory(
            address, array![0, 1, 2, 3].span(), array![addr(0), addr(0), addr(0), addr(0)].span(),
        );
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_callback_consistency_reentrancy_and_rollback() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        for mode in 0_u32..4 {
            let address = deploy(name.clone());
            let receiver = deploy("EnumerationAuditReceiver");
            let fixture = IEnumerationFixtureDispatcher { contract_address: address };
            let nft = IERC721Dispatcher { contract_address: address };
            let safe = IERC721SafeDispatcher { contract_address: address };
            let enumeration = IEnumerableOwnerDispatcher { contract_address: address };
            for id in 1_u32..4 {
                fixture.mint(addr(201), id.into());
            }
            fixture.mint(receiver, 4);
            start_cheat_caller_address(address, addr(201));
            nft.approve(test_address(), 2);
            stop_cheat_caller_address(address);
            let result = safe
                .safe_transfer_from(addr(201), receiver, 2, array![mode.into()].span());
            if mode == 3 {
                expect_error(result, 'ERC721: safe transfer failed');
                assert!(
                    fixture.all_tokens(addr(201)) == array![1, 2, 3].span(), "Enumeration mismatch",
                );
                assert!(nft.get_approved(2) == test_address(), "Enumeration mismatch");
            } else {
                result.unwrap();
                assert!(
                    enumeration.token_of_owner_by_index(addr(201), 1) == 3, "Enumeration mismatch",
                );
                if mode == 1 {
                    assert!(
                        fixture.all_tokens(addr(201)) == array![1, 3, 2].span(),
                        "Enumeration mismatch",
                    );
                } else {
                    assert!(nft.balance_of(addr(201)) == 2, "Enumeration mismatch");
                    if mode == 2 {
                        expect_error(safe.owner_of(2), 'ERC721: invalid token ID');
                    }
                }
            }
            assert!(enumeration.token_of_owner_by_index(addr(201), 0) == 1, "Enumeration mismatch");
            assert!(enumeration.token_of_owner_by_index(receiver, 0) == 4, "Enumeration mismatch");
            assert!(
                nft.balance_of(receiver) == if mode == 0 {
                    2
                } else {
                    1
                }, "Enumeration mismatch",
            );
            if mode == 0 {
                assert!(
                    enumeration.token_of_owner_by_index(receiver, 1) == 2, "Enumeration mismatch",
                );
            }
        }
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_safe_mint_rejection_rolls_back() {
    let address = deploy("EnumerableGenericMock");
    let receiver = deploy("EnumerationAuditReceiver");
    let fixture = IEnumerationFixtureSafeDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    // Mode 2 burns during the callback; the outer safe mint must remain consistent.
    fixture.safe_mint(receiver, 1, array![2].span()).unwrap();
    assert!(nft.balance_of(receiver) == 0, "Enumeration mismatch");
    fixture.safe_mint(receiver, 1, array![0].span()).unwrap();
    assert!(nft.balance_of(receiver) == 1, "Enumeration mismatch");
    // A deployed non-receiver forces OZ's safe-mint check to fail after the update.
    let non_receiver = deploy("EnumerableGenericMock");
    expect_error(fixture.safe_mint(non_receiver, 2, array![].span()), 'ERC721: safe mint failed');
    assert!(nft.balance_of(non_receiver) == 0, "Enumeration mismatch");
    fixture.mint(addr(201), 2).unwrap();
    assert!(nft.owner_of(2) == addr(201), "Enumeration mismatch");
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_failed_mutations_preserve_inventory_and_approval() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let address = deploy(name);
        let fixture = IEnumerationFixtureSafeDispatcher { contract_address: address };
        let nft = IERC721Dispatcher { contract_address: address };
        let safe = IERC721SafeDispatcher { contract_address: address };
        fixture.mint(addr(201), 1).unwrap();
        fixture.mint(addr(201), 2).unwrap();
        expect_error(fixture.mint(addr(201), 2), 'ERC721: token already minted');
        expect_error(fixture.mint(addr(0), 3), 'ERC721: invalid receiver');
        expect_error(safe.transfer_from(addr(201), addr(202), 2), 'ERC721: unauthorized caller');
        start_cheat_caller_address(address, addr(201));
        nft.approve(addr(202), 2);
        start_cheat_caller_address(address, addr(202));
        expect_error(safe.transfer_from(addr(202), addr(202), 2), 'ERC721: invalid sender');
        expect_error(fixture.burn(2), 'Only holder can burn');
        assert!(nft.get_approved(2) == addr(202), "Enumeration mismatch");
        assert_inventory(address, array![1, 2].span(), array![addr(201), addr(201)].span());
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_felt_boundaries_and_wide_id_rollback() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let address = deploy(name);
        let fixture = IEnumerationFixtureSafeDispatcher { contract_address: address };
        let enumeration = IEnumerableOwnerSafeDispatcher { contract_address: address };
        let max_felt = 0x800000000000011000000000000000000000000000000000000000000000000;
        fixture.mint(addr(201), 0).unwrap();
        fixture.mint(addr(201), max_felt.into()).unwrap();
        for id in array![
            0x800000000000011000000000000000000000000000000000000000000000001_u256,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        ] {
            expect_error(fixture.mint(addr(201), id), 'ERC721Enum: token ID too large');
        }
        expect_error(
            enumeration
                .token_of_owner_by_index(
                    addr(201), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
                ),
            'ERC721Enum: out of bounds index',
        );
        expect_error(enumeration.token_of_owner_by_index(addr(0), 0), 'ERC721: invalid account');
        assert_inventory(address, array![0, max_felt].span(), array![addr(201), addr(201)].span());
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_owner_hook_composes_soulbound_and_burn() {
    let address = deploy("EnumerableOwnerMock");
    let fixture = IEnumerationFixtureDispatcher { contract_address: address };
    let safe = IERC721SafeDispatcher { contract_address: address };
    let id = 0x80000000000000000000000000000000;
    fixture.mint(addr(201), id.into());
    start_cheat_caller_address(address, addr(201));
    expect_error(safe.transfer_from(addr(201), addr(202), id.into()), 'Token is soulbound');
    assert_inventory(address, array![id].span(), array![addr(201)].span());
    fixture.burn(id.into());
    assert_inventory(address, array![id].span(), array![addr(0)].span());
}

#[test]
fn enumerable_registers_only_owner_interface_and_initializer_is_idempotent() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let address = deploy(name);
        let fixture = IEnumerationFixtureDispatcher { contract_address: address };
        let src5 = ISRC5Dispatcher { contract_address: address };
        assert!(src5.supports_interface(IENUMERABLE_OWNER_ID), "Missing owner enumeration");
        assert!(!src5.supports_interface(IERC721_ENUMERABLE_ID), "No global enumeration");
        fixture.mint(addr(201), 7);
        fixture.initialize_again();
        assert!(fixture.all_tokens(addr(201)) == array![7].span(), "Enumeration mismatch");
    }
}
