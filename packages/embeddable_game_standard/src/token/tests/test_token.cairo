use game_components_interfaces::structs::metagame::{GameContext, GameContextDetails};
use game_components_interfaces::structs::token::MintBatchRecipient;
use game_components_interfaces::token::game_fee::{
    DEFAULT_GAME_FEE_BPS, FEE_DENOMINATOR, GameFeeTerms, IMINIGAME_TOKEN_GAME_FEE_ID,
    IMinigameTokenGameFeeDispatcher, IMinigameTokenGameFeeDispatcherTrait, default_license,
};
use game_components_interfaces::token::minter::{
    IMinigameTokenMinterDispatcher, IMinigameTokenMinterDispatcherTrait,
};
use game_components_test_common::mocks::standard_game_mock::{
    IStandardGameMockDispatcher, IStandardGameMockDispatcherTrait,
};
use openzeppelin_interfaces::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_caller_address, declare, mock_call, spy_events, start_cheat_block_number,
    start_cheat_block_timestamp, start_cheat_transaction_hash,
};
use starknet::ContractAddress;
use crate::token::interface::{
    IMINIGAME_TOKEN_ID, IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use crate::token::minigame_token_component::MinigameTokenComponent;
use crate::token::packing::{
    SCHEMA_VERSION, unpack_end_delay, unpack_has_context, unpack_metadata,
    unpack_minted_at_block_number, unpack_minted_at_timestamp, unpack_minted_by,
    unpack_objective_id, unpack_paymaster, unpack_schema_version, unpack_settings_id,
    unpack_soulbound, unpack_start_delay, unpack_token_id, unpack_tx_hash, unpack_tx_nonce,
};

fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn ALICE() -> ContractAddress {
    addr('ALICE')
}

fn BOB() -> ContractAddress {
    addr('BOB')
}

fn MINTER() -> ContractAddress {
    addr('MINTER')
}

fn FEE_RECIPIENT() -> ContractAddress {
    addr('FEE_RECIPIENT')
}

fn OWNER() -> ContractAddress {
    addr('OWNER')
}

/// Deploys ONE contract that is both the game and the token — the only
/// supported shape: the component is self-binding.
fn deploy_token() -> (
    IMinigameTokenDispatcher, ERC721ABIDispatcher, IMinigameTokenMinterDispatcher,
) {
    let contract = declare("StandardGameMock").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "StandardToken";
    let symbol: ByteArray = "STD";
    let base_uri: ByteArray = "https://token.test/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    FEE_RECIPIENT().serialize(ref calldata);
    OWNER().serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    (
        IMinigameTokenDispatcher { contract_address },
        ERC721ABIDispatcher { contract_address },
        IMinigameTokenMinterDispatcher { contract_address },
    )
}

/// The embedding game's view of the same contract — used to exercise the
/// component's internal pre-action guard (`assert_owner_and_playable` moved
/// off the external ABI; the mock re-exposes it the way a real game consumes
/// it inside its entrypoints).
fn game_of(token: IMinigameTokenDispatcher) -> IStandardGameMockDispatcher {
    IStandardGameMockDispatcher { contract_address: token.contract_address }
}

/// Mint with the 9-arg shape, neutral values for the params a test is not
/// exercising (no objective/context, no paymaster, zero
/// metadata). There is no game address — the token IS the game — and no
/// salt: ids are made unique by the tx hash (and, in a batch, the position).
fn mint_basic(
    token: IMinigameTokenDispatcher,
    settings_id: Option<u32>,
    start: Option<u64>,
    end: Option<u64>,
    to: ContractAddress,
    soulbound: bool,
) -> felt252 {
    token.mint(settings_id, start, end, Option::None, Option::None, to, soulbound, false, 0)
}

fn sample_context() -> GameContextDetails {
    GameContextDetails {
        name: "Tournament",
        description: "A test tournament",
        id: Option::Some(7),
        context: array![GameContext { name: 'round', value: 1 }].span(),
    }
}

// ================================================================================================
// DEPLOYMENT / INTERFACE REGISTRATION
// ================================================================================================

#[test]
fn test_deployment_and_interfaces() {
    let (token, erc721, _) = deploy_token();

    assert!(erc721.name() == "StandardToken", "Name mismatch");
    assert!(erc721.symbol() == "STD", "Symbol mismatch");

    let src5 = ISRC5Dispatcher { contract_address: token.contract_address };
    assert!(
        src5.supports_interface(IMINIGAME_TOKEN_ID), "Should register the standard interface id",
    );
    // SRC5 is honest: the standard token must never claim the RETIRED
    // generation's id. That generation's code is gone, but deployed contracts
    // still register this value on-chain, so the literal is inlined here
    // deliberately — a consumer probing it must not match a standard token.
    let retired_legacy_id: felt252 =
        0x246f614bd76b91c378a91877851f2ccdb99278e9fb77c782a22355059ce9906;
    assert!(
        !src5.supports_interface(retired_legacy_id),
        "Must NOT advertise the retired generation's token id",
    );
}

// ================================================================================================
// MINT — PACKED FIELDS
// ================================================================================================

#[test]
fn test_mint_packs_expected_fields() {
    let (token, erc721, minter) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    start_cheat_block_number(token.contract_address, 777);

    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let token_id = mint_basic(
        token, Option::Some(42), Option::Some(2400), Option::Some(3600), ALICE(), true,
    );

    let packed = unpack_token_id(token_id);
    assert!(packed.schema_version == SCHEMA_VERSION, "schema_version mismatch");
    assert!(packed.settings_id == 42, "settings_id mismatch");
    assert!(packed.minted_at_block_number == 777, "block number mismatch");
    assert!(packed.minted_at_timestamp == 20, "minted_at_timestamp is whole minutes");
    assert!(packed.start_delay == 20, "start_delay is minutes after minted_at");
    assert!(packed.end_delay == 20, "end_delay is minutes after start");
    assert!(packed.soulbound, "soulbound flag should be set");
    assert!(packed.minted_by == 1, "First minter should pack id 1");
    assert!(packed.tx_nonce == 0, "first attempt takes nonce 0");

    // With the other params neutral, everything above minted_by in the high
    // half (the metadata field) must be zero.
    let raw: u256 = token_id.into();
    assert!(raw.high / 0x10000000000000000 == 0, "neutral metadata must decode as zero"); // 2^64

    // Views resolve from the packed id / minter map
    assert!(token.schema_version(token_id) == SCHEMA_VERSION, "schema_version view mismatch");
    assert!(token.minted_at_block_number(token_id) == 777, "block number view mismatch");
    assert!(token.minted_at(token_id) == 1200, "minted_at view is in seconds");
    assert!(token.start_delay(token_id) == 20, "start_delay view mismatch");
    assert!(token.end_delay(token_id) == 20, "end_delay view mismatch");
    let lifecycle = token.lifecycle(token_id);
    assert!(lifecycle.start == 2400 && lifecycle.end == 3600, "lifecycle view mismatch");
    assert!(token.settings_id(token_id) == 42, "settings_id view mismatch");
    assert!(token.is_soulbound(token_id), "is_soulbound view mismatch");
    assert!(token.minted_by(token_id) == 1, "First minter should get id 1");
    assert!(token.minted_by_address(token_id) == MINTER(), "minted_by_address mismatch");
    assert!(minter.get_minter_address(1) == MINTER(), "Minter registry mismatch");
    assert!(erc721.owner_of(token_id.into()) == ALICE(), "Owner mismatch");
}

#[test]
fn test_mint_defaults_and_metadata_view() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);

    let token_id = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);

    let metadata = token.token_metadata(token_id);
    assert!(metadata.settings_id == 0, "settings_id should default 0");
    assert!(metadata.minted_at == 1200, "minted_at mismatch");
    assert!(metadata.schema_version == SCHEMA_VERSION, "schema_version mismatch");
    assert!(metadata.lifecycle.start == 1200, "start clamps to mint time");
    assert!(metadata.lifecycle.end == 0, "no end means immortal");
    assert!(!metadata.soulbound, "not soulbound");
    // No mutable state exists — these are unconditionally false/0
    assert!(!metadata.game_over, "game_over must always be false");
    assert!(!metadata.completed_objective, "completed_objective must always be false");
    assert!(metadata.completed_at == 0, "completed_at must always be 0");
    // Neutral restored params decode as absent
    assert!(metadata.objective_id == 0, "objective_id defaults to 0");
    assert!(!metadata.has_context, "has_context defaults to false");
    assert!(!metadata.paymaster, "paymaster defaults to false");
    assert!(metadata.metadata == 0, "metadata defaults to 0");
    assert!(token.objective_id(token_id) == 0, "objective_id view defaults to 0");
    assert!(token.mint_metadata(token_id) == 0, "mint_metadata defaults to 0");
    assert!(token.client_url(token_id) == "", "client_url defaults to empty");
    assert!(token.player_name(token_id) == 0, "No player name set");
}

