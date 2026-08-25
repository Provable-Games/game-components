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

fn deploy_legacy_token() -> ContractAddress {
    let contract = declare("MockMinigameTokenForLibs").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    address
}

fn deploy_legacy_game(token_address: ContractAddress) -> ContractAddress {
    let contract = declare("MockMinigameForLibs").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![token_address.into()]).unwrap();
    address
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

/// Same self-bound gate as every other standard-token path: a contract that
/// merely implements `token_address()` must not mint on a token it does not own.
#[test]
#[should_panic(expected: "Game is not registered")]
fn test_batch_recipients_rejects_foreign_standard_token() {
    let victim = deploy_standard_game();
    let hostile: ContractAddress = 0xBAD.try_into().unwrap();
    mock_call(hostile, selector!("token_address"), victim, 10);

    libs::mint_batch_recipients(
        hostile,
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
#[should_panic(expected: "Metagame: standard tokens have no per-token renderer")]
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
#[should_panic(expected: "Metagame: standard tokens have no per-token skills")]
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

// =============================================================================
// LEGACY TOKEN
// =============================================================================

/// Legacy tokens are served too, through their own batch entrypoint.
#[test]
fn test_batch_recipients_through_legacy_token() {
    let token_address = deploy_legacy_token();
    let game_address = deploy_legacy_game(token_address);

    let token_ids = libs::mint_batch_recipients(
        game_address,
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

    assert!(token_ids.len() == 3, "expected 3 tokens, got {}", token_ids.len());
}

/// Legacy keeps its renderer/skills params — they are only unsupported on the
/// standard token, so the legacy path must still accept them.
#[test]
fn test_batch_recipients_accepts_renderer_on_legacy_token() {
    let token_address = deploy_legacy_token();
    let game_address = deploy_legacy_game(token_address);

    let token_ids = libs::mint_batch_recipients(
        game_address,
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

    assert!(token_ids.len() == 1, "legacy batch should accept a renderer");
}

/// The legacy metadata field is u16 — reject rather than silently truncate.
#[test]
#[should_panic(expected: ('Metagame: metadata exceeds u16',))]
fn test_batch_recipients_rejects_wide_metadata_on_legacy_token() {
    let token_address = deploy_legacy_token();
    let game_address = deploy_legacy_game(token_address);

    libs::mint_batch_recipients(
        game_address,
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
        0x100000000,
    );
}

/// The single-mint path narrows the same way the batch path does — the two
/// must not disagree about what a legacy token accepts.
#[test]
#[should_panic(expected: ('Metagame: metadata exceeds u16',))]
fn test_mint_rejects_wide_metadata_on_legacy_token() {
    let token_address = deploy_legacy_token();
    let game_address = deploy_legacy_game(token_address);

    libs::mint(
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        BOB(),
        false,
        false,
        0,
        0x100000000,
    );
}

/// A metadata value that does fit u16 passes through to the legacy token.
#[test]
fn test_batch_recipients_accepts_narrow_metadata_on_legacy_token() {
    let token_address = deploy_legacy_token();
    let game_address = deploy_legacy_game(token_address);

    let token_ids = libs::mint_batch_recipients(
        game_address,
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
        0xFFFF,
    );

    assert!(token_ids.len() == 1, "u16-fitting metadata should pass through");
}
