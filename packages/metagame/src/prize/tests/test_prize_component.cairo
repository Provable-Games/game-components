use game_components_utilities::distribution::structs::Distribution;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use crate::prize::structs::{ERC20Data, ERC721Data, Prize, PrizeType, TokenPrize, TokenTypeData};

#[starknet::interface]
trait IPrizeMockExtended<TContractState> {
    // Existing mock functions
    fn hash_prize_type(self: @TContractState, prize_type: PrizeType) -> felt252;
    fn is_claimed(self: @TContractState, context_id: u64, prize_type: PrizeType) -> bool;
    fn set_claimed(ref self: TContractState, context_id: u64, prize_type: PrizeType);
    // New mock functions for component testing
    fn set_token_prize(ref self: TContractState, prize_id: u64, prize: TokenPrize);
    fn get_prize(self: @TContractState, prize_id: u64) -> Prize;
    fn get_total_prizes(self: @TContractState) -> u64;
    fn increment_prize_count(ref self: TContractState) -> u64;
    fn assert_prize_exists(self: @TContractState, prize_id: u64);
    fn assert_prize_not_claimed(self: @TContractState, context_id: u64, prize_type: PrizeType);
    // Embeddable IPrize method
    fn is_prize_claimed(self: @TContractState, context_id: u64, prize_type: PrizeType) -> bool;
}

fn deploy_prize_mock() -> IPrizeMockExtendedDispatcher {
    let contract_class = declare("PrizeMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).expect('deploy failed');
    IPrizeMockExtendedDispatcher { contract_address }
}

fn make_erc20_prize(
    id: u64, context_id: u64, amount: u128, distribution: Option<Distribution>, count: Option<u32>,
) -> TokenPrize {
    TokenPrize {
        id,
        context_id,
        token_address: core::traits::TryInto::try_into(0xE2C20).unwrap(),
        token_type: TokenTypeData::erc20(
            ERC20Data { amount, distribution, distribution_count: count },
        ),
        sponsor_address: core::traits::TryInto::try_into(0x999).unwrap(),
    }
}

fn make_erc721_prize(id: u64, context_id: u64, token_id: u128) -> TokenPrize {
    TokenPrize {
        id,
        context_id,
        token_address: core::traits::TryInto::try_into(0xE2C721).unwrap(),
        token_type: TokenTypeData::erc721(ERC721Data { id: token_id }),
        sponsor_address: core::traits::TryInto::try_into(0x999).unwrap(),
    }
}

// ============================================================================
// set_token_prize / get_prize roundtrip tests
// ============================================================================

#[test]
fn test_set_and_get_prize_erc20_no_distribution() {
    let mock = deploy_prize_mock();

    let prize = make_erc20_prize(1, 100, 5000, Option::None, Option::None);
    mock.set_token_prize(1, prize);

    let retrieved = match mock.get_prize(1) {
        Prize::Token(t) => t,
        Prize::Extension(_) => panic!("expected token prize"),
    };
    assert!(retrieved.context_id == 100, "context_id mismatch");

    match retrieved.token_type {
        TokenTypeData::erc20(data) => {
            assert!(data.amount == 5000, "amount mismatch");
            assert!(data.distribution.is_none(), "should be None");
        },
        TokenTypeData::erc721(_) => { panic!("expected erc20"); },
    }
}

#[test]
fn test_set_and_get_prize_erc20_linear() {
    let mock = deploy_prize_mock();

    let prize = make_erc20_prize(
        1, 200, 10000, Option::Some(Distribution::Linear(25)), Option::Some(5),
    );
    mock.set_token_prize(1, prize);

    let retrieved = match mock.get_prize(1) {
        Prize::Token(t) => t,
        Prize::Extension(_) => panic!("expected token prize"),
    };

    match retrieved.token_type {
        TokenTypeData::erc20(data) => {
            assert!(data.amount == 10000, "amount mismatch");
            match data.distribution {
                Option::Some(dist) => {
                    match dist {
                        Distribution::Linear(w) => { assert!(w == 25, "weight mismatch"); },
                        _ => { panic!("expected Linear"); },
                    }
                },
                Option::None => { panic!("expected Some"); },
            }
            assert!(data.distribution_count == Option::Some(5), "count mismatch");
        },
        TokenTypeData::erc721(_) => { panic!("expected erc20"); },
    }
}

#[test]
fn test_set_and_get_prize_erc721() {
    let mock = deploy_prize_mock();

    let prize = make_erc721_prize(1, 300, 42);
    mock.set_token_prize(1, prize);

    let retrieved = match mock.get_prize(1) {
        Prize::Token(t) => t,
        Prize::Extension(_) => panic!("expected token prize"),
    };
    assert!(retrieved.context_id == 300, "context_id mismatch");

    match retrieved.token_type {
        TokenTypeData::erc20(_) => { panic!("expected erc721"); },
        TokenTypeData::erc721(data) => { assert!(data.id == 42, "token_id mismatch"); },
    }
}

// ============================================================================
// increment_prize_count tests
// ============================================================================

#[test]
fn test_increment_prize_count() {
    let mock = deploy_prize_mock();

    assert!(mock.get_total_prizes() == 0, "initial should be 0");

    let id1 = mock.increment_prize_count();
    assert!(id1 == 1, "first increment should return 1");

    let id2 = mock.increment_prize_count();
    assert!(id2 == 2, "second increment should return 2");

    let id3 = mock.increment_prize_count();
    assert!(id3 == 3, "third increment should return 3");

    assert!(mock.get_total_prizes() == 3, "total should be 3");
}

// ============================================================================
// assert_prize_exists tests
// ============================================================================

#[test]
#[should_panic]
fn test_assert_prize_exists_fails_for_missing() {
    let mock = deploy_prize_mock();
    mock.assert_prize_exists(99);
}

#[test]
fn test_assert_prize_exists_succeeds_for_stored() {
    let mock = deploy_prize_mock();

    let prize = make_erc20_prize(1, 100, 5000, Option::None, Option::None);
    mock.set_token_prize(1, prize);

    // Should not panic
    mock.assert_prize_exists(1);
}

// ============================================================================
// assert_prize_not_claimed tests
// ============================================================================

#[test]
#[should_panic(expected: "Prize: Prize has already been claimed")]
fn test_assert_prize_not_claimed_fails_when_claimed() {
    let mock = deploy_prize_mock();

    let prize_type = PrizeType::Single(1);
    let context_id: u64 = 42;

    // Set as claimed
    mock.set_claimed(context_id, prize_type);

    // Should panic
    mock.assert_prize_not_claimed(context_id, prize_type);
}

#[test]
fn test_assert_prize_not_claimed_succeeds_when_unclaimed() {
    let mock = deploy_prize_mock();

    let prize_type = PrizeType::Single(1);
    let context_id: u64 = 42;

    // Should not panic (nothing claimed)
    mock.assert_prize_not_claimed(context_id, prize_type);
}

// ============================================================================
// is_prize_claimed (embeddable IPrize) tests
// ============================================================================

#[test]
fn test_is_prize_claimed_false_by_default() {
    let mock = deploy_prize_mock();
    assert!(!mock.is_prize_claimed(1, PrizeType::Single(1)), "should not be claimed by default");
}

#[test]
fn test_is_prize_claimed_true_after_set() {
    let mock = deploy_prize_mock();
    let context_id: u64 = 42;
    let prize_type = PrizeType::Single(1);

    mock.set_claimed(context_id, prize_type);
    assert!(mock.is_prize_claimed(context_id, prize_type), "should be claimed after set");
}