#[test]
fn test_mint_past_start_clamps_to_now() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);

    let token_id = mint_basic(
        token, Option::None, Option::Some(600), Option::Some(2400), ALICE(), false,
    );

    let metadata = token.token_metadata(token_id);
    assert!(metadata.lifecycle.start == 1200, "Past start should clamp to mint time");
    assert!(metadata.lifecycle.end == 2400, "End must reconstruct to the caller's value");
}

/// Pins block timestamp, block number and tx hash so every mint in the test
/// packs byte-identical fields.
fn pin_block_and_tx(token: IMinigameTokenDispatcher) {
    start_cheat_block_timestamp(token.contract_address, 1200);
    start_cheat_block_number(token.contract_address, 42);
    start_cheat_transaction_hash(token.contract_address, 0xABCDEF);
}

/// `mint` always packs tx_nonce 0 and never probes storage: a second mint
/// with identical fields in the same block and tx produces the same id and
/// reverts in the ERC721 mint. Several tokens per tx go through
/// `mint_batch_recipients`.
#[test]
#[should_panic(expected: 'ERC721: token already minted')]
fn test_mint_identical_in_same_tx_reverts() {
    let (token, _, _) = deploy_token();
    pin_block_and_tx(token);
    let id_a = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    assert!(token.tx_nonce(id_a) == 0, "single mint packs nonce 0");
    mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
}

