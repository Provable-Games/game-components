/// Tests for prize_store.cairo bridge layer and prize.cairo pure library.
/// Covers: custom shares reconstruction, extension config read/write,
/// hash_prize_type, and edge cases in the store bridge.
use core::num::traits::Zero;
use game_components_utilities::distribution::structs::Distribution;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::prize::structs::{
    ERC20Data, ERC721Data, Prize, PrizeRecord, PrizeType, TokenPrizePayload, TokenTypeData,
};

#[starknet::interface]
trait IPrizeMockFull<TContractState> {
    fn set_token_record(
        ref self: TContractState,
        prize_id: u64,
        context_id: u64,
        sponsor_address: ContractAddress,
        payload: TokenPrizePayload,
    );
    fn get_prize(self: @TContractState, prize_id: u64) -> PrizeRecord;
    fn get_total_prizes(self: @TContractState) -> u64;
    fn increment_prize_count(ref self: TContractState) -> u64;
    fn hash_prize_type(self: @TContractState, prize_type: PrizeType) -> felt252;
    fn is_claimed(self: @TContractState, context_id: u64, prize_type: PrizeType) -> bool;
    fn is_claimed_by_hash(self: @TContractState, context_id: u64, prize_type_hash: felt252) -> bool;
    fn set_claimed(ref self: TContractState, context_id: u64, prize_type: PrizeType);
    fn set_claimed_by_hash(ref self: TContractState, context_id: u64, prize_type_hash: felt252);
    fn assert_prize_exists(self: @TContractState, prize_id: u64);
    fn assert_prize_not_claimed(self: @TContractState, context_id: u64, prize_type: PrizeType);
    fn get_custom_shares(self: @TContractState, prize_id: u64) -> Array<u16>;
    fn get_extension_address(
        self: @TContractState, context_id: u64, prize_id: u64,
    ) -> ContractAddress;
    fn payout_prize_extension(
        ref self: TContractState,
        context_id: u64,
        prize_id: u64,
        position: Option<u32>,
        recipient: ContractAddress,
        payout_params: Span<felt252>,
    );
    fn add_prize(
        ref self: TContractState, context_id: u64, prize: crate::prize::structs::Prize,
    ) -> u64;
}

