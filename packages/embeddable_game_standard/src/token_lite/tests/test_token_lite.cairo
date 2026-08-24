use game_components_test_common::mocks::lite_game_mock::{
    ILiteGameMockDispatcher, ILiteGameMockDispatcherTrait,
};
use openzeppelin_interfaces::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_caller_address, declare, mock_call, spy_events, start_cheat_block_timestamp,
    start_cheat_transaction_hash,
};
use starknet::ContractAddress;
use crate::token::extensions::minter::interface::{
    IMinigameTokenMinterDispatcher, IMinigameTokenMinterDispatcherTrait,
};
use crate::token::interface::IMINIGAME_TOKEN_ID;
use crate::token::structs::MintBatchRecipient;
use crate::token_lite::interface::{
    IMINIGAME_TOKEN_LITE_ID, IMinigameTokenLiteDispatcher, IMinigameTokenLiteDispatcherTrait,
};
use crate::token_lite::packing::{
    unpack_end_delay, unpack_lite_token_id, unpack_minted_at, unpack_minted_by, unpack_salt,
    unpack_settings_id, unpack_soulbound, unpack_start_delay, unpack_tx_hash,
};
use crate::token_lite::token_lite_component::CoreTokenLiteComponent;

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

/// Deploys ONE contract that is both the game and the token — the only
/// supported shape: the lite component is self-binding.
fn deploy_token_lite() -> (
    IMinigameTokenLiteDispatcher, ERC721ABIDispatcher, IMinigameTokenMinterDispatcher,
) {
    let contract = declare("LiteGameMock").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "LiteToken";
    let symbol: ByteArray = "LITE";
    let base_uri: ByteArray = "https://lite.test/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    (
        IMinigameTokenLiteDispatcher { contract_address },
        ERC721ABIDispatcher { contract_address },
        IMinigameTokenMinterDispatcher { contract_address },
    )
}

/// The embedding game's view of the same contract — used to exercise the
/// component's internal pre-action guard (`assert_owner_and_playable` moved
/// off the external ABI; the mock re-exposes it the way a real game consumes
/// it inside its entrypoints).
fn game_of(token: IMinigameTokenLiteDispatcher) -> ILiteGameMockDispatcher {
    ILiteGameMockDispatcher { contract_address: token.contract_address }
}

/// Mint with the trimmed 7-arg shape — no game address (the token IS the
/// game), none of the full token's dead parameters.
fn mint_basic(
    token: IMinigameTokenLiteDispatcher,
    player_name: Option<felt252>,
    settings_id: Option<u32>,
    start: Option<u64>,
    end: Option<u64>,
    to: ContractAddress,
    soulbound: bool,
    salt: u16,
) -> felt252 {
    token.mint(player_name, settings_id, start, end, to, soulbound, salt)
}

// ================================================================================================
// DEPLOYMENT / INTERFACE REGISTRATION
// ================================================================================================

#[test]
fn test_deployment_and_interfaces() {
    let (token, erc721, _) = deploy_token_lite();

    assert!(erc721.name() == "LiteToken", "Name mismatch");
    assert!(erc721.symbol() == "LITE", "Symbol mismatch");

    let src5 = ISRC5Dispatcher { contract_address: token.contract_address };
    assert!(src5.supports_interface(IMINIGAME_TOKEN_LITE_ID), "Should register lite interface id");
    // SRC5 is honest: a lite token does NOT implement IMinigameToken and no
    // longer advertises the legacy full-token id.
    assert!(!src5.supports_interface(IMINIGAME_TOKEN_ID), "Must NOT advertise the full token id");
}

// ================================================================================================
// MINT — PACKED FIELDS
// ================================================================================================