/// Same params but a different tx hash gives a different id; both single
/// mints carry nonce 0.
#[test]
fn test_mint_distinct_tx_hash_gives_distinct_ids() {
    let (token, _, _) = deploy_token();
    pin_block_and_tx(token);
    let id_a = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    start_cheat_transaction_hash(token.contract_address, 0xABCDEE);
    let id_b = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    assert!(id_a != id_b, "different tx hashes give different ids");
    assert!(token.tx_nonce(id_a) == 0 && token.tx_nonce(id_b) == 0, "single mints pack nonce 0");
    assert!(token.tx_hash(id_a) == 0xCDEF && token.tx_hash(id_b) == 0xCDEE, "tx_hash low 16");
}

#[test]
fn test_mint_minter_ids_by_caller() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);

    let id_a = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    assert!(token.minted_by(id_a) == 1, "First minter should get id 1");

    // Second distinct caller gets minter id 2
    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let id_c = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    assert!(token.minted_by(id_c) == 2, "Second minter should get id 2");
    // Repeat caller keeps its id
    start_cheat_transaction_hash(token.contract_address, 0x2222); // a new tx for the repeat mint
    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let id_d = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    assert!(token.minted_by(id_d) == 2, "Repeat minter keeps id");
}

// ================================================================================================
// MINT — LIFECYCLE VALIDATION
// ================================================================================================

#[test]
#[should_panic(expected: "MinigameToken: Lifecycle end must be in the future and after start")]
fn test_mint_rejects_past_end() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    mint_basic(token, Option::None, Option::None, Option::Some(600), ALICE(), false);
}

#[test]
#[should_panic(expected: "Lifecycle: Start time cannot be greater than end time")]
fn test_mint_rejects_start_after_end() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    mint_basic(token, Option::None, Option::Some(3600), Option::Some(2400), ALICE(), false);
}

// ================================================================================================
// PLAYABILITY — LIFECYCLE WINDOW ONLY
// ================================================================================================

#[test]
fn test_playability_follows_lifecycle_window() {
    let (token, _, _) = deploy_token();
    let game = game_of(token);
    start_cheat_block_timestamp(token.contract_address, 1200);

    let token_id = mint_basic(
        token, Option::None, Option::Some(2400), Option::Some(3600), ALICE(), false,
    );

    assert!(!token.is_playable(token_id), "Not playable before window opens");

    start_cheat_block_timestamp(token.contract_address, 2400);
    assert!(token.is_playable(token_id), "Playable at window start");
    // The embedding game's internal pre-action guard agrees with the view
    game.assert_owner_and_playable(token_id, ALICE());

    start_cheat_block_timestamp(token.contract_address, 3599);
    game.assert_owner_and_playable(token_id, ALICE());

    start_cheat_block_timestamp(token.contract_address, 3600);
    assert!(!token.is_playable(token_id), "Expired at window end");
}

#[test]
fn test_immortal_token_always_playable() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    let token_id = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    start_cheat_block_timestamp(token.contract_address, 99999999);
    assert!(token.is_playable(token_id), "No end means playable forever");
    game_of(token).assert_owner_and_playable(token_id, ALICE());
}

// ================================================================================================
// INTERNAL GUARD (assert_owner_and_playable — via the embedding game mock)
// ================================================================================================

#[test]
#[should_panic(expected: "MinigameToken: Token is not playable - game has expired")]
fn test_guard_panics_after_expiry() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::Some(2400), ALICE(), false,
    );
    start_cheat_block_timestamp(token.contract_address, 2400);
    game_of(token).assert_owner_and_playable(token_id, ALICE());
}

#[test]
#[should_panic(expected: "MinigameToken: Token is not playable - game has not started")]
fn test_guard_panics_before_start() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    let token_id = mint_basic(
        token, Option::None, Option::Some(2400), Option::Some(3600), ALICE(), false,
    );
    game_of(token).assert_owner_and_playable(token_id, ALICE());
}

#[test]
#[should_panic(expected: "MinigameToken: Address is not owner of token")]
fn test_guard_rejects_wrong_owner() {
    let (token, _, _) = deploy_token();
    let token_id = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    game_of(token).assert_owner_and_playable(token_id, BOB());
}

#[test]
#[should_panic(expected: "MinigameToken: Address is not owner of token")]
fn test_guard_rejects_nonexistent_token() {
    let (token, _, _) = deploy_token();
    game_of(token).assert_owner_and_playable(12345, ALICE());
}

#[test]
#[should_panic(expected: "MinigameToken: Expected owner cannot be zero")]
fn test_guard_rejects_zero_owner() {
    let (token, _, _) = deploy_token();
    let token_id = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    game_of(token).assert_owner_and_playable(token_id, addr(0));
}

// ================================================================================================
// SOULBOUND
// ================================================================================================

#[test]
#[should_panic(expected: "Token is soulbound and cannot be transferred")]
fn test_soulbound_transfer_blocked() {
    let (token, erc721, _) = deploy_token();
    let token_id = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), true);
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721.transfer_from(ALICE(), BOB(), token_id.into());
}

