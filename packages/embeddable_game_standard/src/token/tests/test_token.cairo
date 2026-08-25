use game_components_interfaces::structs::metagame::{GameContext, GameContextDetails};
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
    cheat_caller_address, declare, mock_call, spy_events, start_cheat_block_timestamp,
    start_cheat_transaction_hash,
};
use starknet::ContractAddress;
use crate::token::interface::{
    IMINIGAME_TOKEN_ID, IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use crate::token::minigame_token_component::MinigameTokenComponent;
use crate::token::packing::{
    unpack_end_delay, unpack_has_context, unpack_metadata, unpack_minted_at, unpack_minted_by,
    unpack_objective_id, unpack_paymaster, unpack_salt, unpack_settings_id, unpack_soulbound,
    unpack_start_delay, unpack_token_id, unpack_tx_hash,
};
use crate::token_legacy::interface::IMINIGAME_TOKEN_LEGACY_ID;
use crate::token_legacy::structs::MintBatchRecipient;

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

/// Mint with the restored 12-arg shape, neutral values for the params a test
/// is not exercising (no objective/context/client_url, no paymaster, zero
/// metadata). There is still no game address — the token IS the game.
fn mint_basic(
    token: IMinigameTokenDispatcher,
    player_name: Option<felt252>,
    settings_id: Option<u32>,
    start: Option<u64>,
    end: Option<u64>,
    to: ContractAddress,
    soulbound: bool,
    salt: u16,
) -> felt252 {
    token
        .mint(
            player_name,
            settings_id,
            start,
            end,
            Option::None,
            Option::None,
            Option::None,
            to,
            soulbound,
            false,
            salt,
            0,
        )
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
    // SRC5 is honest: a standard token does NOT implement IMinigameTokenLegacy and no
    // longer advertises the legacy token id.
    assert!(
        !src5.supports_interface(IMINIGAME_TOKEN_LEGACY_ID),
        "Must NOT advertise the legacy token id",
    );
}

// ================================================================================================
// MINT — PACKED FIELDS
// ================================================================================================

#[test]
fn test_mint_packs_expected_fields() {
    let (token, erc721, minter) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);

    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let token_id = mint_basic(
        token,
        Option::Some('alice'),
        Option::Some(42),
        Option::Some(2000),
        Option::Some(3000),
        ALICE(),
        true,
        7,
    );

    let packed = unpack_token_id(token_id);
    assert!(packed.settings_id == 42, "settings_id mismatch");
    assert!(packed.minted_at == 1000, "minted_at mismatch");
    assert!(packed.start_delay == 1000, "start_delay mismatch");
    assert!(packed.end_delay == 1000, "end_delay mismatch");
    assert!(packed.soulbound, "soulbound flag should be set");
    assert!(packed.minted_by == 1, "First minter should pack id 1");
    assert!(packed.salt == 7, "salt mismatch");

    // The high half is fully allocated (no reserved region); with the
    // restored params neutral, everything above salt's top bit must be zero.
    let raw: u256 = token_id.into();
    assert!(raw.high / 0x4000000 == 0, "neutral restored fields must decode as zero"); // 2^26

    // Views resolve from the packed id / minter map
    assert!(token.settings_id(token_id) == 42, "settings_id view mismatch");
    assert!(token.is_soulbound(token_id), "is_soulbound view mismatch");
    assert!(token.player_name(token_id) == 'alice', "player_name mismatch");
    assert!(token.minted_by(token_id) == 1, "First minter should get id 1");
    assert!(token.minted_by_address(token_id) == MINTER(), "minted_by_address mismatch");
    assert!(minter.get_minter_address(1) == MINTER(), "Minter registry mismatch");
    assert!(erc721.owner_of(token_id.into()) == ALICE(), "Owner mismatch");
}

#[test]
fn test_mint_defaults_and_metadata_view() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);

    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );

    let metadata = token.token_metadata(token_id);
    assert!(metadata.game_id == 0, "game_id should be 0");
    assert!(metadata.settings_id == 0, "settings_id should default 0");
    assert!(metadata.minted_at == 1000, "minted_at mismatch");
    assert!(metadata.lifecycle.start == 1000, "start clamps to mint time");
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
    assert!(metadata.metadata == 0, "u16 metadata field is always 0 (see mint_metadata)");
    assert!(token.objective_id(token_id) == 0, "objective_id view defaults to 0");
    assert!(token.mint_metadata(token_id) == 0, "mint_metadata defaults to 0");
    assert!(token.client_url(token_id) == "", "client_url defaults to empty");
    assert!(token.player_name(token_id) == 0, "No player name set");
}

