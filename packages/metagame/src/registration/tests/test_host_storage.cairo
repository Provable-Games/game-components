use game_components_interfaces::registration::{
    IRegistrationDispatcher, IRegistrationDispatcherTrait, Registration,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use crate::entry_fee::structs::EntryFeeClaimType;
use super::host_fixtures::{
    HostRegistrationFee, IHostRegistrationFeeDispatcher, IHostRegistrationFeeDispatcherTrait,
};

fn deploy(name: ByteArray) -> (IHostRegistrationFeeDispatcher, IRegistrationDispatcher) {
    let (contract_address, _) = declare(name).unwrap().contract_class().deploy(@array![]).unwrap();
    (
        IHostRegistrationFeeDispatcher { contract_address },
        IRegistrationDispatcher { contract_address },
    )
}
fn check_registration(name: ByteArray) {
    let (host, views) = deploy(name);
    assert!(views.get_entry_count(1) == 0);
    assert!(!views.entry_exists(1, 1));
    assert!(host._get_token_context(1, 77) == 0);
    assert!(host.increment_entry_count(1) == 1);
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
    assert!(views.entry_exists(1, 1));
    assert!(host._get_entry_count(1) == 1);
    assert!(host._entry_exists(1, 1));
    assert!(host._get_entry(1, 1).game_token_id == 77);
    assert!(host._get_token_context(1, 77) == 1);
    assert!(host._get_token_context(2, 77) == 0);
    host.assert_valid_for_submission(views.get_entry(1, 1), 1);
    host.mark_token_submitted(1, 77);
    host.set_claimed(1, EntryFeeClaimType::Refund(77));
    host.ban_token(1, 77);
    assert!(host._is_token_submitted(1, 77));
    assert!(host._is_token_banned(1, 77));
    assert!(views.is_token_banned(1, 77));
    assert!(host.is_claimed(1, EntryFeeClaimType::Refund(77)));
    // The refund bit belongs to fee accounting, even if registration overwrites the slot.
    host
        .set_entry(
            Registration {
                context_id: 1,
                entry_id: 1,
                game_token_id: 88,
                has_submitted: false,
                is_banned: false,
            },
        );
    assert!(host._get_token_context(1, 77) == 0);
    assert!(!host._is_token_submitted(1, 77));
    assert!(!host._is_token_banned(1, 77));
    assert!(host.is_claimed(1, EntryFeeClaimType::Refund(77)));
    assert!(!host.is_claimed(1, EntryFeeClaimType::Refund(88)));
    assert!(!host.is_claimed(2, EntryFeeClaimType::Refund(77)));
    host
        .set_entry(
            Registration {
                context_id: 2, entry_id: 1, game_token_id: 88, has_submitted: true, is_banned: true,
            },
        );
    assert!(!views.get_entry(1, 1).is_banned);
    assert!(views.get_entry(2, 1).is_banned);
}
#[test]
fn registration_host_storage_preserves_refunds_and_contexts() {
    check_registration("HostRegistrationFee");
}
#[test]
fn registration_host_storage_component_adapter() {
    check_registration("AdapterRegistrationFee");
}
#[test]
#[fuzzer(runs: 64)]
fn registration_host_storage_combined_flags(
    context: u64, submitted: bool, banned: bool, refunded: bool,
) {
    let id = if context == 0 {
        1
    } else {
        context
    };
    let (host, views) = deploy("HostRegistrationFee");
    if refunded {
        host.set_claimed(id, EntryFeeClaimType::Refund(11));
    }
    host
        .set_entry(
            Registration {
                context_id: id,
                entry_id: 1,
                game_token_id: 11,
                has_submitted: submitted,
                is_banned: banned,
            },
        );
    let entry = views.get_entry(id, 1);
    assert!(entry.context_id == id);
    assert!(entry.has_submitted == submitted);
    assert!(entry.is_banned == banned);
    assert!(host.is_claimed(id, EntryFeeClaimType::Refund(11)) == refunded);
    host.mark_token_submitted(id, 11);
    host.ban_token(id, 11);
    assert!(host.is_claimed(id, EntryFeeClaimType::Refund(11)) == refunded);
    assert!(views.get_entry(id, 1).has_submitted);
    assert!(views.get_entry(id, 1).is_banned);
}
#[test]
#[should_panic(expected: ('Invalid token id', 'ENTRYPOINT_FAILED'))]
fn registration_host_storage_rejects_zero_token() {
    let (host, _) = deploy("HostRegistrationFee");
    host
        .set_entry(
            Registration {
                context_id: 1,
                entry_id: 1,
                game_token_id: 0,
                has_submitted: false,
                is_banned: false,
            },
        );
}

#[test]
fn registration_host_storage_clearing_refund_preserves_registration() {
    let mut state = HostRegistrationFee::contract_state_for_testing();
    HostRegistrationFee::RegistrationHostStore::set_token_state_raw(
        ref state, 1, 77, 0x30000000000000001,
    );
    HostRegistrationFee::EntryFeeHostStore::set_refund_claimed(ref state, 1, 77, true);
    assert!(
        HostRegistrationFee::RegistrationHostStore::get_token_state_raw(
            @state, 1, 77,
        ) == 0x30000000000000001,
    );
    HostRegistrationFee::EntryFeeHostStore::set_refund_claimed(ref state, 1, 77, false);
    assert!(
        HostRegistrationFee::RegistrationHostStore::get_token_state_raw(
            @state, 1, 77,
        ) == 0x30000000000000001,
    );
    assert!(!HostRegistrationFee::EntryFeeHostStore::get_refund_claimed(@state, 1, 77));
}