#[test]
fn test_non_soulbound_transfer_allowed() {
    let (token, erc721, _) = deploy_token();
    let token_id = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721.transfer_from(ALICE(), BOB(), token_id.into());
    assert!(erc721.owner_of(token_id.into()) == BOB(), "Transfer should succeed");
}

// ================================================================================================
// METADATA REFRESH + PLAYER NAME
// ================================================================================================

#[test]
fn test_refresh_metadata_emits_event() {
    let (token, _, _) = deploy_token();
    let token_id = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);

    let mut spy = spy_events();
    token.refresh_metadata(token_id);
    spy
        .assert_emitted(
            @array![
                (
                    token.contract_address,
                    MinigameTokenComponent::Event::MetadataUpdate(
                        MinigameTokenComponent::MetadataUpdate { token_id: token_id.into() },
                    ),
                ),
            ],
        );
}

#[test]
fn test_set_player_name_by_owner() {
    let (token, _, _) = deploy_token();
    let token_id = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    token.set_player_name(token_id, 'new');
    assert!(token.player_name(token_id) == 'new', "Player name should update");
}

#[test]
#[should_panic(expected: "MinigameToken: Caller is not owner of token")]
fn test_set_player_name_rejects_non_owner() {
    let (token, _, _) = deploy_token();
    let token_id = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    cheat_caller_address(token.contract_address, BOB(), CheatSpan::TargetCalls(1));
    token.set_player_name(token_id, 'new');
}

// ================================================================================================
// BATCH MINT
// ================================================================================================

fn batch_neutral(
    token: IMinigameTokenDispatcher, recipients: Array<MintBatchRecipient>,
) -> Array<felt252> {
    token
        .mint_batch_recipients(
            Option::Some(5),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipients,
            false,
            false,
            0,
        )
}

#[test]
fn test_mint_batch_recipients_counts_owners_and_nonces() {
    let (token, erc721, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);

    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let ids = batch_neutral(
        token,
        array![
            MintBatchRecipient { to: ALICE(), count: 2 },
            MintBatchRecipient { to: BOB(), count: 1 },
        ],
    );

    assert!(ids.len() == 3, "Should mint 3 tokens");
    let id_a = *ids.at(0);
    let id_b = *ids.at(1);
    let id_c = *ids.at(2);
    assert!(id_a != id_b && id_b != id_c && id_a != id_c, "Token ids must be distinct");
    assert!(erc721.owner_of(id_a.into()) == ALICE(), "First token to ALICE");
    assert!(erc721.owner_of(id_b.into()) == ALICE(), "Second token to ALICE");
    assert!(erc721.owner_of(id_c.into()) == BOB(), "Third token to BOB");

    // One nonce counter across the batch, minter registered once
    assert!(
        unpack_tx_nonce(id_a) == 0 && unpack_tx_nonce(id_b) == 1 && unpack_tx_nonce(id_c) == 2,
        "batch nonces run 0, 1, 2",
    );
    let mut i: u32 = 0;
    while i < ids.len() {
        let id = *ids.at(i);
        assert!(token.minted_by(id) == 1, "All share minter id 1");
        assert!(token.settings_id(id) == 5, "Shared settings id");
        i += 1;
    }
}

