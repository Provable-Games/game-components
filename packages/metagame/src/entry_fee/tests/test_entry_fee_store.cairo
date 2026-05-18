/// Tests for the entry_fee_store.cairo bridge layer and entry_fee_component.cairo
/// store/extension paths that previously had 0% coverage.
///
/// Covers:
///   - get_entry_fee: full config roundtrip with game_creator_share and refund_share
///   - set_entry_fee_config / get_additional_shares: slot boundary crossing (>16 shares)
///   - is_entry_fee_set: true after set, false before (tested via set_entry_fee assertion)
///   - is_claimed / set_claimed: GameCreator, Refund, and AdditionalShare claim types
///   - store_extension_address / get_extension: via set_entry_fee Extension variant
///   - write_extension_config / read_extension_config: via mock helpers
///   - _set_extension: via set_entry_fee Extension variant with mock_call

use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::entry_fee::structs::{AdditionalShare, EntryFee, EntryFeeClaimType, EntryFeeConfig};

// ============================================================================
// Interface for the updated EntryFeeMock (includes extension helpers)
// ============================================================================

#[starknet::interface]
trait IEntryFeeMockFull<TContractState> {
    // Original functions
    fn set_entry_fee(ref self: TContractState, context_id: u64, entry_fee: EntryFee);
    fn get_entry_fee(self: @TContractState, context_id: u64) -> Option<EntryFeeConfig>;
    fn get_additional_shares(self: @TContractState, context_id: u64) -> Span<AdditionalShare>;
    fn is_claimed(self: @TContractState, context_id: u64, claim_type: EntryFeeClaimType) -> bool;
    fn set_claimed(ref self: TContractState, context_id: u64, claim_type: EntryFeeClaimType);
    // Extension functions
    fn read_extension_config(self: @TContractState, context_id: u64) -> Span<felt252>;
    fn write_extension_config(ref self: TContractState, context_id: u64, config: Span<felt252>);
    fn get_extension_address(self: @TContractState, context_id: u64) -> ContractAddress;
    fn claim_entry_fee_extension(
        ref self: TContractState, context_id: u64, claim_params: Span<felt252>,
    );
}

// ============================================================================
// Helpers
// ============================================================================

fn deploy_mock() -> IEntryFeeMockFullDispatcher {
    let contract_class = declare("EntryFeeMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).expect('deploy failed');
    IEntryFeeMockFullDispatcher { contract_address }
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

/// Helper to set up mock_call for an extension address so set_entry_fee(Extension) succeeds.
/// Mocks supports_interface to return true and set_entry_fee_config to return ().
fn mock_extension_calls(ext_addr: ContractAddress) {
    mock_call(ext_addr, selector!("supports_interface"), true, 10);
    mock_call(ext_addr, selector!("set_entry_fee_config"), (), 10);
}

// ============================================================================
// 1. is_entry_fee_set: tested via set_entry_fee assertion behavior
//    The set_entry_fee function calls is_entry_fee_set internally and panics
//    if already set. We verify: first call succeeds, second call panics.
// ============================================================================

#[test]
fn test_set_entry_fee_succeeds_when_not_set() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0xCAFE),
            amount: 5000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    // First call should succeed (is_entry_fee_set returns false)
    mock.set_entry_fee(1, entry_fee);

    // Verify config was stored
    let config = mock.get_entry_fee(1).expect('should be Some');
    assert!(config.amount == 5000, "amount mismatch");
}

#[test]
#[should_panic(expected: "EntryFee: Entry fee already set for context 1")]
fn test_set_entry_fee_panics_when_already_set() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0xCAFE),
            amount: 5000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    // Second call to same context should panic (is_entry_fee_set returns true)
    let entry_fee2 = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0xBEEF),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee2);
}

