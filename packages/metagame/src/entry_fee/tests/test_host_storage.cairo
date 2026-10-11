use game_components_interfaces::entry_fee::{IEntryFeeDispatcher, IEntryFeeDispatcherTrait};
use game_components_interfaces::registration::Registration;
use game_components_utilities::distribution::structs::Distribution;
use metagame_extensions_interfaces::extension::ExtensionConfig;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::entry_fee::structs::{
    AdditionalShare, EntryFee, EntryFeeClaimType, EntryFeeConfig, EntryFeeDeposit,
};
use crate::registration::host_fixtures::{
    IHostRegistrationFeeDispatcher, IHostRegistrationFeeDispatcherTrait,
};
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
fn deploy(name: ByteArray) -> (IHostRegistrationFeeDispatcher, IEntryFeeDispatcher) {
    let (contract_address, _) = declare(name).unwrap().contract_class().deploy(@array![]).unwrap();
    (IHostRegistrationFeeDispatcher { contract_address }, IEntryFeeDispatcher { contract_address })
}
fn config() -> EntryFeeConfig {
    EntryFeeConfig {
        token_address: addr(0xabc),
        amount: 1000,
        game_creator_share: Option::Some(1000),
        refund_share: Option::Some(500),
        additional_shares: array![
            AdditionalShare { recipient: addr(11), share_bps: 300 },
            AdditionalShare { recipient: addr(12), share_bps: 200 },
        ]
            .span(),
        distribution: Option::Some(Distribution::Custom(array![4000, 6000].span())),
        distribution_count: 2,
    }
}
fn check_fee(name: ByteArray) {
    let (host, views) = deploy(name);
    assert!(views.get_entry_fee(1).is_none());
    assert!(host.get_entry_fee_extension_config(addr(1), 1).is_empty());
    let stored = host.set_entry_fee(1, EntryFee::Config(config())).unwrap();
    assert!(stored.amount == 1000);
    let read = views.get_entry_fee(1).unwrap();
    assert!(read.amount == 1000);
    assert!(read.game_creator_share == Option::Some(1000));
    assert!(read.refund_share == Option::Some(500));
    assert!(read.distribution_count == 2);
    assert!(host._get_entry_fee(1).unwrap().amount == 1000);
    assert!(*host._get_additional_shares(1).at(1).recipient == addr(12));
    assert!(*host._get_distribution_shares(1, 2).at(1) == 6000);
    assert!(host._get_custom_share_at(1, 1) == 4000);
    host.set_claimed(1, EntryFeeClaimType::GameCreator);
    host.set_claimed(1, EntryFeeClaimType::AdditionalShare(1));
    host.set_claimed(1, EntryFeeClaimType::Position(2));
    assert!(host.is_claimed(1, EntryFeeClaimType::GameCreator));
    assert!(host.is_claimed(1, EntryFeeClaimType::AdditionalShare(1)));
    assert!(!host.is_claimed(1, EntryFeeClaimType::AdditionalShare(0)));
    assert!(host.is_claimed(1, EntryFeeClaimType::Position(2)));
    assert!(!host.is_claimed(2, EntryFeeClaimType::Position(2)));
    assert!(views.get_entry_fee(1).unwrap().amount == 1000);
    assert!(host._get_custom_share_at(1, 2) == 6000);
    // Both token transfers and extension dispatch use the same shared internal API.
    mock_call(addr(0xabc), selector!("transfer_from"), true, 1);
    host.deposit_entry_fee(1, EntryFeeDeposit::Config(config()));
    mock_call(addr(0xabc), selector!("transfer"), true, 1);
    host.payout(addr(0xabc), addr(99), 100);
    host.payout(addr(0xabc), addr(99), 0);
    host._store_distribution_shares(2, array![1, 2, 3].span());
    assert!(*host._get_distribution_shares(2, 3).at(2) == 3);
}
#[test]
fn entry_fee_host_storage_roundtrip_and_claims() {
    check_fee("HostRegistrationFee");
}
#[test]
fn entry_fee_host_storage_component_adapter() {
    check_fee("AdapterRegistrationFee");
}
fn check_entry_fee_extensions(name: ByteArray) {
    let (host, views) = deploy(name);
    let ext = addr(0xeee);
    mock_call(ext, selector!("supports_interface"), true, 1);
    mock_call(ext, selector!("set_entry_fee_config"), (), 1);
    assert!(
        host
            .set_entry_fee(
                4, EntryFee::Extension(ExtensionConfig { address: ext, config: array![99].span() }),
            )
            .is_none(),
    );
    assert!(views.get_entry_fee(4).is_none());
    assert!(host.get_extension_address(4) == ext);
    mock_call(ext, selector!("get_config"), array![99].span(), 1);
    assert!(*host.get_entry_fee_extension_config(addr(1), 4).at(0) == 99);
    mock_call(ext, selector!("pay_entry_fee"), (), 1);
    host.deposit_entry_fee(4, EntryFeeDeposit::Extension(array![17].span()));
    mock_call(ext, selector!("payout_entry_fee"), (), 1);
    host.payout_entry_fee_extension(4, Option::Some(77), array![19].span());
}
#[test]
#[should_panic(expected: "EntryFee: Entry fee already set for context 1")]
fn entry_fee_host_storage_rejects_reconfiguration() {
    let (host, _) = deploy("HostRegistrationFee");
    let _ = host.set_entry_fee(1, EntryFee::Config(config()));
    let _ = host.set_entry_fee(1, EntryFee::Config(config()));
}
#[test]
#[should_panic(expected: "EntryFee: Extension address cannot be zero")]
fn entry_fee_host_storage_rejects_zero_extension() {
    let (host, _) = deploy("HostRegistrationFee");
    let _ = host
        .set_entry_fee(
            1, EntryFee::Extension(ExtensionConfig { address: addr(0), config: array![].span() }),
        );
}
#[test]
#[should_panic(expected: "EntryFee: ERC20 transfer_from failed")]
fn entry_fee_host_storage_rejects_failed_deposit() {
    let (host, _) = deploy("HostRegistrationFee");
    mock_call(addr(0xabc), selector!("transfer_from"), false, 1);
    host.deposit_entry_fee(1, EntryFeeDeposit::Config(config()));
}
// Matched benchmark operations: deployment, registration, submission and fee refund marking.
fn benchmark(name: ByteArray) {
    let (host, _) = deploy(name);
    host
        .set_entry(
            Registration {
                context_id: 1,
                entry_id: 1,
                game_token_id: 77,
                has_submitted: false,
                is_banned: false,
            },
        );
    host.mark_token_submitted(1, 77);
    host.set_claimed(1, EntryFeeClaimType::Refund(77));
}
#[test]
fn entry_fee_host_storage_gas_combined() {
    benchmark("HostRegistrationFee");
}
#[test]
fn entry_fee_host_storage_gas_separate() {
    benchmark("AdapterRegistrationFee");
}