/// A batch shares one 8-bit nonce counter: 256 tokens exactly fill it.
#[test]
fn test_mint_batch_recipients_at_256_token_cap() {
    let (token, erc721, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    let ids = batch_neutral(
        token,
        array![
            MintBatchRecipient { to: ALICE(), count: 200 },
            MintBatchRecipient { to: BOB(), count: 56 },
        ],
    );
    assert!(ids.len() == 256, "Should mint 256 tokens");
    assert!(unpack_tx_nonce(*ids.at(0)) == 0, "first nonce");
    assert!(unpack_tx_nonce(*ids.at(255)) == 255, "last nonce fills the 8-bit field");
    assert!(erc721.owner_of((*ids.at(255)).into()) == BOB(), "last token to BOB");
}

#[test]
#[should_panic(expected: "MinigameToken: batch exceeds 256 tokens (8-bit tx_nonce)")]
fn test_mint_batch_recipients_rejects_257_tokens() {
    let (token, erc721, _) = deploy_token();
    // 257 tokens can never fit one nonce counter — rejected before any mint.
    batch_neutral(
        token,
        array![
            MintBatchRecipient { to: ALICE(), count: 256 },
            MintBatchRecipient { to: BOB(), count: 1 },
        ],
    );
    assert!(erc721.balance_of(ALICE()) == 0, "nothing minted before the cap check");
}

/// A batch always starts its nonces at 0, so mixing `mint` and a batch with
/// identical fields in one block and tx is not supported: the batch's first
/// token collides with the single mint and reverts.
#[test]
#[should_panic(expected: 'ERC721: token already minted')]
fn test_mint_then_identical_batch_in_same_tx_reverts() {
    let (token, _, _) = deploy_token();
    pin_block_and_tx(token);

    let single = token
        .mint(
            Option::Some(5),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
        );
    assert!(unpack_tx_nonce(single) == 0, "single mint packs nonce 0");
    batch_neutral(token, array![MintBatchRecipient { to: ALICE(), count: 3 }]);
}

#[test]
#[should_panic(expected: "MinigameToken: recipients array cannot be empty")]
fn test_mint_batch_recipients_rejects_empty() {
    let (token, _, _) = deploy_token();
    batch_neutral(token, array![]);
}

#[test]
#[should_panic(expected: "MinigameToken: per-recipient count must be > 0")]
fn test_mint_batch_recipients_rejects_zero_count() {
    let (token, _, _) = deploy_token();
    batch_neutral(token, array![MintBatchRecipient { to: ALICE(), count: 0 }]);
}

// ================================================================================================
// ECOSYSTEM INTEGRATION (metagame assert_game_registered)
// ================================================================================================

/// Positive path: `assert_game_registered` probes the game's SRC5 for
/// `IMINIGAME_TOKEN_ID`. A self-bound standard deployment IS its own token, so
/// it advertises the id and the check passes.
#[test]
fn test_assert_game_registered_accepts_self_bound_game() {
    let (token, _, _) = deploy_token();
    crate::metagame::metagame::assert_game_registered(token.contract_address);
}

/// Negative path: a fake game that is NOT a standard token — it does not
/// advertise `IMINIGAME_TOKEN_ID` over SRC5 — is rejected. The self-bound game
/// IS the token, so validity is exactly `supports_interface(IMINIGAME_TOKEN_ID)`
/// on the game address itself; a contract that fails the probe cannot have a
/// metagame mint on it or pay its fee recipient.
#[test]
#[should_panic(expected: "Game is not registered")]
fn test_assert_game_registered_rejects_game_not_paired_with_standard_token() {
    let fake_game = addr('FAKE_GAME');
    mock_call(fake_game, selector!("supports_interface"), false, 1);
    crate::metagame::metagame::assert_game_registered(fake_game);
}

// ================================================================================================
// PACKING — LAYOUT AND HELPERS
// ================================================================================================

#[test]
fn test_helper_unpackers_agree_with_full_unpack() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1234);
    start_cheat_block_number(token.contract_address, 99);
    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let token_id = mint_basic(
        token, Option::Some(9), Option::None, Option::Some(9999), ALICE(), true,
    );

    // The standalone helper unpackers (what game/dungeon contracts use on
    // their side) must agree with the full unpack.
    let packed = unpack_token_id(token_id);
    assert!(unpack_schema_version(token_id) == packed.schema_version, "schema helper mismatch");
    assert!(
        unpack_minted_at_block_number(token_id) == packed.minted_at_block_number,
        "block number helper mismatch",
    );
    assert!(
        unpack_minted_at_timestamp(token_id) == packed.minted_at_timestamp,
        "minted_at_timestamp helper mismatch",
    );
    assert!(unpack_start_delay(token_id) == packed.start_delay, "start_delay helper mismatch");
    assert!(unpack_end_delay(token_id) == packed.end_delay, "end_delay helper mismatch");
    assert!(unpack_settings_id(token_id) == packed.settings_id, "settings_id helper mismatch");
    assert!(unpack_minted_by(token_id) == packed.minted_by, "minted_by helper mismatch");
    assert!(unpack_soulbound(token_id) == packed.soulbound, "soulbound helper mismatch");
    assert!(unpack_tx_hash(token_id) == packed.tx_hash, "tx_hash helper mismatch");
    assert!(unpack_tx_nonce(token_id) == packed.tx_nonce, "tx_nonce helper mismatch");
    assert!(unpack_paymaster(token_id) == packed.paymaster, "paymaster helper mismatch");
    assert!(unpack_has_context(token_id) == packed.has_context, "has_context helper mismatch");
    assert!(unpack_objective_id(token_id) == packed.objective_id, "objective_id helper mismatch");
    assert!(unpack_metadata(token_id) == packed.metadata, "metadata helper mismatch");
    // 1234 s floors to minute 20; end 9999 s from start 1260 s ceils to 146 min.
    assert!(packed.minted_at_timestamp == 20 && packed.settings_id == 9, "field values");
    assert!(packed.start_delay == 1 && packed.end_delay == 146, "delay values");
    assert!(packed.soulbound && packed.minted_at_block_number == 99, "field values");
    assert!(packed.minted_by == 1 && packed.tx_nonce == 0, "field values");
}

