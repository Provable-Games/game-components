//! Tests for the assumptions behind skipped writes and shared storage/owner reads.
use openzeppelin_interfaces::erc721::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721SafeDispatcher, IERC721SafeDispatcherTrait,
};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address, test_address};
use starknet::ContractAddress;
use super::enumerable_fixtures::{
    IEnumerationFixtureDispatcher, IEnumerationFixtureDispatcherTrait,
    IEnumerationFixtureSafeDispatcher, IEnumerationFixtureSafeDispatcherTrait,
};
use super::test_enumerable::{addr, assert_inventory, deploy};

// Three base-four digits: 1..3 identify tokens, zero terminates the list.
// Reject gaps and repeated tokens. This enumerates each ordered subset once.
fn owner_list(mut encoded: u32) -> Option<Array<u32>> {
    let mut list = array![];
    let mut ended = false;
    for _ in 0_u32..3 {
        let digit = encoded % 4;
        encoded /= 4;
        if digit == 0 {
            ended = true;
        } else {
            if ended {
                return Option::None;
            }
            for seen in list.span() {
                if *seen == digit - 1 {
                    return Option::None;
                }
            }
            list.append(digit - 1);
        }
    }
    Option::Some(list)
}

fn contains(list: Span<u32>, index: u32) -> bool {
    for value in list {
        if *value == index {
            return true;
        }
    }
    false
}

fn owner_at(a: Span<u32>, b: Span<u32>, index: u32) -> ContractAddress {
    if contains(a, index) {
        addr(201)
    } else if contains(b, index) {
        addr(202)
    } else {
        addr(0)
    }
}

// All 49 disjoint ordered-subset pairs for three token IDs and two owners.
// Each case exercises every legal outgoing transition under both hook styles.
#[test]
#[test_case(0, 0)]
#[test_case(0, 1)]
#[test_case(0, 2)]
#[test_case(0, 3)]
#[test_case(0, 6)]
#[test_case(0, 7)]
#[test_case(0, 9)]
#[test_case(0, 11)]
#[test_case(0, 13)]
#[test_case(0, 14)]
#[test_case(0, 27)]
#[test_case(0, 30)]
#[test_case(0, 39)]
#[test_case(0, 45)]
#[test_case(0, 54)]
#[test_case(0, 57)]
#[test_case(1, 0)]
#[test_case(1, 2)]
#[test_case(1, 3)]
#[test_case(1, 11)]
#[test_case(1, 14)]
#[test_case(2, 0)]
#[test_case(2, 1)]
#[test_case(2, 3)]
#[test_case(2, 7)]
#[test_case(2, 13)]
#[test_case(3, 0)]
#[test_case(3, 1)]
#[test_case(3, 2)]
#[test_case(3, 6)]
#[test_case(3, 9)]
#[test_case(6, 0)]
#[test_case(6, 3)]
#[test_case(7, 0)]
#[test_case(7, 2)]
#[test_case(9, 0)]
#[test_case(9, 3)]
#[test_case(11, 0)]
#[test_case(11, 1)]
#[test_case(13, 0)]
#[test_case(13, 2)]
#[test_case(14, 0)]
#[test_case(14, 1)]
#[test_case(27, 0)]
#[test_case(30, 0)]
#[test_case(39, 0)]
#[test_case(45, 0)]
#[test_case(54, 0)]
#[test_case(57, 0)]
#[feature("safe_dispatcher")]
fn enumerable_all_small_inventory_states_and_transitions(a_code: u32, b_code: u32) {
    let a = owner_list(a_code).unwrap();
    let b = owner_list(b_code).unwrap();
    for index in a.span() {
        assert!(!contains(b.span(), *index), "Invalid state fixture");
    }
    let ids: Span<felt252> = array![
        0, 0x100000000000000000000000000000001,
        0x800000000000011000000000000000000000000000000000000000000000000,
    ]
        .span();
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let mut transitions = 0_u32;
        for token in 0_u32..3 {
            let from = owner_at(a.span(), b.span(), token);
            for destination in 0_u32..3 {
                let to = if destination == 0 {
                    addr(0)
                } else {
                    addr((200 + destination).into())
                };
                if from == addr(0) && to == addr(0) {
                    continue;
                }
                let address = deploy(name.clone());
                let fixture = IEnumerationFixtureDispatcher { contract_address: address };
                let nft = IERC721Dispatcher { contract_address: address };
                for index in a.span() {
                    fixture.mint(addr(201), (*ids.at(*index)).into());
                }
                for index in b.span() {
                    fixture.mint(addr(202), (*ids.at(*index)).into());
                }
                let id = (*ids.at(token)).into();
                if from == addr(0) {
                    fixture.mint(to, id);
                } else {
                    start_cheat_caller_address(address, from);
                    if to == addr(0) {
                        fixture.burn(id);
                    } else {
                        nft.transfer_from(from, to, id);
                    }
                }
                let mut owners = array![];
                for index in 0_u32..3 {
                    owners
                        .append(
                            if index == token {
                                to
                            } else {
                                owner_at(a.span(), b.span(), index)
                            },
                        );
                }
                assert_inventory(address, ids, owners.span());
                transitions += 1;
            }
        }
        assert!(transitions == 6 + a.len() + b.len(), "Incomplete transition enumeration");
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_approved_operator_is_not_the_previous_owner() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let address = deploy(name);
        let fixture = IEnumerationFixtureDispatcher { contract_address: address };
        let nft = IERC721Dispatcher { contract_address: address };
        let safe = IERC721SafeDispatcher { contract_address: address };
        fixture.mint(addr(201), 1);
        fixture.mint(addr(201), 2);
        fixture.mint(addr(201), 3);
        // Give the operator its own inventory, so a wrong owner snapshot can corrupt it.
        fixture.mint(addr(202), 4);
        fixture.mint(addr(202), 5);
        start_cheat_caller_address(address, addr(201));
        nft.approve(addr(202), 2);
        nft.set_approval_for_all(addr(202), true);
        start_cheat_caller_address(address, addr(202));
        nft.transfer_from(addr(201), addr(203), 2);
        assert_inventory(
            address,
            array![1, 2, 3, 4, 5].span(),
            array![addr(201), addr(203), addr(201), addr(202), addr(202)].span(),
        );
        nft.transfer_from(addr(201), addr(202), 3);
        assert_inventory(
            address,
            array![1, 2, 3, 4, 5].span(),
            array![addr(201), addr(203), addr(202), addr(202), addr(202)].span(),
        );
        // Reverted authorization cannot commit the hook's attempted index changes.
        let result = safe.transfer_from(addr(203), addr(202), 2);
        assert!(
            result == Result::Err(array!['ERC721: unauthorized caller', 'ENTRYPOINT_FAILED']),
            "Unexpected error",
        );
        assert_inventory(
            address,
            array![1, 2, 3, 4, 5].span(),
            array![addr(201), addr(203), addr(202), addr(202), addr(202)].span(),
        );
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_burn_zero_index_then_remint_into_reused_empty_wallet() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let address = deploy(name);
        let fixture = IEnumerationFixtureDispatcher { contract_address: address };
        let nft = IERC721Dispatcher { contract_address: address };
        // Burn index zero while another token must be swapped into its place.
        fixture.mint(addr(201), 0);
        fixture.mint(addr(201), 1);
        fixture.mint(addr(202), 2);
        start_cheat_caller_address(address, addr(202));
        nft.transfer_from(addr(202), addr(203), 2);
        start_cheat_caller_address(address, addr(201));
        fixture.burn(0);
        fixture.mint(addr(202), 0);
        fixture.mint(addr(202), 3);
        start_cheat_caller_address(address, addr(202));
        fixture.burn(0);
        assert_inventory(
            address,
            array![0, 1, 2, 3].span(),
            array![addr(0), addr(201), addr(203), addr(202)].span(),
        );
        fixture.burn(3);
        fixture.mint(addr(202), 0);
        assert_inventory(
            address,
            array![0, 1, 2, 3].span(),
            array![addr(202), addr(201), addr(203), addr(0)].span(),
        );
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_duplicate_mint_to_different_owner_rolls_back_both_inventories() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        let address = deploy(name);
        let fixture = IEnumerationFixtureSafeDispatcher { contract_address: address };
        fixture.mint(addr(201), 1).unwrap();
        fixture.mint(addr(201), 2).unwrap();
        fixture.mint(addr(202), 3).unwrap();
        let result = fixture.mint(addr(202), 2);
        assert!(
            result == Result::Err(array!['ERC721: token already minted', 'ENTRYPOINT_FAILED']),
            "Unexpected error",
        );
        assert_inventory(
            address, array![1, 2, 3].span(), array![addr(201), addr(201), addr(202)].span(),
        );
    }
}

