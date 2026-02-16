use game_components_utilities::distribution::models::Distribution;
use crate::prize::models::{ERC20Data, ERC721Data, PrizeData, StoredPrizeTrait, TokenTypeData};

// ============================================================================
// pack_token_type / unpack_token_type roundtrip tests via StoredPrizeTrait
// ============================================================================

fn make_prize(token_type: TokenTypeData) -> PrizeData {
    PrizeData {
        id: 0,
        context_id: 1,
        token_address: starknet::contract_address_const::<0x123>(),
        token_type,
        sponsor_address: starknet::contract_address_const::<0x456>(),
    }
}

#[test]
fn test_pack_unpack_token_type_erc20_no_distribution() {
    let original = TokenTypeData::erc20(
        ERC20Data { amount: 500, distribution: Option::None, distribution_count: Option::None },
    );

    let stored = StoredPrizeTrait::from_prize(make_prize(original));
    let restored = stored.to_prize(1);

    match restored.token_type {
        TokenTypeData::erc20(data) => {
            assert!(data.amount == 500, "amount mismatch");
            assert!(data.distribution.is_none(), "should be None");
            assert!(data.distribution_count.is_none(), "count should be None");
        },
        TokenTypeData::erc721(_) => { panic!("expected erc20"); },
    }
}

#[test]
fn test_pack_unpack_token_type_erc20_linear() {
    let original = TokenTypeData::erc20(
        ERC20Data {
            amount: 1000,
            distribution: Option::Some(Distribution::Linear(15)),
            distribution_count: Option::Some(3),
        },
    );

    let stored = StoredPrizeTrait::from_prize(make_prize(original));
    let restored = stored.to_prize(1);

    match restored.token_type {
        TokenTypeData::erc20(data) => {
            assert!(data.amount == 1000, "amount mismatch");
            match data.distribution {
                Option::Some(dist) => {
                    match dist {
                        Distribution::Linear(w) => { assert!(w == 15, "weight mismatch"); },
                        _ => { panic!("expected Linear"); },
                    }
                },
                Option::None => { panic!("expected Some"); },
            }
            assert!(data.distribution_count == Option::Some(3), "count mismatch");
        },
        TokenTypeData::erc721(_) => { panic!("expected erc20"); },
    }
}

#[test]
fn test_pack_unpack_token_type_erc20_exponential() {
    let original = TokenTypeData::erc20(
        ERC20Data {
            amount: 2000,
            distribution: Option::Some(Distribution::Exponential(50)),
            distribution_count: Option::Some(5),
        },
    );

    let stored = StoredPrizeTrait::from_prize(make_prize(original));
    let restored = stored.to_prize(1);

    match restored.token_type {
        TokenTypeData::erc20(data) => {
            assert!(data.amount == 2000, "amount mismatch");
            match data.distribution {
                Option::Some(dist) => {
                    match dist {
                        Distribution::Exponential(w) => { assert!(w == 50, "weight mismatch"); },
                        _ => { panic!("expected Exponential"); },
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
fn test_pack_unpack_token_type_erc20_uniform() {
    let original = TokenTypeData::erc20(
        ERC20Data {
            amount: 3000,
            distribution: Option::Some(Distribution::Uniform),
            distribution_count: Option::Some(4),
        },
    );

    let stored = StoredPrizeTrait::from_prize(make_prize(original));
    let restored = stored.to_prize(1);

    match restored.token_type {
        TokenTypeData::erc20(data) => {
            assert!(data.amount == 3000, "amount mismatch");
            match data.distribution {
                Option::Some(dist) => {
                    match dist {
                        Distribution::Uniform => {},
                        _ => { panic!("expected Uniform"); },
                    }
                },
                Option::None => { panic!("expected Some"); },
            }
            assert!(data.distribution_count == Option::Some(4), "count mismatch");
        },
        TokenTypeData::erc721(_) => { panic!("expected erc20"); },
    }
}

#[test]
fn test_pack_unpack_token_type_erc20_custom() {
    // Custom distribution loses share data during pack (shares stored separately in component)
    // but the variant type should be preserved
    let original = TokenTypeData::erc20(
        ERC20Data {
            amount: 4000,
            distribution: Option::Some(
                Distribution::Custom(array![5000_u16, 3000_u16, 2000_u16].span()),
            ),
            distribution_count: Option::Some(3),
        },
    );

    let stored = StoredPrizeTrait::from_prize(make_prize(original));
    let restored = stored.to_prize(1);

    match restored.token_type {
        TokenTypeData::erc20(data) => {
            assert!(data.amount == 4000, "amount mismatch");
            match data.distribution {
                Option::Some(dist) => {
                    match dist {
                        Distribution::Custom(_) => {},
                        _ => { panic!("expected Custom"); },
                    }
                },
                Option::None => { panic!("expected Some"); },
            }
            assert!(data.distribution_count == Option::Some(3), "count mismatch");
        },
        TokenTypeData::erc721(_) => { panic!("expected erc20"); },
    }
}

#[test]
fn test_pack_unpack_token_type_erc721() {
    let original = TokenTypeData::erc721(ERC721Data { id: 42 });

    let stored = StoredPrizeTrait::from_prize(make_prize(original));
    let restored = stored.to_prize(1);

    match restored.token_type {
        TokenTypeData::erc20(_) => { panic!("expected erc721"); },
        TokenTypeData::erc721(data) => { assert!(data.id == 42, "id mismatch"); },
    }
}

// ============================================================================
// StoredPrize from/to roundtrip
// ============================================================================

#[test]
fn test_stored_prize_from_to_roundtrip_erc20() {
    let token_addr = starknet::contract_address_const::<0xABC>();
    let sponsor_addr = starknet::contract_address_const::<0xDEF>();

    let prize = PrizeData {
        id: 7,
        context_id: 42,
        token_address: token_addr,
        token_type: TokenTypeData::erc20(
            ERC20Data {
                amount: 999999,
                distribution: Option::Some(Distribution::Linear(20)),
                distribution_count: Option::Some(10),
            },
        ),
        sponsor_address: sponsor_addr,
    };

    let stored = StoredPrizeTrait::from_prize(prize);
    let restored = stored.to_prize(7);

    assert!(restored.id == 7, "id mismatch");
    assert!(restored.context_id == 42, "context_id mismatch");
    assert!(restored.token_address == token_addr, "token_address mismatch");
    assert!(restored.sponsor_address == sponsor_addr, "sponsor_address mismatch");
}

#[test]
fn test_stored_prize_from_to_roundtrip_erc721() {
    let token_addr = starknet::contract_address_const::<0xABC>();
    let sponsor_addr = starknet::contract_address_const::<0xDEF>();

    let prize = PrizeData {
        id: 3,
        context_id: 99,
        token_address: token_addr,
        token_type: TokenTypeData::erc721(ERC721Data { id: 777 }),
        sponsor_address: sponsor_addr,
    };

    let stored = StoredPrizeTrait::from_prize(prize);
    let restored = stored.to_prize(3);

    assert!(restored.id == 3, "id mismatch");
    assert!(restored.context_id == 99, "context_id mismatch");
    assert!(restored.token_address == token_addr, "token_address mismatch");
    assert!(restored.sponsor_address == sponsor_addr, "sponsor_address mismatch");

    match restored.token_type {
        TokenTypeData::erc20(_) => { panic!("expected erc721"); },
        TokenTypeData::erc721(data) => { assert!(data.id == 777, "id mismatch"); },
    }
}