#[test]
fn test_mint_packs_expected_fields() {
    let (token, erc721, minter) = deploy_token_lite();
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

    let packed = unpack_lite_token_id(token_id);
    assert!(packed.settings_id == 42, "settings_id mismatch");
    assert!(packed.minted_at == 1000, "minted_at mismatch");
    assert!(packed.start_delay == 1000, "start_delay mismatch");
    assert!(packed.end_delay == 1000, "end_delay mismatch");
    assert!(packed.soulbound, "soulbound flag should be set");
    assert!(packed.minted_by == 1, "First minter should pack id 1");
    assert!(packed.salt == 7, "salt mismatch");

    // Reserved region (high bits 26-122) is component-owned and must be
    // provably zero on every minted id: only tx_hash(10) + salt(16) occupy
    // the high half.
    let raw: u256 = token_id.into();
    assert!(raw.high / 0x4000000 == 0, "reserved bits must be zero"); // 2^26

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
    let (token, _, _) = deploy_token_lite();
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
    assert!(token.player_name(token_id) == 0, "No player name set");
}

#[test]
fn test_mint_past_start_clamps_to_now() {
    let (token, _, _) = deploy_token_lite();
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
    let (token, _, _) = deploy_token_lite();
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
#[should_panic(expected: "MinigameTokenLite: Lifecycle end must be in the future and after start")]
fn test_mint_rejects_past_end() {
    let (token, _, _) = deploy_token_lite();
    start_cheat_block_timestamp(token.contract_address, 1000);
    mint_basic(
        token, Option::None, Option::None, Option::None, Option::Some(900), ALICE(), false, 0,
    );
}

#[test]
#[should_panic(expected: "Lifecycle: Start time cannot be greater than end time")]
fn test_mint_rejects_start_after_end() {
    let (token, _, _) = deploy_token_lite();
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
    let (token, _, _) = deploy_token_lite();
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
    let (token, _, _) = deploy_token_lite();
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
#[should_panic(expected: "MinigameTokenLite: Token is not playable - game has expired")]
fn test_guard_panics_after_expiry() {
    let (token, _, _) = deploy_token_lite();
    start_cheat_block_timestamp(token.contract_address, 1000);
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::Some(2000), ALICE(), false, 0,
    );
    start_cheat_block_timestamp(token.contract_address, 2000);
    game_of(token).assert_owner_and_playable(token_id, ALICE());
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Token is not playable - game has not started")]
fn test_guard_panics_before_start() {
    let (token, _, _) = deploy_token_lite();
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
#[should_panic(expected: "MinigameTokenLite: Address is not owner of token")]
fn test_guard_rejects_wrong_owner() {
    let (token, _, _) = deploy_token_lite();
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    game_of(token).assert_owner_and_playable(token_id, BOB());
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Address is not owner of token")]
fn test_guard_rejects_nonexistent_token() {
    let (token, _, _) = deploy_token_lite();
    game_of(token).assert_owner_and_playable(12345, ALICE());
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Expected owner cannot be zero")]
fn test_guard_rejects_zero_owner() {
    let (token, _, _) = deploy_token_lite();
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
    let (token, erc721, _) = deploy_token_lite();
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), true, 0,
    );
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721.transfer_from(ALICE(), BOB(), token_id.into());
}

#[test]
fn test_non_soulbound_transfer_allowed() {
    let (token, erc721, _) = deploy_token_lite();
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
    let (token, _, _) = deploy_token_lite();
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
                    CoreTokenLiteComponent::Event::MetadataUpdate(
                        CoreTokenLiteComponent::MetadataUpdate { token_id: token_id.into() },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_player_name_by_owner() {
    let (token, _, _) = deploy_token_lite();
    let token_id = mint_basic(
        token, Option::Some('old'), Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    token.update_player_name(token_id, 'new');
    assert!(token.player_name(token_id) == 'new', "Player name should update");
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Caller is not owner of token")]
fn test_update_player_name_rejects_non_owner() {
    let (token, _, _) = deploy_token_lite();
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
    token: IMinigameTokenLiteDispatcher, recipients: Array<MintBatchRecipient>, salt: u16,
) -> Array<felt252> {
    token
        .mint_batch_recipients(
            Option::Some('bench'),
            Option::Some(5),
            Option::None,
            Option::None,
            recipients,
            false,
            salt,
        )
}

#[test]
fn test_mint_batch_recipients_counts_owners_and_salts() {
    let (token, erc721, _) = deploy_token_lite();
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
#[should_panic(
    expected: "MinigameTokenLite: salt overflow (salt + total tokens - 1 must be <= 65535)",
)]
fn test_mint_batch_recipients_rejects_salt_overflow() {
    let (token, _, _) = deploy_token_lite();
    // 65533 + 4 - 1 = 65536 > 0xFFFF — one past the 16-bit salt field.
    batch_neutral(token, array![MintBatchRecipient { to: ALICE(), count: 4 }], 65533);
}

#[test]
fn test_mint_batch_recipients_salt_at_16_bit_boundary() {
    let (token, _, _) = deploy_token_lite();
    start_cheat_block_timestamp(token.contract_address, 1000);
    // 65533 + 3 - 1 = 65535 == 0xFFFF — exactly fills the widened 16-bit
    // field (would have overflowed the full token's 10-bit salt long ago).
    let ids = batch_neutral(token, array![MintBatchRecipient { to: ALICE(), count: 3 }], 65533);
    assert!(ids.len() == 3, "Should mint 3 tokens");
    assert!(unpack_salt(*ids.at(0)) == 65533, "first salt");
    assert!(unpack_salt(*ids.at(2)) == 0xFFFF, "last salt fills the 16-bit field");
}

#[test]
#[should_panic(expected: "MinigameTokenLite: recipients array cannot be empty")]
fn test_mint_batch_recipients_rejects_empty() {
    let (token, _, _) = deploy_token_lite();
    batch_neutral(token, array![], 0);
}

#[test]
#[should_panic(expected: "MinigameTokenLite: per-recipient count must be > 0")]
fn test_mint_batch_recipients_rejects_zero_count() {
    let (token, _, _) = deploy_token_lite();
    batch_neutral(token, array![MintBatchRecipient { to: ALICE(), count: 0 }], 0);
}

// ================================================================================================
// ECOSYSTEM INTEGRATION (metagame assert_game_registered)
// ================================================================================================

/// Positive path: `assert_game_registered` now probes the token's SRC5 for
/// `IMINIGAME_TOKEN_LITE_ID` first (lite tokens expose no registry views). A
/// self-bound lite deployment IS its own game: `token_address()` returns
/// itself, the lite id matches, and the check reduces to a trivially-true
/// address equality.
#[test]
fn test_assert_game_registered_accepts_self_bound_lite_game() {
    let (token, _, _) = deploy_token_lite();
    crate::metagame::metagame::assert_game_registered(token.contract_address);
}

/// Negative path: a game whose `token_address()` points at some OTHER lite
/// token is not a valid pairing — self-binding means the only accepted answer
/// is the game's own address. A second LiteGameMock cannot express this
/// misconfiguration (it always returns itself), so the fake game is a mocked
/// address pointing at a real lite deployment: the SRC5 probe finds the lite
/// id for real, then the address equality fake_game == token fails.
#[test]
#[should_panic(expected: "Game is not registered")]
fn test_assert_game_registered_rejects_game_not_paired_with_lite_token() {
    let (token, _, _) = deploy_token_lite();

    let fake_game = addr('FAKE_GAME');
    mock_call(fake_game, selector!("token_address"), token.contract_address, 1);
    crate::metagame::metagame::assert_game_registered(fake_game);
}

// ================================================================================================
// LITE PACKING — LAYOUT AND HELPERS
// ================================================================================================

#[test]
fn test_helper_unpackers_agree_with_full_unpack() {
    let (token, _, _) = deploy_token_lite();
    start_cheat_block_timestamp(token.contract_address, 1234);
    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));
    let token_id = mint_basic(
        token, Option::None, Option::Some(9), Option::None, Option::Some(9999), ALICE(), true, 3,
    );

    // Token ids use the lite-native 251-bit layout, so the standalone helper
    // unpackers (what game/dungeon contracts use on their side) must agree
    // with the full unpack.
    let packed = unpack_lite_token_id(token_id);
    assert!(unpack_minted_at(token_id) == packed.minted_at, "minted_at helper mismatch");
    assert!(unpack_start_delay(token_id) == packed.start_delay, "start_delay helper mismatch");
    assert!(unpack_end_delay(token_id) == packed.end_delay, "end_delay helper mismatch");
    assert!(unpack_settings_id(token_id) == packed.settings_id, "settings_id helper mismatch");
    assert!(unpack_minted_by(token_id) == packed.minted_by, "minted_by helper mismatch");
    assert!(unpack_soulbound(token_id) == packed.soulbound, "soulbound helper mismatch");
    assert!(unpack_tx_hash(token_id) == packed.tx_hash, "tx_hash helper mismatch");
    assert!(unpack_salt(token_id) == packed.salt, "salt helper mismatch");
    assert!(packed.minted_at == 1234 && packed.settings_id == 9, "field values");
    assert!(packed.soulbound && packed.salt == 3 && packed.minted_by == 1, "field values");
}

/// Bit-exact layout proof: with every input pinned (including the tx hash),
/// the minted id must equal the arithmetic reconstruction of the documented
/// lite layout — low: minted_at | start_delay<<35 | end_delay<<60 |
/// settings_id<<85 | minted_by<<101 | soulbound<<127; high: tx_hash | salt<<10;
/// reserved bits [26-122] of the high half all zero.
#[test]
fn test_lite_layout_bit_positions_exact() {
    let (token, _, _) = deploy_token_lite();
    start_cheat_block_timestamp(token.contract_address, 1000);
    start_cheat_transaction_hash(token.contract_address, 0x123456789abcdef);
    cheat_caller_address(token.contract_address, MINTER(), CheatSpan::TargetCalls(1));

    let token_id = mint_basic(
        token,
        Option::None,
        Option::Some(0xABCD),
        Option::Some(2000),
        Option::Some(5000),
        ALICE(),
        true,
        0x1234,
    );

    // minted_at=1000, start_delay=1000, end_delay=3000, settings_id=0xABCD,
    // minted_by=1 (first minter), soulbound=1, tx_hash=0x1ef (last 10 bits
    // of 0x...cdef), salt=0x1234.
    let expected_low: u128 = 1000
        + 1000 * 0x800000000 // start_delay << 35
        + 3000 * 0x1000000000000000 // end_delay << 60
        + 0xABCD * 0x2000000000000000000000 // settings_id << 85
        + 1 * 0x20000000000000000000000000 // minted_by << 101
        + 0x80000000000000000000000000000000; // soulbound << 127
    let expected_high: u128 = 0x1ef + 0x1234 * 0x400; // tx_hash | salt << 10
    let expected: felt252 = u256 { low: expected_low, high: expected_high }.try_into().unwrap();
    assert!(token_id == expected, "lite layout bit positions must match the documented table");
}

#[test]
fn test_mint_accepts_settings_id_at_16_bit_boundary() {
    let (token, _, _) = deploy_token_lite();
    start_cheat_block_timestamp(token.contract_address, 1000);
    let token_id = mint_basic(
        token, Option::None, Option::Some(0xFFFF), Option::None, Option::None, ALICE(), false, 0,
    );
    assert!(token.settings_id(token_id) == 0xFFFF, "boundary settings_id roundtrip");
}

#[test]
#[should_panic(expected: "LitePackedTokenId: settings_id exceeds 16-bit limit")]
fn test_mint_rejects_settings_id_over_16_bits() {
    let (token, _, _) = deploy_token_lite();
    start_cheat_block_timestamp(token.contract_address, 1000);
    // 0x10000 fit the full token's 30-bit field but exceeds the lite 16-bit
    // field — must now be rejected at mint.
    mint_basic(
        token, Option::None, Option::Some(0x10000), Option::None, Option::None, ALICE(), false, 0,
    );
}