/// Every view in the ABI against one known packed input: the id is built by
/// hand from the documented layout, then read back through the contract.
#[test]
fn test_views_decode_known_packed_input() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    start_cheat_block_number(token.contract_address, 0xDEADBEEF);
    start_cheat_transaction_hash(token.contract_address, 0x123456789abcdef);
    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));

    let token_id = token
        .mint(
            Option::Some(0xABCDE),
            Option::Some(2400),
            Option::Some(6000),
            Option::Some(0x1ABCD),
            Option::Some(sample_context()),
            ALICE(),
            true,
            true,
            0x123456789ABCD,
        );

    // low: version 1 | has_context<<5 | soulbound<<6 | paymaster<<7 |
    // tx_hash 0xcdef<<8 | nonce 0<<24 | block<<32 | ts 20<<64 |
    // start_delay 20<<91 | end_delay 60<<109
    let expected_low: u128 = 1
        + 0x20
        + 0x40
        + 0x80
        + 0xcdef * 0x100
        + 0xDEADBEEF * 0x100000000
        + 20 * 0x10000000000000000
        + 20 * 0x80000000000000000000000
        + 60 * 0x2000000000000000000000000000;
    let expected_high: u128 = 0xABCDE
        + 0x1ABCD * 0x100000
        + 1 * 0x10000000000
        + 0x123456789ABCD * 0x10000000000000000;
    let expected: felt252 = u256 { low: expected_low, high: expected_high }.try_into().unwrap();
    assert!(token_id == expected, "fixture: id must match the hand-packed layout");

    assert!(token.schema_version(token_id) == 1, "schema_version");
    assert!(token.has_context(token_id), "has_context");
    assert!(token.is_soulbound(token_id), "is_soulbound");
    assert!(token.is_paymaster(token_id), "is_paymaster");
    assert!(token.tx_hash(token_id) == 0xcdef, "tx_hash");
    assert!(token.tx_nonce(token_id) == 0, "tx_nonce");
    assert!(token.minted_at_block_number(token_id) == 0xDEADBEEF, "minted_at_block_number");
    assert!(token.minted_at(token_id) == 1200, "minted_at");
    assert!(token.start_delay(token_id) == 20, "start_delay");
    assert!(token.end_delay(token_id) == 60, "end_delay");
    let lifecycle = token.lifecycle(token_id);
    assert!(lifecycle.start == 2400 && lifecycle.end == 6000, "lifecycle");
    assert!(token.settings_id(token_id) == 0xABCDE, "settings_id");
    assert!(token.objective_id(token_id) == 0x1ABCD, "objective_id");
    assert!(token.minted_by(token_id) == 1, "minted_by");
    assert!(token.mint_metadata(token_id) == 0x123456789ABCD, "mint_metadata");
    // Name and url are never set at mint; the owner sets them afterwards.
    assert!(token.player_name(token_id) == 0 && token.client_url(token_id) == "", "unset");
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(2));
    token.set_player_name(token_id, 'alice');
    token.set_client_url(token_id, "https://play.example/game");
    assert!(token.player_name(token_id) == 'alice', "player_name");
    assert!(token.client_url(token_id) == "https://play.example/game", "client_url");
    let md = token.token_metadata(token_id);
    assert!(md.minted_at == 1200 && md.minted_at_block_number == 0xDEADBEEF, "token_metadata");
    assert!(md.schema_version == 1 && md.settings_id == 0xABCDE, "token_metadata");
    assert!(md.lifecycle.start == 2400 && md.lifecycle.end == 6000, "token_metadata");
    assert!(md.has_context && md.soulbound && md.paymaster, "token_metadata flags");
    assert!(md.objective_id == 0x1ABCD && md.metadata == 0x123456789ABCD, "token_metadata");
}

/// Mint at 1_000_000_059: the timestamp floors to minute 16_666_667 and
/// `minted_at` reports 1_000_000_020 — never later than the block time.
#[test]
fn test_mint_time_floors_to_the_minute() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1_000_000_059);
    let token_id = mint_basic(token, Option::None, Option::None, Option::None, ALICE(), false);
    assert!(unpack_minted_at_timestamp(token_id) == 16_666_667, "floored minutes");
    assert!(token.minted_at(token_id) == 1_000_000_020, "minted_at in seconds");
    // start clamps to now (1_000_000_059) which ceils to minute +1
    assert!(token.start_delay(token_id) == 1, "start ceils to the next minute");
    assert!(token.lifecycle(token_id).start == 1_000_000_080, "reconstructed start");
}

/// Delays ceil: a start 2 s after a :59 mint time lands in the next minute,
/// and an end 1 s after that start still yields end_delay 1 — a sub-minute
/// window never collapses into an immortal token.
#[test]
fn test_mint_delays_ceil_to_the_minute() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1_000_000_059);
    let token_id = mint_basic(
        token,
        Option::None,
        Option::Some(1_000_000_061),
        Option::Some(1_000_000_062),
        ALICE(),
        false,
    );
    assert!(token.start_delay(token_id) == 1, "start_delay ceils");
    assert!(token.end_delay(token_id) == 1, "end_delay ceils, never 0 for a real end");
    let lifecycle = token.lifecycle(token_id);
    assert!(lifecycle.start == 1_000_000_080, "start = (ts + 1) * 60");
    assert!(lifecycle.end == 1_000_000_140, "end = start + 60");
}

#[test]
fn test_mint_accepts_settings_id_at_20_bit_boundary() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    let token_id = mint_basic(
        token, Option::Some(0xFFFFF), Option::None, Option::None, ALICE(), false,
    );
    assert!(token.settings_id(token_id) == 0xFFFFF, "boundary settings_id roundtrip");
}

