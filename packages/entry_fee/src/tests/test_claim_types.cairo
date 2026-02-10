use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use crate::models::{AdditionalShare, EntryFee, EntryFeeClaimType};

#[starknet::interface]
trait IEntryFeeMock<TContractState> {
    fn set_entry_fee(ref self: TContractState, context_id: u64, entry_fee: EntryFee);
    fn get_additional_shares(self: @TContractState, context_id: u64) -> Span<AdditionalShare>;
    fn is_claimed(self: @TContractState, context_id: u64, claim_type: EntryFeeClaimType) -> bool;
    fn set_claimed(ref self: TContractState, context_id: u64, claim_type: EntryFeeClaimType);
}

fn deploy_mock() -> IEntryFeeMockDispatcher {
    let contract_class = declare("EntryFeeMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).expect('deploy failed');
    IEntryFeeMockDispatcher { contract_address }
}

fn make_address(value: felt252) -> starknet::ContractAddress {
    value.try_into().unwrap()
}

fn setup_entry_fee_with_additional_shares(mock: IEntryFeeMockDispatcher) {
    let entry_fee = EntryFee {
        token_address: make_address(0x1234),
        amount: 1000,
        game_creator_share: Option::Some(500),
        refund_share: Option::Some(300),
        additional_shares: array![
            AdditionalShare { recipient: make_address(0xA1), share_bps: 100 },
            AdditionalShare { recipient: make_address(0xA2), share_bps: 100 },
        ]
            .span(),
    };
    mock.set_entry_fee(1, entry_fee);
}

// ============================================================================
// Refund claim tests
// ============================================================================

#[test]
fn test_is_claimed_refund_default_false() {
    let mock = deploy_mock();

    let result = mock.is_claimed(1, EntryFeeClaimType::Refund(42));
    assert!(!result, "refund should not be claimed by default");
}

#[test]
fn test_set_and_check_claimed_refund() {
    let mock = deploy_mock();

    let claim_type = EntryFeeClaimType::Refund(42);

    assert!(!mock.is_claimed(1, claim_type), "should start unclaimed");

    mock.set_claimed(1, claim_type);

    assert!(mock.is_claimed(1, claim_type), "should be claimed after set");
}

// ============================================================================
// AdditionalShare claim tests
// ============================================================================

#[test]
fn test_is_claimed_additional_share_default_false() {
    let mock = deploy_mock();
    setup_entry_fee_with_additional_shares(mock);

    let result = mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(0));
    assert!(!result, "additional share 0 should not be claimed by default");
}

#[test]
fn test_set_claimed_additional_share() {
    let mock = deploy_mock();
    setup_entry_fee_with_additional_shares(mock);

    assert!(!mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(0)), "should start unclaimed");

    mock.set_claimed(1, EntryFeeClaimType::AdditionalShare(0));

    assert!(
        mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(0)), "should be claimed after set",
    );
}

#[test]
fn test_set_claimed_additional_share_preserves_others() {
    let mock = deploy_mock();
    setup_entry_fee_with_additional_shares(mock);

    // Claim index 0
    mock.set_claimed(1, EntryFeeClaimType::AdditionalShare(0));

    // Verify index 0 is claimed
    assert!(mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(0)), "index 0 should be claimed");

    // Verify index 1 is still unclaimed
    assert!(
        !mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(1)),
        "index 1 should still be unclaimed",
    );
}

// ============================================================================
// GameCreator claim tests
// ============================================================================

#[test]
fn test_is_claimed_game_creator_default_false() {
    let mock = deploy_mock();
    setup_entry_fee_with_additional_shares(mock);

    let result = mock.is_claimed(1, EntryFeeClaimType::GameCreator);
    assert!(!result, "game creator should not be claimed by default");
}

#[test]
fn test_set_claimed_game_creator() {
    let mock = deploy_mock();
    setup_entry_fee_with_additional_shares(mock);

    mock.set_claimed(1, EntryFeeClaimType::GameCreator);

    assert!(mock.is_claimed(1, EntryFeeClaimType::GameCreator), "should be claimed");
}