#[test]
fn test_mint_past_start_clamps_to_now() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);

    let token_id = mint_basic(
        token, Option::None, Option::None, Option::Some(500), Option::Some(2000), ALICE(), false, 0,
    );

    let metadata = token.token_metadata(token_id);
    assert!(metadata.lifecycle.start == 1000, "Past start should clamp to mint time");
    assert!(metadata.lifecycle.end == 2000, "End must reconstruct to the caller's value");
}

#[test]
fn test_mint_unique_ids_by_salt_and_minter() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);

    // Same params, same block, same caller — salt must disambiguate
    let id_a = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    let id_b = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 1,
    );
    assert!(id_a != id_b, "Salt must produce distinct token ids");

    // Second distinct caller gets minter id 2
    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let id_c = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    assert!(token.minted_by(id_c) == 2, "Second minter should get id 2");
    // Repeat caller keeps its id
    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let id_d = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 1,
    );
    assert!(token.minted_by(id_d) == 2, "Repeat minter keeps id");
}

// ================================================================================================
// MINT — LIFECYCLE VALIDATION
// ================================================================================================

#[test]
#[should_panic(expected: "MinigameToken: Lifecycle end must be in the future and after start")]
fn test_mint_rejects_past_end() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    mint_basic(
        token, Option::None, Option::None, Option::None, Option::Some(900), ALICE(), false, 0,
    );
}

#[test]
#[should_panic(expected: "Lifecycle: Start time cannot be greater than end time")]
fn test_mint_rejects_start_after_end() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    mint_basic(
        token,
        Option::None,
        Option::None,
        Option::Some(3000),
        Option::Some(2000),
        ALICE(),
        false,
        0,
    );
}

// ================================================================================================
// PLAYABILITY — LIFECYCLE WINDOW ONLY
// ================================================================================================

#[test]
fn test_playability_follows_lifecycle_window() {
    let (token, _, _) = deploy_token();
    let game = game_of(token);
    start_cheat_block_timestamp(token.contract_address, 1000);

    let token_id = mint_basic(
        token,
        Option::None,
        Option::None,
        Option::Some(2000),
        Option::Some(3000),
        ALICE(),
        false,
        0,
    );

    assert!(!token.is_playable(token_id), "Not playable before window opens");

    start_cheat_block_timestamp(token.contract_address, 2000);
    assert!(token.is_playable(token_id), "Playable at window start");
    // The embedding game's internal pre-action guard agrees with the view
    game.assert_owner_and_playable(token_id, ALICE());

    start_cheat_block_timestamp(token.contract_address, 3000);
    assert!(!token.is_playable(token_id), "Expired at window end");
}

#[test]
fn test_immortal_token_always_playable() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    start_cheat_block_timestamp(token.contract_address, 99999999);
    assert!(token.is_playable(token_id), "No end means playable forever");
}

// ================================================================================================
// INTERNAL GUARD (assert_owner_and_playable — via the embedding game mock)
// ================================================================================================

#[test]
#[should_panic(expected: "MinigameToken: Token is not playable - game has expired")]
fn test_guard_panics_after_expiry() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::Some(2000), ALICE(), false, 0,
    );
    start_cheat_block_timestamp(token.contract_address, 2000);
    game_of(token).assert_owner_and_playable(token_id, ALICE());
}

#[test]
#[should_panic(expected: "MinigameToken: Token is not playable - game has not started")]
fn test_guard_panics_before_start() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    let token_id = mint_basic(
        token,
        Option::None,
        Option::None,
        Option::Some(2000),
        Option::Some(3000),
        ALICE(),
        false,
        0,
    );
    game_of(token).assert_owner_and_playable(token_id, ALICE());
}

#[test]
#[should_panic(expected: "MinigameToken: Address is not owner of token")]
fn test_guard_rejects_wrong_owner() {
    let (token, _, _) = deploy_token();
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
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
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    game_of(token).assert_owner_and_playable(token_id, addr(0));
}