#[test]
#[should_panic(expected: "PackedTokenId: settings_id exceeds 20-bit limit")]
fn test_mint_rejects_settings_id_over_20_bits() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    // 2^20 — one past the 20-bit field — must be rejected at mint.
    mint_basic(token, Option::Some(0x100000), Option::None, Option::None, ALICE(), false);
}

// ================================================================================================
// RESTORED MINT PARAMS — objective_id / context / paymaster / metadata
// ================================================================================================

/// Mint helper that exercises exactly the restored params, neutral elsewhere.
fn mint_restored(
    token: IMinigameTokenDispatcher,
    objective_id: Option<u32>,
    context: Option<GameContextDetails>,
    paymaster: bool,
    metadata: u128,
) -> felt252 {
    token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            objective_id,
            context,
            ALICE(),
            false,
            paymaster,
            metadata,
        )
}

/// The restored packed fields roundtrip through mint: id bits, standalone
/// helpers, ABI views and the shared TokenMetadata struct all agree.
#[test]
fn test_mint_restored_fields_roundtrip() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);

    let token_id = mint_restored(
        token, Option::Some(123456), Option::Some(sample_context()), true, 0xDEADBEEFCAFE,
    );

    let packed = unpack_token_id(token_id);
    assert!(packed.objective_id == 123456, "objective_id pack mismatch");
    assert!(packed.has_context, "has_context bit should be set");
    assert!(packed.paymaster, "paymaster bit should be set");
    assert!(packed.metadata == 0xDEADBEEFCAFE, "metadata pack mismatch");

    // ABI views
    assert!(token.objective_id(token_id) == 123456, "objective_id view mismatch");
    assert!(token.mint_metadata(token_id) == 0xDEADBEEFCAFE, "mint_metadata view mismatch");

    // Shared TokenMetadata struct: every packed field round-trips, metadata
    // included — the struct field is 59 bits wide, so it holds exactly what
    // was minted and agrees with mint_metadata.
    // objective_id is inert data the game interprets: the standard token has no
    // completion machinery, so completed_objective stays false.
    let md = token.token_metadata(token_id);
    assert!(md.objective_id == 123456, "TokenMetadata.objective_id mismatch");
    assert!(md.has_context, "TokenMetadata.has_context mismatch");
    assert!(md.paymaster, "TokenMetadata.paymaster mismatch");
    assert!(md.metadata == 0xDEADBEEFCAFE, "TokenMetadata.metadata must round-trip");
    assert!(
        md.metadata == token.mint_metadata(token_id),
        "TokenMetadata.metadata must agree with mint_metadata",
    );
    assert!(!md.completed_objective, "completed_objective stays always-false");
}

#[test]
fn test_mint_accepts_field_boundaries() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);

    // Every restored field at its maximum: objective_id 2^20-1, metadata
    // 2^59-1 (filling high bit 122, the topmost usable bit), both flag bits
    // set.
    let token_id = mint_restored(
        token, Option::Some(0xFFFFF), Option::Some(sample_context()), true, 0x7FFFFFFFFFFFFFF,
    );
    assert!(token.objective_id(token_id) == 0xFFFFF, "boundary objective_id roundtrip");
    assert!(token.mint_metadata(token_id) == 0x7FFFFFFFFFFFFFF, "boundary metadata roundtrip");

    // metadata is the topmost high field: with it maxed, the quotient above
    // minted_by's top bit must be exactly the metadata value — nothing sits
    // above it.
    let raw: u256 = token_id.into();
    assert!(
        raw.high / 0x10000000000000000 == 0x7FFFFFFFFFFFFFF,
        "metadata occupies the entire top of the high half",
    ); // 2^64
}

#[test]
#[should_panic(expected: "PackedTokenId: objective_id exceeds 20-bit limit")]
fn test_mint_rejects_objective_id_over_20_bits() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    // 2^20 — one past the 20-bit field.
    mint_restored(token, Option::Some(0x100000), Option::None, false, 0);
}

#[test]
#[should_panic(expected: "PackedTokenId: metadata exceeds 59-bit limit")]
fn test_mint_rejects_metadata_over_59_bits() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    // 2^59 — one past the 59-bit field.
    mint_restored(token, Option::None, Option::None, false, 0x800000000000000);
}

/// client_url is never set at mint: it defaults to empty and the token owner
/// sets it afterwards via `set_client_url`, which emits `MetadataUpdate`.
#[test]
fn test_set_client_url_by_owner() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);
    let token_id = mint_restored(token, Option::None, Option::None, false, 0);
    assert!(token.client_url(token_id) == "", "client_url defaults to empty");

    let mut spy = spy_events();
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    token.set_client_url(token_id, "https://play.example/game");
    assert!(token.client_url(token_id) == "https://play.example/game", "client_url view mismatch");
    spy
        .assert_emitted(
            @array![
                (
                    token.contract_address,
                    MinigameTokenComponent::Event::MetadataUpdate(
                        MinigameTokenComponent::MetadataUpdate { token_id: token_id.into() },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: "MinigameToken: Caller is not owner of token")]
fn test_set_client_url_rejects_non_owner() {
    let (token, _, _) = deploy_token();
    let token_id = mint_restored(token, Option::None, Option::None, false, 0);
    cheat_caller_address(token.contract_address, BOB(), CheatSpan::TargetCalls(1));
    token.set_client_url(token_id, "https://play.example/game");
}

/// context sets the id's has_context bit only — the data itself is NOT stored
/// (legacy-token parity: its context hook was a documented no-op and token_uri
/// sourced context from the minter at render time).
#[test]
fn test_context_sets_has_context_bit_without_storage() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);

    let with_context = mint_restored(token, Option::None, Option::Some(sample_context()), false, 0);
    assert!(unpack_has_context(with_context), "has_context bit must be set");
    assert!(token.token_metadata(with_context).has_context, "metadata view agrees");
    // Nothing context-shaped was persisted: the only storage-backed views
    // stay at their defaults.
    assert!(token.client_url(with_context) == "", "no context data lands in storage");
    assert!(token.player_name(with_context) == 0, "no context data lands in storage");

    let without_context = mint_restored(token, Option::None, Option::None, false, 0);
    assert!(!unpack_has_context(without_context), "has_context bit must be clear");
}