#[test]
fn test_set_entry_fee_different_contexts_succeed() {
    let mock = deploy_mock();

    let entry_fee1 = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 100,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee1);

    let entry_fee2 = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x2),
            amount: 200,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    // Different context should succeed (is_entry_fee_set returns false for context 2)
    mock.set_entry_fee(2, entry_fee2);

    let c1 = mock.get_entry_fee(1).expect('context 1 should be Some');
    let c2 = mock.get_entry_fee(2).expect('context 2 should be Some');
    assert!(c1.amount == 100, "context 1 amount mismatch");
    assert!(c2.amount == 200, "context 2 amount mismatch");
}

// ============================================================================
// 2. get_entry_fee with game_creator_share and refund_share both Some (non-zero)
// ============================================================================

#[test]
fn test_get_entry_fee_with_both_shares_nonzero() {
    let mock = deploy_mock();

    let shares = array![
        AdditionalShare { recipient: make_address(0xA1), share_bps: 200 },
        AdditionalShare { recipient: make_address(0xA2), share_bps: 300 },
    ];

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0xFEED),
            amount: 1_000_000,
            game_creator_share: Option::Some(1500), // 15%
            refund_share: Option::Some(750), // 7.5%
            additional_shares: shares.span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(42, entry_fee);

    let config = mock.get_entry_fee(42).expect('should be Some');
    assert!(config.token_address == make_address(0xFEED), "token_address mismatch");
    assert!(config.amount == 1_000_000, "amount mismatch");
    assert!(config.game_creator_share == Option::Some(1500), "game_creator_share mismatch");
    assert!(config.refund_share == Option::Some(750), "refund_share mismatch");
    assert!(config.additional_shares.len() == 2, "additional_shares count mismatch");
    assert!(
        *config.additional_shares.at(0).recipient == make_address(0xA1), "recipient 0 mismatch",
    );
    assert!(*config.additional_shares.at(0).share_bps == 200, "share_bps 0 mismatch");
    assert!(
        *config.additional_shares.at(1).recipient == make_address(0xA2), "recipient 1 mismatch",
    );
    assert!(*config.additional_shares.at(1).share_bps == 300, "share_bps 1 mismatch");
}

#[test]
fn test_get_entry_fee_none_when_token_zero() {
    let mock = deploy_mock();
    let result = mock.get_entry_fee(999);
    assert!(result.is_none(), "should be None when no entry fee set");
}

#[test]
fn test_get_entry_fee_no_additional_but_gc_and_refund() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0xABCD),
            amount: 250_000,
            game_creator_share: Option::Some(5000), // 50%
            refund_share: Option::Some(2500), // 25%
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(10, entry_fee);

    let config = mock.get_entry_fee(10).expect('should be Some');
    assert!(config.amount == 250_000, "amount mismatch");
    assert!(config.game_creator_share == Option::Some(5000), "game_creator_share mismatch");
    assert!(config.refund_share == Option::Some(2500), "refund_share mismatch");
    assert!(config.additional_shares.len() == 0, "should have 0 additional shares");
}

// ============================================================================
// 3. get_additional_shares crossing slot boundary (>16 shares)
// ============================================================================

#[test]
fn test_additional_shares_crossing_slot_boundary_17() {
    let mock = deploy_mock();

    let shares = create_additional_shares(17);
    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: shares.span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    let result = mock.get_additional_shares(1);
    assert!(result.len() == 17, "should have 17 shares");

    // Verify first slot shares (indices 0-15)
    assert!(*result.at(0).share_bps == 100, "share 0 mismatch");
    assert!(*result.at(0).recipient == make_address(100), "recipient 0 mismatch");
    assert!(*result.at(15).share_bps == 1600, "share 15 mismatch");
    assert!(*result.at(15).recipient == make_address(115), "recipient 15 mismatch");

    // Verify second slot share (index 16)
    assert!(*result.at(16).share_bps == 1700, "share 16 mismatch");
    assert!(*result.at(16).recipient == make_address(116), "recipient 16 mismatch");
}