// ================================================================================================
// SOULBOUND
// ================================================================================================

#[test]
#[should_panic(expected: "Token is soulbound and cannot be transferred")]
fn test_soulbound_transfer_blocked() {
    let (token, erc721, _) = deploy_token();
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), true, 0,
    );
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721.transfer_from(ALICE(), BOB(), token_id.into());
}

#[test]
fn test_non_soulbound_transfer_allowed() {
    let (token, erc721, _) = deploy_token();
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
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
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );

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
fn test_update_player_name_by_owner() {
    let (token, _, _) = deploy_token();
    let token_id = mint_basic(
        token, Option::Some('old'), Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    token.update_player_name(token_id, 'new');
    assert!(token.player_name(token_id) == 'new', "Player name should update");
}

#[test]
#[should_panic(expected: "MinigameToken: Caller is not owner of token")]
fn test_update_player_name_rejects_non_owner() {
    let (token, _, _) = deploy_token();
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    cheat_caller_address(token.contract_address, BOB(), CheatSpan::TargetCalls(1));
    token.update_player_name(token_id, 'new');
}

// ================================================================================================
// BATCH MINT
// ================================================================================================

fn batch_neutral(
    token: IMinigameTokenDispatcher, recipients: Array<MintBatchRecipient>, salt: u16,
) -> Array<felt252> {
    token
        .mint_batch_recipients(
            Option::Some('bench'),
            Option::Some(5),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipients,
            false,
            false,
            salt,
            0,
        )
}

#[test]
fn test_mint_batch_recipients_counts_owners_and_salts() {
    let (token, erc721, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);

    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let ids = batch_neutral(
        token,
        array![
            MintBatchRecipient { to: ALICE(), count: 2 },
            MintBatchRecipient { to: BOB(), count: 1 },
        ],
        7,
    );

    assert!(ids.len() == 3, "Should mint 3 tokens");
    let id_a = *ids.at(0);
    let id_b = *ids.at(1);
    let id_c = *ids.at(2);
    assert!(id_a != id_b && id_b != id_c && id_a != id_c, "Token ids must be distinct");
    assert!(erc721.owner_of(id_a.into()) == ALICE(), "First token to ALICE");
    assert!(erc721.owner_of(id_b.into()) == ALICE(), "Second token to ALICE");
    assert!(erc721.owner_of(id_c.into()) == BOB(), "Third token to BOB");

    // Global salt counter across the batch, minter registered once
    assert!(unpack_salt(id_a) == 7 && unpack_salt(id_b) == 8 && unpack_salt(id_c) == 9, "salts");
    let mut i: u32 = 0;
    while i < ids.len() {
        let id = *ids.at(i);
        assert!(token.minted_by(id) == 1, "All share minter id 1");
        assert!(token.settings_id(id) == 5, "Shared settings id");
        assert!(token.player_name(id) == 'bench', "Shared player name");
        i += 1;
    }
}

#[test]
#[should_panic(expected: "MinigameToken: salt overflow (salt + total tokens - 1 must be <= 65535)")]
fn test_mint_batch_recipients_rejects_salt_overflow() {
    let (token, _, _) = deploy_token();
    // 65533 + 4 - 1 = 65536 > 0xFFFF — one past the 16-bit salt field.
    batch_neutral(token, array![MintBatchRecipient { to: ALICE(), count: 4 }], 65533);
}

#[test]
fn test_mint_batch_recipients_salt_at_16_bit_boundary() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    // 65533 + 3 - 1 = 65535 == 0xFFFF — exactly fills the widened 16-bit
    // field (would have overflowed the legacy token's 10-bit salt long ago).
    let ids = batch_neutral(token, array![MintBatchRecipient { to: ALICE(), count: 3 }], 65533);
    assert!(ids.len() == 3, "Should mint 3 tokens");
    assert!(unpack_salt(*ids.at(0)) == 65533, "first salt");
    assert!(unpack_salt(*ids.at(2)) == 0xFFFF, "last salt fills the 16-bit field");
}

#[test]
#[should_panic(expected: "MinigameToken: recipients array cannot be empty")]
fn test_mint_batch_recipients_rejects_empty() {
    let (token, _, _) = deploy_token();
    batch_neutral(token, array![], 0);
}