/// Batch mints share the packed fields (has_context bit, objective, paymaster,
/// metadata) across all tokens.
#[test]
fn test_mint_batch_shares_restored_fields() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1200);

    let ids = token
        .mint_batch_recipients(
            Option::None,
            Option::None,
            Option::None,
            Option::Some(77),
            Option::Some(sample_context()),
            array![
                MintBatchRecipient { to: ALICE(), count: 2 },
                MintBatchRecipient { to: BOB(), count: 1 },
            ],
            false,
            true,
            42,
        );

    assert!(ids.len() == 3, "Should mint 3 tokens");
    let mut i: u32 = 0;
    while i < ids.len() {
        let id = *ids.at(i);
        assert!(unpack_has_context(id), "shared has_context bit");
        assert!(unpack_paymaster(id), "shared paymaster bit");
        assert!(token.objective_id(id) == 77, "shared objective_id");
        assert!(token.mint_metadata(id) == 42, "shared metadata");
        i += 1;
    }
}

// ================================================================================================
// CREATOR SURFACE (owner-administered payout identity)
// ================================================================================================

fn game_fee_of(token: IMinigameTokenDispatcher) -> IMinigameTokenGameFeeDispatcher {
    IMinigameTokenGameFeeDispatcher { contract_address: token.contract_address }
}

#[test]
fn test_game_fee_registered_with_defaults() {
    let (token, _, _) = deploy_token();
    let game_fee = game_fee_of(token);

    let src5 = ISRC5Dispatcher { contract_address: token.contract_address };
    assert!(
        src5.supports_interface(IMINIGAME_TOKEN_GAME_FEE_ID),
        "Should register the game-fee interface id",
    );

    assert!(game_fee.game_fee_recipient() == FEE_RECIPIENT(), "Recipient address mismatch");
    let info = game_fee.game_fee_terms();
    let expected = GameFeeTerms {
        recipient: FEE_RECIPIENT(), license: default_license(), fee_numerator: DEFAULT_GAME_FEE_BPS,
    };
    assert!(info == expected, "Info should carry the ecosystem defaults");
}

#[test]
fn test_owner_rotates_recipient_and_sets_fee() {
    let (token, _, _) = deploy_token();
    let game_fee = game_fee_of(token);

    cheat_caller_address(token.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    game_fee.set_game_fee_recipient(BOB());
    game_fee.set_game_fee("Custom license", 1000);

    let info = game_fee.game_fee_terms();
    assert!(info.recipient == BOB(), "Rotation should take effect");
    assert!(info.license == "Custom license", "License should update");
    assert!(info.fee_numerator == 1000, "Fee should update");
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_recipient_itself_cannot_rotate() {
    // The stored recipient is a payout sink, not an admin: only the contract
    // owner rotates it.
    let (token, _, _) = deploy_token();
    cheat_caller_address(token.contract_address, FEE_RECIPIENT(), CheatSpan::TargetCalls(1));
    game_fee_of(token).set_game_fee_recipient(BOB());
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_set_fee() {
    let (token, _, _) = deploy_token();
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    game_fee_of(token).set_game_fee("hijack", 0);
}

#[test]
#[should_panic(expected: "MinigameToken: Fee recipient cannot be zero")]
fn test_rotation_to_zero_rejected() {
    let (token, _, _) = deploy_token();
    cheat_caller_address(token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    game_fee_of(token).set_game_fee_recipient(addr(0));
}

#[test]
#[should_panic(expected: "MinigameToken: Fee numerator exceeds denominator")]
fn test_fee_above_denominator_rejected() {
    let (token, _, _) = deploy_token();
    cheat_caller_address(token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    game_fee_of(token).set_game_fee("too greedy", FEE_DENOMINATOR + 1);
}

#[test]
fn test_zero_recipient_deploy_rejected() {
    let contract = declare("StandardGameMock").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "StandardToken";
    let symbol: ByteArray = "STD";
    let base_uri: ByteArray = "https://token.test/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    addr(0).serialize(ref calldata);
    OWNER().serialize(ref calldata);
    assert!(contract.deploy(@calldata).is_err(), "Zero recipient must fail the constructor");
}