#[test]
fn entry_fee_host_storage_extensions() {
    check_entry_fee_extensions("HostRegistrationFee");
}
#[test]
fn entry_fee_host_storage_extension_component_adapter() {
    check_entry_fee_extensions("AdapterRegistrationFee");
}

#[test]
fn entry_fee_host_storage_scalar_distribution_ranges() {
    let (host, views) = deploy("HostRegistrationFee");
    let distributions = array![
        Distribution::Linear(0xffff), Distribution::Exponential(0xffff), Distribution::Uniform,
        Distribution::Geometric((255, 254)),
        Distribution::Tiered(
            game_components_utilities::distribution::structs::TieredConfig {
                head_ratio: (255, 254), head_count: 255, head_share_bps: 9000,
            },
        ),
    ];
    let mut index = 0;
    while index < distributions.len() {
        let mut cfg = config();
        cfg.amount = 0xffffffffffffffffffffffffffffffff;
        cfg.distribution = Option::Some(*distributions.at(index));
        cfg.distribution_count = 0xffffffff;
        // This low-level setter is intentionally internal; hosts validate their supported terms.
        host._set_entry_fee_config((index + 1).into(), cfg);
        let actual = views.get_entry_fee((index + 1).into()).unwrap();
        assert!(actual.amount == 0xffffffffffffffffffffffffffffffff);
        assert!(actual.distribution_count == 0xffffffff);
        assert!(actual.distribution == Option::Some(*distributions.at(index)));
        index += 1;
    }
}
