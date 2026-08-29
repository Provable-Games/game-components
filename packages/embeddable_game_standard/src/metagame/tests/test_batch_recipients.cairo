// =============================================================================
// TEST: mint_batch_recipients — ONE game, many recipients, ONE dispatch
// =============================================================================
//
// Distinct from `mint_batch`, which loops over `mint`: one cross-contract call
// per token, each entry free to name a different game. This routes a single
// dispatch to the token's own batch entrypoint, which hoists the
// batch-invariant work and runs one global salt counter. Tournament entry is
// the motivating case — budokan mints every entrant in one call, and adopting
// `mint_batch` there would have turned that into N calls.

use game_components_embeddable_game_standard::token::interface::{
    IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use game_components_interfaces::structs::token::MintBatchRecipient;
use game_components_testing::constants::{ALICE, BOB, OWNER};
use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::metagame::metagame as libs;

// =============================================================================
// HELPERS
// =============================================================================

/// The merged game+token contract — the only supported standard-token shape.
fn deploy_standard_game() -> ContractAddress {
    let contract = declare("StandardGameMock").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "StandardToken";
    let symbol: ByteArray = "STD";
    let base_uri: ByteArray = "https://token.test/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    ALICE().serialize(ref calldata);
    OWNER().serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}


/// Two recipients, three tokens total — exercises per-recipient counts.
fn two_recipients() -> Array<MintBatchRecipient> {
    array![MintBatchRecipient { to: ALICE(), count: 2 }, MintBatchRecipient { to: BOB(), count: 1 }]
}

fn one_recipient() -> Array<MintBatchRecipient> {
    array![MintBatchRecipient { to: BOB(), count: 1 }]
}

// =============================================================================
// STANDARD TOKEN
// =============================================================================

/// One dispatch mints every recipient's tokens, in recipient order.
#[test]
fn test_batch_recipients_through_standard_token() {
    let game = deploy_standard_game();

    let token_ids = libs::mint_batch_recipients(
        game,
        Option::Some('Entrant'),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        two_recipients(),
        false,
        false,
        0,
        0,
    );

    assert!(token_ids.len() == 3, "expected 3 tokens, got {}", token_ids.len());
    let erc721 = IERC721Dispatcher { contract_address: game };
    assert!(erc721.owner_of((*token_ids.at(0)).into()) == ALICE(), "token 0 should go to ALICE");
    assert!(erc721.owner_of((*token_ids.at(1)).into()) == ALICE(), "token 1 should go to ALICE");
    assert!(erc721.owner_of((*token_ids.at(2)).into()) == BOB(), "token 2 should go to BOB");
}

/// Every token in the batch is distinct — the global salt counter runs across
/// recipients, not per recipient.
#[test]
fn test_batch_recipients_ids_are_distinct() {
    let game = deploy_standard_game();

    let token_ids = libs::mint_batch_recipients(
        game,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        two_recipients(),
        false,
        false,
        0,
        0,
    );

    let a = *token_ids.at(0);
    let b = *token_ids.at(1);
    let c = *token_ids.at(2);
    assert!(a != b, "tokens 0 and 1 collided");
    assert!(b != c, "tokens 1 and 2 collided");
    assert!(a != c, "tokens 0 and 2 collided");
}

/// The reason this parameter is `u128`: budokan passes a metadata_value wider
/// than the legacy token's u16 field, and it must survive the batch unchanged.
#[test]
fn test_batch_recipients_carries_wide_metadata() {
    let game = deploy_standard_game();
    // Wider than u16, well inside the id layout's 65-bit metadata field.
    let wide: u128 = 0x100000000;

    let token_ids = libs::mint_batch_recipients(
        game,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        one_recipient(),
        false,
        false,
        0,
        wide,
    );

    let token = IMinigameTokenDispatcher { contract_address: game };
    assert!(token.mint_metadata(*token_ids.at(0)) == wide, "wide metadata lost in the batch");
}

/// Same self-bound gate as every other standard-token path: a contract that is
/// not a standard token — it does not advertise `IMINIGAME_TOKEN_ID` — must not
/// have a batch minted on it.
#[test]
#[should_panic(expected: "Game is not registered")]
fn test_batch_recipients_rejects_game_that_is_not_a_standard_token() {
    let fake: ContractAddress = 0xBAD.try_into().unwrap();
    mock_call(fake, selector!("supports_interface"), false, 10);

    libs::mint_batch_recipients(
        fake,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        one_recipient(),
        false,
        false,
        0,
        0,
    );
}

/// Unsupported params are rejected loudly, never silently dropped.
#[test]
#[should_panic(expected: "Metagame: tokens have no per-token renderer")]
fn test_batch_recipients_rejects_renderer_on_standard_token() {
    let game = deploy_standard_game();
    libs::mint_batch_recipients(
        game,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(BOB()),
        Option::None,
        one_recipient(),
        false,
        false,
        0,
        0,
    );
}

#[test]
#[should_panic(expected: "Metagame: tokens have no per-token skills")]
fn test_batch_recipients_rejects_skills_on_standard_token() {
    let game = deploy_standard_game();
    libs::mint_batch_recipients(
        game,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(BOB()),
        one_recipient(),
        false,
        false,
        0,
        0,
    );
}
