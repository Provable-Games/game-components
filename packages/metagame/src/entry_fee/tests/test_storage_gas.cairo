use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
/// Storage gas tests for PackedAdditionalShares
/// These tests measure actual storage gas by using a contract that embeds the component.
///
/// Gas Comparison Summary:
/// ----------------------
/// Before optimization: Each additional share stored individually
///   - 1 storage write per share_bps+claimed (15 bits wasted 237 bits per slot)
///   - Total for N shares: N storage writes
///
/// After optimization: Up to 16 shares packed per felt252 slot
///   - 1 storage write per 16 shares (240 bits used of 252)
///   - Total for N shares: ceil(N/16) storage writes
///
/// Storage Gas Savings:
///   - 4 shares: 4 writes -> 1 write = 75% reduction
///   - 8 shares: 8 writes -> 1 write = 87.5% reduction
///   - 16 shares: 16 writes -> 1 write = 93.75% reduction
///
/// Note: Recipients are still stored separately (ContractAddress = 251 bits, cannot pack)

use crate::entry_fee::structs::{AdditionalShare, EntryFee, EntryFeeClaimType, EntryFeeConfig};

#[starknet::interface]
trait IEntryFeeMock<TContractState> {
    fn set_entry_fee(ref self: TContractState, context_id: u64, entry_fee: EntryFee);
    fn get_entry_fee(self: @TContractState, context_id: u64) -> Option<EntryFeeConfig>;
    fn get_additional_shares(self: @TContractState, context_id: u64) -> Span<AdditionalShare>;
    fn is_claimed(self: @TContractState, context_id: u64, claim_type: EntryFeeClaimType) -> bool;
    fn set_claimed(ref self: TContractState, context_id: u64, claim_type: EntryFeeClaimType);
}

fn deploy_mock() -> IEntryFeeMockDispatcher {
    let contract_class = declare("EntryFeeMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).expect('deploy failed');
    IEntryFeeMockDispatcher { contract_address }
}

fn make_address(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn create_additional_shares(count: u32) -> Array<AdditionalShare> {
    let mut shares = ArrayTrait::new();
    let mut i: u32 = 0;
    while i < count {
        shares
            .append(
                AdditionalShare {
                    recipient: make_address((i + 100).into()),
                    share_bps: ((i + 1) * 100).try_into().unwrap(),
                },
            );
        i += 1;
    }
    shares
}

/// Test storage gas with 1 additional share
/// This is the baseline - minimal shares
#[test]
fn test_storage_gas_1_additional_share() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(1),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: create_additional_shares(1).span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );

    mock.set_entry_fee(1, entry_fee);

    // Verify data is stored correctly
    let shares = mock.get_additional_shares(1);
    assert!(shares.len() == 1, "should have 1 share");
    assert!(*shares.at(0).share_bps == 100, "share_bps mismatch");
}

/// Test storage gas with 4 additional shares
/// Before: 4 storage slots for shares
/// After: 1 storage slot for all 4 shares (packed)
#[test]
fn test_storage_gas_4_additional_shares() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(1),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: create_additional_shares(4).span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );

    mock.set_entry_fee(1, entry_fee);

    let shares = mock.get_additional_shares(1);
    assert!(shares.len() == 4, "should have 4 shares");
    assert!(*shares.at(0).share_bps == 100, "share 0 mismatch");
    assert!(*shares.at(3).share_bps == 400, "share 3 mismatch");
}

/// Test storage gas with 8 additional shares
/// Before: 8 storage slots for shares
/// After: 1 storage slot for all 8 shares (packed)
#[test]
fn test_storage_gas_8_additional_shares() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(1),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: create_additional_shares(8).span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );

    mock.set_entry_fee(1, entry_fee);

    let shares = mock.get_additional_shares(1);
    assert!(shares.len() == 8, "should have 8 shares");
    assert!(*shares.at(0).share_bps == 100, "share 0 mismatch");
    assert!(*shares.at(7).share_bps == 800, "share 7 mismatch");
}