#[test]
fn test_additional_shares_crossing_slot_boundary_20() {
    let mock = deploy_mock();

    let shares = create_additional_shares(20);
    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 500,
            game_creator_share: Option::Some(100),
            refund_share: Option::Some(50),
            additional_shares: shares.span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    let result = mock.get_additional_shares(1);
    assert!(result.len() == 20, "should have 20 shares");

    // Verify first slot boundary (index 15 = last of slot 0)
    assert!(*result.at(15).share_bps == 1600, "share 15 mismatch");
    // Verify second slot start (index 16 = first of slot 1)
    assert!(*result.at(16).share_bps == 1700, "share 16 mismatch");
    // Verify last share
    assert!(*result.at(19).share_bps == 2000, "share 19 mismatch");
    assert!(*result.at(19).recipient == make_address(119), "recipient 19 mismatch");
}

#[test]
fn test_additional_shares_crossing_slot_boundary_32() {
    let mock = deploy_mock();

    let shares = create_additional_shares(32);
    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: shares.span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    let result = mock.get_additional_shares(1);
    assert!(result.len() == 32, "should have 32 shares");

    // Verify slot 0 boundary (index 15)
    assert!(*result.at(15).share_bps == 1600, "share 15 mismatch");
    // Verify slot 1 start (index 16)
    assert!(*result.at(16).share_bps == 1700, "share 16 mismatch");
    // Verify slot 1 boundary (index 31)
    assert!(*result.at(31).share_bps == 3200, "share 31 mismatch");
    assert!(*result.at(31).recipient == make_address(131), "recipient 31 mismatch");
}

#[test]
fn test_get_entry_fee_with_cross_slot_shares() {
    let mock = deploy_mock();

    let shares = create_additional_shares(18);
    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0xABC),
            amount: 999_999,
            game_creator_share: Option::Some(2000),
            refund_share: Option::Some(1000),
            additional_shares: shares.span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(5, entry_fee);

    let config = mock.get_entry_fee(5).expect('should be Some');
    assert!(config.amount == 999_999, "amount mismatch");
    assert!(config.game_creator_share == Option::Some(2000), "game_creator_share mismatch");
    assert!(config.refund_share == Option::Some(1000), "refund_share mismatch");
    assert!(config.additional_shares.len() == 18, "additional_shares count mismatch");
    // Verify cross-slot share
    assert!(*config.additional_shares.at(17).share_bps == 1800, "share 17 mismatch");
}

// ============================================================================
// 4. GameCreator claim type
// ============================================================================

#[test]
fn test_game_creator_is_claimed_default_false() {
    let mock = deploy_mock();
    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 100,
            game_creator_share: Option::Some(500),
            refund_share: Option::None,
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    assert!(!mock.is_claimed(1, EntryFeeClaimType::GameCreator), "should not be claimed initially");
}

#[test]
fn test_game_creator_set_claimed() {
    let mock = deploy_mock();
    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 100,
            game_creator_share: Option::Some(500),
            refund_share: Option::None,
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    mock.set_claimed(1, EntryFeeClaimType::GameCreator);

    assert!(mock.is_claimed(1, EntryFeeClaimType::GameCreator), "should be claimed after set");
}

#[test]
fn test_game_creator_claim_preserves_other_data() {
    let mock = deploy_mock();
    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 50_000,
            game_creator_share: Option::Some(1000),
            refund_share: Option::Some(500),
            additional_shares: create_additional_shares(2).span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    mock.set_claimed(1, EntryFeeClaimType::GameCreator);

    // Verify claim
    assert!(mock.is_claimed(1, EntryFeeClaimType::GameCreator), "game creator should be claimed");

    // Verify the rest of the config is intact
    let config = mock.get_entry_fee(1).expect('should be Some');
    assert!(config.amount == 50_000, "amount should be preserved");
    assert!(config.game_creator_share == Option::Some(1000), "gc share should be preserved");
    assert!(config.refund_share == Option::Some(500), "refund share should be preserved");
    assert!(config.additional_shares.len() == 2, "additional shares should be preserved");
}