#[test]
#[should_panic(expected: "MinigameToken: per-recipient count must be > 0")]
fn test_mint_batch_recipients_rejects_zero_count() {
    let (token, _, _) = deploy_token();
    batch_neutral(token, array![MintBatchRecipient { to: ALICE(), count: 0 }], 0);
}

// ================================================================================================
// ECOSYSTEM INTEGRATION (metagame assert_game_registered)
// ================================================================================================

/// Positive path: `assert_game_registered` now probes the token's SRC5 for
/// `IMINIGAME_TOKEN_ID` first (standard tokens expose no registry views). A
/// self-bound standard deployment IS its own game: `token_address()` returns
/// itself, the standard id matches, and the check reduces to a trivially-true
/// address equality.
#[test]
fn test_assert_game_registered_accepts_self_bound_game() {
    let (token, _, _) = deploy_token();
    crate::metagame::metagame::assert_game_registered(token.contract_address);
}

/// Negative path: a game whose `token_address()` points at some OTHER standard
/// token is not a valid pairing — self-binding means the only accepted answer
/// is the game's own address. A second StandardGameMock cannot express this
/// misconfiguration (it always returns itself), so the fake game is a mocked
/// address pointing at a real standard deployment: the SRC5 probe finds the
/// id for real, then the address equality fake_game == token fails.
#[test]
#[should_panic(expected: "Game is not registered")]
fn test_assert_game_registered_rejects_game_not_paired_with_standard_token() {
    let (token, _, _) = deploy_token();

    let fake_game = addr('FAKE_GAME');
    mock_call(fake_game, selector!("token_address"), token.contract_address, 1);
    crate::metagame::metagame::assert_game_registered(fake_game);
}

// ================================================================================================
// PACKING — LAYOUT AND HELPERS
// ================================================================================================

#[test]
fn test_helper_unpackers_agree_with_full_unpack() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1234);
    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let token_id = mint_basic(
        token, Option::None, Option::Some(9), Option::None, Option::Some(9999), ALICE(), true, 3,
    );

    // Token ids use the standard 251-bit layout, so the standalone helper
    // unpackers (what game/dungeon contracts use on their side) must agree
    // with the full unpack.
    let packed = unpack_token_id(token_id);
    assert!(unpack_minted_at(token_id) == packed.minted_at, "minted_at helper mismatch");
    assert!(unpack_start_delay(token_id) == packed.start_delay, "start_delay helper mismatch");
    assert!(unpack_end_delay(token_id) == packed.end_delay, "end_delay helper mismatch");
    assert!(unpack_settings_id(token_id) == packed.settings_id, "settings_id helper mismatch");
    assert!(unpack_minted_by(token_id) == packed.minted_by, "minted_by helper mismatch");
    assert!(unpack_soulbound(token_id) == packed.soulbound, "soulbound helper mismatch");
    assert!(unpack_tx_hash(token_id) == packed.tx_hash, "tx_hash helper mismatch");
    assert!(unpack_salt(token_id) == packed.salt, "salt helper mismatch");
    assert!(unpack_paymaster(token_id) == packed.paymaster, "paymaster helper mismatch");
    assert!(unpack_has_context(token_id) == packed.has_context, "has_context helper mismatch");
    assert!(unpack_objective_id(token_id) == packed.objective_id, "objective_id helper mismatch");
    assert!(unpack_metadata(token_id) == packed.metadata, "metadata helper mismatch");
    assert!(packed.minted_at == 1234 && packed.settings_id == 9, "field values");
    assert!(packed.soulbound && packed.salt == 3 && packed.minted_by == 1, "field values");
}