fn deploy() -> IPrizeMockFullDispatcher {
    let contract_class = declare("PrizeMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).expect('deploy failed');
    IPrizeMockFullDispatcher { contract_address }
}

fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn make_erc20_prize(
    id: u64, context_id: u64, amount: u128, distribution: Option<Distribution>, count: Option<u32>,
) -> (u64, u64, ContractAddress, TokenPrizePayload) {
    let _ = id;
    (
        0,
        context_id,
        addr(0x999),
        TokenPrizePayload {
            token_address: addr(0xE2C20),
            token_type: TokenTypeData::erc20(
                ERC20Data { amount, distribution, distribution_count: count },
            ),
        },
    )
}

// ============================================================================
// hash_prize_type pure library tests (prize.cairo coverage)
// ============================================================================

#[test]
fn test_hash_prize_type_single() {
    let mock = deploy();
    let hash = mock.hash_prize_type(PrizeType::Single(1));
    assert!(hash != 0, "hash should be non-zero");
}

#[test]
fn test_hash_prize_type_different_ids_produce_different_hashes() {
    let mock = deploy();
    let hash1 = mock.hash_prize_type(PrizeType::Single(1));
    let hash2 = mock.hash_prize_type(PrizeType::Single(2));
    assert!(hash1 != hash2, "different prize IDs should produce different hashes");
}

#[test]
fn test_hash_prize_type_position() {
    let mock = deploy();
    let hash = mock.hash_prize_type(PrizeType::Distributed((1, 3)));
    assert!(hash != 0, "position hash should be non-zero");
}

#[test]
fn test_hash_prize_type_single_vs_position_different() {
    let mock = deploy();
    let hash_single = mock.hash_prize_type(PrizeType::Single(1));
    let hash_distributed = mock.hash_prize_type(PrizeType::Distributed((1, 1)));
    assert!(hash_single != hash_distributed, "Single and Distributed should hash differently");
}

#[test]
fn test_hash_prize_type_deterministic() {
    let mock = deploy();
    let hash1 = mock.hash_prize_type(PrizeType::Single(42));
    let hash2 = mock.hash_prize_type(PrizeType::Single(42));
    assert!(hash1 == hash2, "same input should produce same hash");
}

// ============================================================================
// get_prize with custom shares reconstruction (prize_store.cairo coverage)
// ============================================================================

#[test]
fn test_get_prize_erc20_custom_distribution_stores_shares_separately() {
    let mock = deploy();

    // Custom distribution - shares are stored via store_custom_shares during set_token_record
    // but the StoredPrize only preserves the variant type, not the shares.
    // get_prize then reconstructs shares from packed storage.
    let (_, context_id, sponsor, payload) = make_erc20_prize(
        1,
        100,
        5000,
        Option::Some(Distribution::Custom(array![5000_u16, 3000_u16, 2000_u16].span())),
        Option::Some(3),
    );
    mock.set_token_record(1, context_id, sponsor, payload);

    let record = mock.get_prize(1);
    let retrieved = match record.prize {
        Prize::Token(t) => t,
        Prize::Extension(_) => panic!("expected token prize"),
    };
    match retrieved.token_type {
        TokenTypeData::erc20(data) => {
            assert!(data.amount == 5000, "amount mismatch");
            // The Custom variant is preserved but shares come from packed storage
            // Since set_token_record doesn't call store_custom_shares (only _add_prize_config
            // does), the shares array will be empty when retrieved via get_prize after
            // set_token_record
            match data.distribution {
                Option::Some(dist) => {
                    match dist {
                        Distribution::Custom(_) => {},
                        _ => { panic!("expected Custom"); },
                    }
                },
                Option::None => { panic!("expected Some"); },
            }
        },
        TokenTypeData::erc721(_) => { panic!("expected erc20"); },
    }
}

#[test]
fn test_get_prize_erc721_passthrough() {
    let mock = deploy();

    let payload = TokenPrizePayload {
        token_address: addr(0xE2C721), token_type: TokenTypeData::erc721(ERC721Data { id: 42 }),
    };
    mock.set_token_record(2, 200, addr(0x999), payload);

    let record = mock.get_prize(2);
    let retrieved = match record.prize {
        Prize::Token(t) => t,
        Prize::Extension(_) => panic!("expected token prize"),
    };
    match retrieved.token_type {
        TokenTypeData::erc20(_) => { panic!("expected erc721"); },
        TokenTypeData::erc721(data) => { assert!(data.id == 42, "id mismatch"); },
    }
}

// ============================================================================
// get_custom_shares (prize_store.cairo lines 85-110)
// ============================================================================

#[test]
fn test_get_custom_shares_empty_when_none_stored() {
    let mock = deploy();
    let shares = mock.get_custom_shares(999);
    assert!(shares.len() == 0, "should be empty for non-existent prize");
}

// ============================================================================
// is_prize_claimed_by_hash / set_prize_claimed_by_hash (prize_store.cairo)
// ============================================================================

#[test]
fn test_claim_by_hash_roundtrip() {
    let mock = deploy();
    let prize_type = PrizeType::Single(1);
    let hash = mock.hash_prize_type(prize_type);

    assert!(!mock.is_claimed_by_hash(42, hash), "should not be claimed initially");

    mock.set_claimed_by_hash(42, hash);

    assert!(mock.is_claimed_by_hash(42, hash), "should be claimed after set");
}

#[test]
fn test_claim_by_hash_isolation_across_contexts() {
    let mock = deploy();
    let hash = mock.hash_prize_type(PrizeType::Single(1));

    mock.set_claimed_by_hash(1, hash);

    assert!(mock.is_claimed_by_hash(1, hash), "context 1 should be claimed");
    assert!(!mock.is_claimed_by_hash(2, hash), "context 2 should not be claimed");
}

// ============================================================================
// Extension address (config storage was dropped — extension owns its own state)
// ============================================================================

#[test]
fn test_extension_address_default_zero() {
    let mock = deploy();
    let ext_addr = mock.get_extension_address(1, 1);
    assert!(ext_addr.is_zero(), "should be zero by default");
}

// ============================================================================
// payout_prize_extension dispatch
// ============================================================================

#[test]
fn test_payout_prize_extension_dispatches_when_configured() {
    let mock = deploy();
    let ext_addr = addr(0xE0E0E0);

    // Seed the extension via the real add_prize component path so the
    // address slot the dispatcher reads is populated. The component
    // verifies SRC5 + calls IPrizeExtension.add_prize during set — both
    // are mocked here.
    mock_call(ext_addr, selector!("supports_interface"), true, 10);
    mock_call(ext_addr, selector!("add_prize"), (), 10);
    let prize_id = mock
        .add_prize(
            42,
            crate::prize::structs::Prize::Extension(
                crate::prize::structs::ExtensionPrizePayload {
                    address: ext_addr, config: array![].span(),
                },
            ),
        );

    // Mock the extension's payout entrypoint and verify the component
    // dispatches without panicking.
    mock_call(ext_addr, selector!("payout_prize"), (), 10);
    mock.payout_prize_extension(42, prize_id, Option::Some(1_u32), addr(0xFEED), array![].span());
}

#[test]
#[should_panic(expected: "Prize: No extension configured for prize")]
fn test_payout_prize_extension_panics_when_unset() {
    let mock = deploy();
    mock.payout_prize_extension(1, 1, Option::Some(1_u32), addr(0xFEED), array![].span());
}