// ============================================================================
// 5. Refund claim type
// ============================================================================

#[test]
fn test_refund_is_claimed_default_false() {
    let mock = deploy_mock();

    assert!(
        !mock.is_claimed(1, EntryFeeClaimType::Refund(42)),
        "refund should not be claimed by default",
    );
}

#[test]
fn test_refund_set_claimed() {
    let mock = deploy_mock();

    mock.set_claimed(1, EntryFeeClaimType::Refund(42));

    assert!(
        mock.is_claimed(1, EntryFeeClaimType::Refund(42)), "refund should be claimed after set",
    );
}

#[test]
fn test_refund_claim_isolation_by_token_id() {
    let mock = deploy_mock();

    mock.set_claimed(1, EntryFeeClaimType::Refund(100));

    assert!(mock.is_claimed(1, EntryFeeClaimType::Refund(100)), "token 100 should be claimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::Refund(101)), "token 101 should not be claimed");
}

#[test]
fn test_refund_claim_isolation_by_context() {
    let mock = deploy_mock();

    mock.set_claimed(1, EntryFeeClaimType::Refund(42));

    assert!(mock.is_claimed(1, EntryFeeClaimType::Refund(42)), "context 1 should be claimed");
    assert!(
        !mock.is_claimed(2, EntryFeeClaimType::Refund(42)),
        "context 2 should not be claimed for same token_id",
    );
}

// ============================================================================
// 6. AdditionalShare claim type across slot boundary
// ============================================================================

#[test]
fn test_additional_share_claim_across_slots() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 1000,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: create_additional_shares(20).span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    // Claim share in slot 0 (index 5) and slot 1 (index 17)
    mock.set_claimed(1, EntryFeeClaimType::AdditionalShare(5));
    mock.set_claimed(1, EntryFeeClaimType::AdditionalShare(17));

    assert!(
        mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(5)),
        "share 5 (slot 0) should be claimed",
    );
    assert!(
        mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(17)),
        "share 17 (slot 1) should be claimed",
    );
    // Verify adjacent shares remain unclaimed
    assert!(
        !mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(4)), "share 4 should not be claimed",
    );
    assert!(
        !mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(6)), "share 6 should not be claimed",
    );
    assert!(
        !mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(16)),
        "share 16 should not be claimed",
    );
    assert!(
        !mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(18)),
        "share 18 should not be claimed",
    );
}

// ============================================================================
// 7. Extension storage via set_entry_fee(Extension) with mock_call
//    This exercises: _set_extension -> store_extension_address,
//    write_extension_config, and the IEntryFeeExtension dispatch.
//    Also exercises is_entry_fee_set returning true for extension.
// ============================================================================

#[test]
fn test_set_entry_fee_extension_stores_address_and_config() {
    let mock = deploy_mock();
    let ext_addr = make_address(0xDEAD);

    // Mock the extension contract's SRC5 and set_entry_fee_config calls
    mock_extension_calls(ext_addr);

    let config_data = array![0x111, 0x222, 0x333];
    let entry_fee = EntryFee::Extension(
        metagame_extensions_interfaces::extension::ExtensionConfig {
            address: ext_addr, config: config_data.span(),
        },
    );
    mock.set_entry_fee(1, entry_fee);

    // Verify extension address was stored via store_extension_address bridge
    let stored_addr = mock.get_extension_address(1);
    assert!(stored_addr == ext_addr, "extension address mismatch");

    // Verify extension config was written via write_extension_config bridge
    let stored_config = mock.read_extension_config(1);
    assert!(stored_config.len() == 3, "extension config should have 3 elements");
    assert!(*stored_config.at(0) == 0x111, "config element 0 mismatch");
    assert!(*stored_config.at(1) == 0x222, "config element 1 mismatch");
    assert!(*stored_config.at(2) == 0x333, "config element 2 mismatch");
}

