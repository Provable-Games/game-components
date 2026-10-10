use core::num::traits::Zero;
use game_components_interfaces::prize::{IPrizeDispatcher, IPrizeDispatcherTrait};
use game_components_utilities::distribution::structs::Distribution;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::prize::structs::{
    ERC20Data, ERC721Data, ExtensionPrizePayload, Prize, PrizeType, TokenPrizePayload,
    TokenTypeData,
};
use super::host_fixtures::{HostPrize, IHostPrizeDispatcher, IHostPrizeDispatcherTrait};
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
fn deploy(name: ByteArray) -> (IHostPrizeDispatcher, IPrizeDispatcher) {
    let (contract_address, _) = declare(name).unwrap().contract_class().deploy(@array![]).unwrap();
    (IHostPrizeDispatcher { contract_address }, IPrizeDispatcher { contract_address })
}
fn payload() -> TokenPrizePayload {
    TokenPrizePayload {
        token_address: addr(0xabc),
        token_type: TokenTypeData::erc20(
            ERC20Data {
                amount: 1234,
                distribution: Option::Some(Distribution::Custom(array![2500, 7500].span())),
                distribution_count: Option::Some(2),
            },
        ),
    }
}
fn check_prize(name: ByteArray) {
    let (host, views) = deploy(name);
    assert!(views.get_total_prizes() == 0);
    mock_call(addr(0xabc), selector!("transfer_from"), true, 1);
    let id = host.add_prize(1, Prize::Token(payload()));
    assert!(id == 1);
    assert!(host._get_total_prizes() == 1);
    let record = views.get_prize(id);
    assert!(record.context_id == 1);
    assert!(host._get_prize(id).context_id == 1);
    assert!(*host._get_custom_shares(id).at(1) == 7500);
    assert!(host._get_custom_share_at(id, 1) == 2500);
    host.assert_prize_exists(id);
    host.assert_prize_not_claimed(1, PrizeType::Distributed((id, 1)));
    let hash = host.hash_prize_type(PrizeType::Distributed((id, 1)));
    host._assert_prize_not_claimed_by_hash(1, hash);
    host._set_prize_claimed_by_hash(1, hash);
    assert!(host._is_prize_claimed_by_hash(1, hash));
    assert!(host._is_prize_claimed(1, PrizeType::Distributed((id, 1))));
    assert!(views.is_prize_claimed(1, PrizeType::Distributed((id, 1))));
    assert!(!views.is_prize_claimed(2, PrizeType::Distributed((id, 1))));
    assert!(!views.is_prize_claimed(1, PrizeType::Distributed((id, 2))));
    host.set_prize_claimed(1, PrizeType::Distributed((id, 2)));
    host.set_payout_position(id, 12);
    assert!(host.get_payout_position(id) == 12);
    assert!(*host._get_custom_shares(id).at(1) == 7500);
    assert!(host.get_extension_address(1, id).is_zero());
    mock_call(addr(0xabc), selector!("transfer"), true, 2);
    host.payout_erc20(addr(0xabc), 100, addr(88));
    host.refund_prize_erc20(id, 200);
    let next = host.increment_prize_count();
    host
        .set_token_record(
            next,
            2,
            addr(99),
            TokenPrizePayload {
                token_address: addr(0xcba),
                token_type: TokenTypeData::erc721(ERC721Data { id: 55 }),
            },
        );
    assert!(views.get_prize(next).context_id == 2);
    mock_call(addr(0xcba), selector!("transfer_from"), (), 2);
    host.payout_erc721(addr(0xcba), 55, addr(88));
    host.refund_prize_erc721(next, 55);
}
#[test]
fn prize_host_storage_roundtrip_and_claims() {
    check_prize("HostPrize");
}
#[test]
fn prize_host_storage_component_adapter() {
    check_prize("AdapterPrize");
}
fn check_prize_extensions(name: ByteArray) {
    let (host, views) = deploy(name);
    let ext = addr(0xeee);
    mock_call(ext, selector!("supports_interface"), true, 1);
    mock_call(ext, selector!("add_prize"), (), 1);
    let id = host
        .add_prize(
            0xffffffffffffffff,
            Prize::Extension(ExtensionPrizePayload { address: ext, config: array![99].span() }),
        );
    host.set_payout_position(id, 0xffffffff);
    mock_call(ext, selector!("get_config"), array![99].span(), 1);
    let record = views.get_prize(id);
    assert!(record.context_id == 0xffffffffffffffff);
    assert!(host.get_payout_position(id) == 0xffffffff);
    assert!(host.get_extension_address(0xffffffffffffffff, id) == ext);
    let config = match record.prize {
        Prize::Extension(payload) => payload.config,
        _ => panic!("expected extension"),
    };
    assert!(*config.at(0) == 99);
    mock_call(ext, selector!("payout_prize"), (), 1);
    host.payout_prize_extension(0xffffffffffffffff, id, Option::Some(77), array![18].span());
}
#[test]
#[should_panic(expected: "Prize: Extension address cannot be zero")]
fn prize_host_storage_rejects_zero_extension() {
    let (host, _) = deploy("HostPrize");
    let _ = host
        .add_prize(
            1,
            Prize::Extension(ExtensionPrizePayload { address: addr(0), config: array![].span() }),
        );
}
#[test]
#[should_panic(expected: "Prize: ERC20 transfer_from failed")]
fn prize_host_storage_rejects_failed_deposit() {
    let (host, _) = deploy("HostPrize");
    mock_call(addr(0xabc), selector!("transfer_from"), false, 1);
    let _ = host.add_prize(1, Prize::Token(payload()));
}

#[test]
#[fuzzer(runs: 64)]
fn prize_host_storage_metadata_updates_preserve_other_fields(
    context: u64, count: u32, position: u32,
) {
    let mut state = HostPrize::contract_state_for_testing();
    HostPrize::PrizeHostStore::set_extension_prize_context(ref state, 1, context);
    HostPrize::PrizeHostStore::set_custom_shares_count(ref state, 1, count);
    HostPrize::PrizeHostStore::set_payout_position(ref state, 1, position);
    assert!(HostPrize::PrizeHostStore::get_extension_prize_context(@state, 1) == context);
    assert!(HostPrize::PrizeHostStore::get_custom_shares_count(@state, 1) == count);
    assert!(HostPrize::PrizeHostStore::get_payout_position(@state, 1) == position);
    HostPrize::PrizeHostStore::set_extension_prize_context(ref state, 1, 0);
    assert!(HostPrize::PrizeHostStore::get_custom_shares_count(@state, 1) == count);
    assert!(HostPrize::PrizeHostStore::get_payout_position(@state, 1) == position);
    HostPrize::PrizeHostStore::set_custom_shares_count(ref state, 1, 0);
    assert!(HostPrize::PrizeHostStore::get_payout_position(@state, 1) == position);
    HostPrize::PrizeHostStore::set_payout_position(ref state, 1, 0);
    assert!(HostPrize::PrizeHostStore::get_extension_prize_context(@state, 1) == 0);
    assert!(HostPrize::PrizeHostStore::get_custom_shares_count(@state, 1) == 0);
    assert!(HostPrize::PrizeHostStore::get_payout_position(@state, 1) == 0);
}

#[test]
fn prize_host_storage_extensions_and_packed_metadata() {
    check_prize_extensions("HostPrize");
}
#[test]
fn prize_host_storage_extension_component_adapter() {
    check_prize_extensions("AdapterPrize");
}