#[test]
#[feature("safe_dispatcher")]
fn enumerable_safe_receiver_reenters_after_transfer_to_empty_wallet() {
    for name in array!["EnumerableGenericMock", "EnumerableOwnerMock"] {
        for mode in 0_u32..4 {
            let address = deploy(name.clone());
            let receiver = deploy("EnumerationAuditReceiver");
            let fixture = IEnumerationFixtureDispatcher { contract_address: address };
            let nft = IERC721Dispatcher { contract_address: address };
            let safe = IERC721SafeDispatcher { contract_address: address };
            fixture.mint(addr(201), 1);
            fixture.mint(addr(201), 2);
            start_cheat_caller_address(address, addr(201));
            nft.approve(test_address(), 2);
            stop_cheat_caller_address(address);
            let result = safe
                .safe_transfer_from(addr(201), receiver, 2, array![mode.into()].span());
            if mode == 3 {
                assert!(
                    result == Result::Err(
                        array!['ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'],
                    ),
                    "Unexpected error",
                );
                assert!(nft.get_approved(2) == test_address(), "Approval not restored");
            } else {
                result.unwrap();
            }
            assert!(
                fixture
                    .all_tokens(addr(201)) == if mode == 1 || mode == 3 {
                        array![1, 2].span()
                    } else {
                        array![1].span()
                    },
                "Wrong sender inventory",
            );
            assert!(
                fixture
                    .all_tokens(receiver) == if mode == 0 {
                        array![2].span()
                    } else {
                        array![].span()
                    },
                "Wrong receiver inventory",
            );
            if mode == 2 {
                let (_, reverse) = fixture.stored_indexes(receiver, 0, 2);
                assert!(reverse == 0, "Burned reverse not clear");
                fixture.mint(receiver, 2);
                fixture.mint(receiver, 3);
                start_cheat_caller_address(address, receiver);
                fixture.burn(2);
                assert!(
                    fixture.all_tokens(receiver) == array![3].span(),
                    "Stale reverse after reentrant burn",
                );
            }
        }
    }
}