#[test]
#[should_panic(expected: "EntryFee: Entry fee already set for context 1")]
fn test_set_entry_fee_extension_blocks_second_set() {
    let mock = deploy_mock();
    let ext_addr = make_address(0xDEAD);

    mock_extension_calls(ext_addr);

    let entry_fee = EntryFee::Extension(
        metagame_extensions_interfaces::extension::ExtensionConfig {
            address: ext_addr, config: array![0x1].span(),
        },
    );
    mock.set_entry_fee(1, entry_fee);

    // Second set should panic because is_entry_fee_set returns true (extension is set)
    let ext_addr2 = make_address(0xBEEF);
    mock_extension_calls(ext_addr2);

    let entry_fee2 = EntryFee::Extension(
        metagame_extensions_interfaces::extension::ExtensionConfig {
            address: ext_addr2, config: array![0x2].span(),
        },
    );
    mock.set_entry_fee(1, entry_fee2);
}

#[test]
fn test_set_entry_fee_extension_with_empty_config() {
    let mock = deploy_mock();
    let ext_addr = make_address(0xABCD);

    mock_extension_calls(ext_addr);

    let entry_fee = EntryFee::Extension(
        metagame_extensions_interfaces::extension::ExtensionConfig {
            address: ext_addr, config: array![].span(),
        },
    );
    mock.set_entry_fee(1, entry_fee);

    let stored_addr = mock.get_extension_address(1);
    assert!(stored_addr == ext_addr, "extension address mismatch");

    let stored_config = mock.read_extension_config(1);
    assert!(stored_config.len() == 0, "extension config should be empty");
}

#[test]
fn test_get_entry_fee_returns_none_for_extension_only() {
    let mock = deploy_mock();
    let ext_addr = make_address(0xDEAD);

    mock_extension_calls(ext_addr);

    let entry_fee = EntryFee::Extension(
        metagame_extensions_interfaces::extension::ExtensionConfig {
            address: ext_addr, config: array![0x1].span(),
        },
    );
    mock.set_entry_fee(1, entry_fee);

    // get_entry_fee checks token address, which is zero for extension-only entry fees
    let result = mock.get_entry_fee(1);
    assert!(result.is_none(), "should be None for extension-only entry fee (no token)");
}

// ============================================================================
// 8. Extension read/write directly via mock helpers
//    Exercises read_extension_config and write_extension_config bridge paths.
// ============================================================================

#[test]
fn test_extension_config_empty_by_default() {
    let mock = deploy_mock();
    let config = mock.read_extension_config(1);
    assert!(config.len() == 0, "extension config should be empty by default");
}

#[test]
fn test_write_and_read_extension_config_single_element() {
    let mock = deploy_mock();

    let config = array![0x12345].span();
    mock.write_extension_config(1, config);

    let result = mock.read_extension_config(1);
    assert!(result.len() == 1, "should have 1 element");
    assert!(*result.at(0) == 0x12345, "element 0 mismatch");
}

#[test]
fn test_write_and_read_extension_config_multiple_elements() {
    let mock = deploy_mock();

    let config = array![0x111, 0x222, 0x333, 0x444, 0x555].span();
    mock.write_extension_config(1, config);

    let result = mock.read_extension_config(1);
    assert!(result.len() == 5, "should have 5 elements");
    assert!(*result.at(0) == 0x111, "element 0 mismatch");
    assert!(*result.at(1) == 0x222, "element 1 mismatch");
    assert!(*result.at(2) == 0x333, "element 2 mismatch");
    assert!(*result.at(3) == 0x444, "element 3 mismatch");
    assert!(*result.at(4) == 0x555, "element 4 mismatch");
}