/// Test storage gas with 16 additional shares (max per slot)
/// Before: 16 storage slots for shares
/// After: 1 storage slot for all 16 shares (packed)
/// This is the optimal case - maximum packing efficiency
#[test]
fn test_storage_gas_16_additional_shares() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(1),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: create_additional_shares(16).span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );

    mock.set_entry_fee(1, entry_fee);

    let shares = mock.get_additional_shares(1);
    assert!(shares.len() == 16, "should have 16 shares");
    assert!(*shares.at(0).share_bps == 100, "share 0 mismatch");
    assert!(*shares.at(15).share_bps == 1600, "share 15 mismatch");
}

/// Test claim status storage with packed shares
/// Verifies that setting claimed status works with packed storage
#[test]
fn test_storage_gas_claim_status() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(1),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: create_additional_shares(8).span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );

    mock.set_entry_fee(1, entry_fee);

    // Initially not claimed
    assert!(!mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(0)), "should not be claimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(7)), "should not be claimed");

    // Claim share 3
    mock.set_claimed(1, EntryFeeClaimType::AdditionalShare(3));

    // Verify only share 3 is claimed
    assert!(
        !mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(0)), "share 0 should not be claimed",
    );
    assert!(
        !mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(2)), "share 2 should not be claimed",
    );
    assert!(mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(3)), "share 3 should be claimed");
    assert!(
        !mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(4)), "share 4 should not be claimed",
    );
}

/// Test claiming multiple shares (measures read-modify-write gas)
#[test]
fn test_storage_gas_claim_multiple_shares() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(1),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: create_additional_shares(16).span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );

    mock.set_entry_fee(1, entry_fee);

    // Claim shares 0, 5, 10, 15 (spread across the packed slot)
    mock.set_claimed(1, EntryFeeClaimType::AdditionalShare(0));
    mock.set_claimed(1, EntryFeeClaimType::AdditionalShare(5));
    mock.set_claimed(1, EntryFeeClaimType::AdditionalShare(10));
    mock.set_claimed(1, EntryFeeClaimType::AdditionalShare(15));

    // Verify claimed status
    assert!(mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(0)), "share 0 should be claimed");
    assert!(
        !mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(1)), "share 1 should not be claimed",
    );
    assert!(mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(5)), "share 5 should be claimed");
    assert!(
        mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(10)), "share 10 should be claimed",
    );
    assert!(
        mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(15)), "share 15 should be claimed",
    );
}

// ============================================================================
// get_entry_fee roundtrip tests (covers _get_entry_fee with explicit unpack)
// ============================================================================

/// No entry fee set → get_entry_fee returns None
#[test]
fn test_get_entry_fee_none_when_unset() {
    let mock = deploy_mock();
    let result = mock.get_entry_fee(999);
    assert!(result.is_none(), "should be None when no entry fee set");
}

/// Full config roundtrip with game_creator_share and refund_share set
#[test]
fn test_get_entry_fee_roundtrip_with_shares() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0xABCD),
            amount: 500_000,
            game_creator_share: Option::Some(1000), // 10%
            refund_share: Option::Some(500), // 5%
            additional_shares: create_additional_shares(2).span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    let config = mock.get_entry_fee(1).expect('should be Some');
    assert!(config.amount == 500_000, "amount mismatch");
    assert!(config.game_creator_share == Option::Some(1000), "game_creator_share mismatch");
    assert!(config.refund_share == Option::Some(500), "refund_share mismatch");
    assert!(config.additional_shares.len() == 2, "additional_shares count mismatch");
}

/// Config with shares set to None (0 stored → None on read)
#[test]
fn test_get_entry_fee_roundtrip_no_shares() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    let config = mock.get_entry_fee(1).expect('should be Some');
    assert!(config.amount == 1000, "amount mismatch");
    assert!(config.game_creator_share.is_none(), "game_creator_share should be None");
    assert!(config.refund_share.is_none(), "refund_share should be None");
    assert!(config.additional_shares.len() == 0, "should have 0 additional shares");
}