/// Bit-exact layout proof: with every input pinned (including the tx hash),
/// the minted id must equal the arithmetic reconstruction of the documented
/// id layout — low: minted_at | start_delay<<35 | end_delay<<60 |
/// settings_id<<85 | minted_by<<101 | soulbound<<127; high: tx_hash |
/// salt<<10 | paymaster<<26 | has_context<<27 | objective_id<<28 |
/// metadata<<58. The high half is fully allocated — no reserved region.
#[test]
fn test_layout_bit_positions_exact() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    start_cheat_transaction_hash(token.contract_address, 0x123456789abcdef);
    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));

    let token_id = token
        .mint(
            Option::None,
            Option::Some(0xABCD),
            Option::Some(2000),
            Option::Some(5000),
            Option::Some(0x1ABCDE),
            Option::Some(sample_context()),
            Option::None,
            ALICE(),
            true,
            true,
            0x1234,
            0x123456789ABCD,
        );

    // minted_at=1000, start_delay=1000, end_delay=3000, settings_id=0xABCD,
    // minted_by=1 (first minter), soulbound=1, tx_hash=0x1ef (last 10 bits
    // of 0x...cdef), salt=0x1234, paymaster=1, has_context=1 (context
    // supplied), objective_id=0x1ABCDE, metadata=0x123456789ABCD.
    let expected_low: u128 = 1000
        + 1000 * 0x800000000 // start_delay << 35
        + 3000 * 0x1000000000000000 // end_delay << 60
        + 0xABCD * 0x2000000000000000000000 // settings_id << 85
        + 1 * 0x20000000000000000000000000 // minted_by << 101
        + 0x80000000000000000000000000000000; // soulbound << 127
    let expected_high: u128 = 0x1ef
        + 0x1234 * 0x400 // salt << 10
        + 0x4000000 // paymaster << 26
        + 0x8000000 // has_context << 27
        + 0x1ABCDE * 0x10000000 // objective_id << 28
        + 0x123456789ABCD * 0x400000000000000; // metadata << 58
    let expected: felt252 = u256 { low: expected_low, high: expected_high }.try_into().unwrap();
    assert!(token_id == expected, "id layout bit positions must match the documented table");
}

#[test]
fn test_mint_accepts_settings_id_at_16_bit_boundary() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    let token_id = mint_basic(
        token, Option::None, Option::Some(0xFFFF), Option::None, Option::None, ALICE(), false, 0,
    );
    assert!(token.settings_id(token_id) == 0xFFFF, "boundary settings_id roundtrip");
}

#[test]
#[should_panic(expected: "PackedTokenId: settings_id exceeds 16-bit limit")]
fn test_mint_rejects_settings_id_over_16_bits() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    // 0x10000 fit the legacy token's 30-bit field but exceeds the standard 16-bit
    // field — must now be rejected at mint.
    mint_basic(
        token, Option::None, Option::Some(0x10000), Option::None, Option::None, ALICE(), false, 0,
    );
}

// ================================================================================================
// RESTORED MINT PARAMS — objective_id / context / client_url / paymaster / metadata
// ================================================================================================

/// Mint helper that exercises exactly the restored params, neutral elsewhere.
fn mint_restored(
    token: IMinigameTokenDispatcher,
    objective_id: Option<u32>,
    context: Option<GameContextDetails>,
    client_url: Option<ByteArray>,
    paymaster: bool,
    salt: u16,
    metadata: u128,
) -> felt252 {
    token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            objective_id,
            context,
            client_url,
            ALICE(),
            false,
            paymaster,
            salt,
            metadata,
        )
}

/// The restored packed fields roundtrip through mint: id bits, standalone
/// helpers, ABI views and the shared TokenMetadata struct all agree.
#[test]
fn test_mint_restored_fields_roundtrip() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);

    let token_id = mint_restored(
        token,
        Option::Some(123456),
        Option::Some(sample_context()),
        Option::None,
        true,
        0,
        0xDEADBEEFCAFE,
    );

    let packed = unpack_token_id(token_id);
    assert!(packed.objective_id == 123456, "objective_id pack mismatch");
    assert!(packed.has_context, "has_context bit should be set");
    assert!(packed.paymaster, "paymaster bit should be set");
    assert!(packed.metadata == 0xDEADBEEFCAFE, "metadata pack mismatch");

    // ABI views
    assert!(token.objective_id(token_id) == 123456, "objective_id view mismatch");
    assert!(token.mint_metadata(token_id) == 0xDEADBEEFCAFE, "mint_metadata view mismatch");

    // Shared TokenMetadata struct: objective_id/has_context/paymaster are
    // populated from the id; the u16 metadata field CANNOT hold the 65-bit
    // value and stays 0 (never truncated) — mint_metadata is the real view.
    // objective_id is inert data the game interprets: the standard token has no
    // completion machinery, so completed_objective stays false.
    let md = token.token_metadata(token_id);
    assert!(md.objective_id == 123456, "TokenMetadata.objective_id mismatch");
    assert!(md.has_context, "TokenMetadata.has_context mismatch");
    assert!(md.paymaster, "TokenMetadata.paymaster mismatch");
    assert!(md.metadata == 0, "TokenMetadata.metadata must be 0, not a truncation");
    assert!(!md.completed_objective, "completed_objective stays always-false");
}