#[test]
fn test_extension_config_isolation_by_context() {
    let mock = deploy_mock();

    mock.write_extension_config(1, array![0xAAA, 0xBBB].span());
    mock.write_extension_config(2, array![0xCCC].span());

    let config1 = mock.read_extension_config(1);
    let config2 = mock.read_extension_config(2);
    let config3 = mock.read_extension_config(3);

    assert!(config1.len() == 2, "context 1 should have 2 elements");
    assert!(*config1.at(0) == 0xAAA, "context 1 element 0 mismatch");
    assert!(*config1.at(1) == 0xBBB, "context 1 element 1 mismatch");

    assert!(config2.len() == 1, "context 2 should have 1 element");
    assert!(*config2.at(0) == 0xCCC, "context 2 element 0 mismatch");

    assert!(config3.len() == 0, "context 3 should be empty");
}

#[test]
fn test_write_extension_config_empty_span() {
    let mock = deploy_mock();

    mock.write_extension_config(1, array![].span());

    let result = mock.read_extension_config(1);
    assert!(result.len() == 0, "writing empty span should result in empty config");
}

// ============================================================================
// 9. Extension address via get_extension_address
// ============================================================================

#[test]
fn test_extension_address_default_zero() {
    let mock = deploy_mock();
    let addr = mock.get_extension_address(1);
    let zero: ContractAddress = 0.try_into().unwrap();
    assert!(addr == zero, "extension address should be zero by default");
}

#[test]
fn test_extension_address_isolation_by_context() {
    let mock = deploy_mock();
    let ext_addr1 = make_address(0xAAA);
    let ext_addr2 = make_address(0xBBB);

    // Set extensions on two different contexts
    mock_extension_calls(ext_addr1);
    let entry_fee1 = EntryFee::Extension(
        metagame_extensions_interfaces::extension::ExtensionConfig {
            address: ext_addr1, config: array![].span(),
        },
    );
    mock.set_entry_fee(1, entry_fee1);

    mock_extension_calls(ext_addr2);
    let entry_fee2 = EntryFee::Extension(
        metagame_extensions_interfaces::extension::ExtensionConfig {
            address: ext_addr2, config: array![].span(),
        },
    );
    mock.set_entry_fee(2, entry_fee2);

    assert!(mock.get_extension_address(1) == ext_addr1, "context 1 extension mismatch");
    assert!(mock.get_extension_address(2) == ext_addr2, "context 2 extension mismatch");
    let zero: ContractAddress = 0.try_into().unwrap();
    assert!(mock.get_extension_address(3) == zero, "context 3 should be zero");
}

// ============================================================================
// 10. Multiple claim types on the same context
// ============================================================================

#[test]
fn test_mixed_claim_types_on_same_context() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 1000,
            game_creator_share: Option::Some(500),
            refund_share: Option::Some(300),
            additional_shares: create_additional_shares(3).span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    // All unclaimed initially
    assert!(!mock.is_claimed(1, EntryFeeClaimType::GameCreator), "gc unclaimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::Refund(1)), "refund unclaimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(0)), "share 0 unclaimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(1)), "share 1 unclaimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(2)), "share 2 unclaimed");

    // Claim game creator
    mock.set_claimed(1, EntryFeeClaimType::GameCreator);
    assert!(mock.is_claimed(1, EntryFeeClaimType::GameCreator), "gc should be claimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::Refund(1)), "refund still unclaimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(0)), "share 0 still unclaimed");

    // Claim refund for token_id 1
    mock.set_claimed(1, EntryFeeClaimType::Refund(1));
    assert!(mock.is_claimed(1, EntryFeeClaimType::Refund(1)), "refund 1 should be claimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::Refund(2)), "refund 2 still unclaimed");

    // Claim additional share 1
    mock.set_claimed(1, EntryFeeClaimType::AdditionalShare(1));
    assert!(mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(1)), "share 1 should be claimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(0)), "share 0 still unclaimed");
    assert!(!mock.is_claimed(1, EntryFeeClaimType::AdditionalShare(2)), "share 2 still unclaimed");
}

// ============================================================================
// 11. get_additional_shares returns empty when count is 0
// ============================================================================

#[test]
fn test_get_additional_shares_empty() {
    let mock = deploy_mock();

    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 100,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    let result = mock.get_additional_shares(1);
    assert!(result.len() == 0, "should return empty when no additional shares");
}