#[test]
fn test_mint_accepts_field_boundaries() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);

    // Every restored field at its maximum: objective_id 2^30-1, metadata
    // 2^65-1 (filling the high half's topmost bit — the layout has no
    // reserved region), both flag bits set, salt filling its 16 bits.
    let token_id = mint_restored(
        token,
        Option::Some(0x3FFFFFFF),
        Option::Some(sample_context()),
        Option::None,
        true,
        0xFFFF,
        0x1FFFFFFFFFFFFFFFF,
    );
    assert!(token.objective_id(token_id) == 0x3FFFFFFF, "boundary objective_id roundtrip");
    assert!(token.mint_metadata(token_id) == 0x1FFFFFFFFFFFFFFFF, "boundary metadata roundtrip");

    // metadata is the topmost high field: with it maxed, the quotient above
    // objective_id's top bit must be exactly the metadata value — nothing
    // sits above it.
    let raw: u256 = token_id.into();
    assert!(
        raw.high / 0x400000000000000 == 0x1FFFFFFFFFFFFFFFF,
        "metadata occupies the entire top of the high half",
    ); // 2^58
}

#[test]
#[should_panic(expected: "PackedTokenId: objective_id exceeds 30-bit limit")]
fn test_mint_rejects_objective_id_over_30_bits() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    // 2^30 — one past the 30-bit field.
    mint_restored(token, Option::Some(0x40000000), Option::None, Option::None, false, 0, 0);
}

#[test]
#[should_panic(expected: "PackedTokenId: metadata exceeds 65-bit limit")]
fn test_mint_rejects_metadata_over_65_bits() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);
    // 2^65 — one past the 65-bit field.
    mint_restored(token, Option::None, Option::None, Option::None, false, 0, 0x20000000000000000);
}

/// client_url is storage-backed exactly as on the legacy token: written when
/// Some, readable via the view, empty ByteArray default when absent.
#[test]
fn test_client_url_stored_and_empty_default() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);

    let with_url = mint_restored(
        token, Option::None, Option::None, Option::Some("https://play.example/game"), false, 0, 0,
    );
    assert!(token.client_url(with_url) == "https://play.example/game", "client_url view mismatch");

    let without_url = mint_restored(token, Option::None, Option::None, Option::None, false, 1, 0);
    assert!(token.client_url(without_url) == "", "client_url should default to empty");
}

/// context sets the id's has_context bit only — the data itself is NOT stored
/// (legacy-token parity: its context hook was a documented no-op and token_uri
/// sourced context from the minter at render time).
#[test]
fn test_context_sets_has_context_bit_without_storage() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);

    let with_context = mint_restored(
        token, Option::None, Option::Some(sample_context()), Option::None, false, 0, 0,
    );
    assert!(unpack_has_context(with_context), "has_context bit must be set");
    assert!(token.token_metadata(with_context).has_context, "metadata view agrees");
    // Nothing context-shaped was persisted: the only storage-backed views
    // stay at their defaults.
    assert!(token.client_url(with_context) == "", "no context data lands in storage");
    assert!(token.player_name(with_context) == 0, "no context data lands in storage");

    let without_context = mint_restored(
        token, Option::None, Option::None, Option::None, false, 1, 0,
    );
    assert!(!unpack_has_context(without_context), "has_context bit must be clear");
}

/// Batch mints share the packed fields (has_context bit, objective, paymaster,
/// metadata) across all tokens, and the client_url — when Some — is written
/// per token.
#[test]
fn test_mint_batch_shares_restored_fields_and_url() {
    let (token, _, _) = deploy_token();
    start_cheat_block_timestamp(token.contract_address, 1000);

    let ids = token
        .mint_batch_recipients(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(77),
            Option::Some(sample_context()),
            Option::Some("https://play.example/batch"),
            array![
                MintBatchRecipient { to: ALICE(), count: 2 },
                MintBatchRecipient { to: BOB(), count: 1 },
            ],
            false,
            true,
            0,
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
        assert!(token.client_url(id) == "https://play.example/batch", "url written per token");
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