// ============================================================================
// 12. Exactly 16 shares (single full slot boundary)
// ============================================================================

#[test]
fn test_exactly_16_shares_full_slot() {
    let mock = deploy_mock();

    let shares = create_additional_shares(16);
    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0x1),
            amount: 1000,
            game_creator_share: Option::Some(1000),
            refund_share: Option::Some(500),
            additional_shares: shares.span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);

    let config = mock.get_entry_fee(1).expect('should be Some');
    assert!(config.additional_shares.len() == 16, "should have exactly 16 shares");
    assert!(config.game_creator_share == Option::Some(1000), "gc share mismatch");
    assert!(config.refund_share == Option::Some(500), "refund share mismatch");

    // Verify all 16 shares
    let mut i: u32 = 0;
    while i < 16 {
        let share = *config.additional_shares.at(i);
        let expected_bps: u16 = ((i + 1) * 100).try_into().unwrap();
        assert!(share.share_bps == expected_bps, "share_bps mismatch");
        assert!(share.recipient == make_address((i + 100).into()), "recipient mismatch");
        i += 1;
    };
}

// ============================================================================
// 13. Extension address and config together via mock helpers
// ============================================================================

#[test]
fn test_extension_address_and_config_together() {
    let mock = deploy_mock();
    let ext_addr = make_address(0xE0E0E0);

    mock_extension_calls(ext_addr);

    let config_data = array![0x42, 0x84, 0xFF];
    let entry_fee = EntryFee::Extension(
        metagame_extensions_interfaces::extension::ExtensionConfig {
            address: ext_addr, config: config_data.span(),
        },
    );
    mock.set_entry_fee(1, entry_fee);

    // Verify address via get_extension bridge
    assert!(mock.get_extension_address(1) == ext_addr, "extension address mismatch");

    // Verify config via read_extension_config bridge
    let config = mock.read_extension_config(1);
    assert!(config.len() == 3, "config should have 3 elements");
    assert!(*config.at(0) == 0x42, "config element 0 mismatch");
    assert!(*config.at(1) == 0x84, "config element 1 mismatch");
    assert!(*config.at(2) == 0xFF, "config element 2 mismatch");
}

// ============================================================================
// 14. claim_entry_fee_extension dispatch
// ============================================================================

#[test]
fn test_claim_entry_fee_extension_dispatches_when_configured() {
    let mock = deploy_mock();
    let ext_addr = make_address(0xE0E0E0);

    mock_extension_calls(ext_addr);
    // Mock the extension claim method — return value is `()`.
    mock_call(ext_addr, selector!("claim_entry_fee"), (), 10);

    let entry_fee = EntryFee::Extension(
        metagame_extensions_interfaces::extension::ExtensionConfig {
            address: ext_addr, config: array![].span(),
        },
    );
    mock.set_entry_fee(7, entry_fee);

    // Should not panic — the dispatch goes through to the mocked extension.
    mock.claim_entry_fee_extension(7, array![0xAA].span());
}

#[test]
#[should_panic(expected: "EntryFee: No extension configured")]
fn test_claim_entry_fee_extension_panics_when_unset() {
    let mock = deploy_mock();
    // No set_entry_fee call — extension address is zero.
    mock.claim_entry_fee_extension(99, array![].span());
}

#[test]
#[should_panic(expected: "EntryFee: No extension configured")]
fn test_claim_entry_fee_extension_panics_when_builtin() {
    let mock = deploy_mock();
    let entry_fee = EntryFee::Config(
        EntryFeeConfig {
            token_address: make_address(0xCAFE),
            amount: 100,
            game_creator_share: Option::None,
            refund_share: Option::None,
            additional_shares: array![].span(),
            distribution: Option::None,
            distribution_count: 0,
        },
    );
    mock.set_entry_fee(1, entry_fee);
    // Built-in path stores no extension address — should panic.
    mock.claim_entry_fee_extension(1, array![].span());
}
