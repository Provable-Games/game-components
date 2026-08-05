use openzeppelin_interfaces::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_caller_address, declare, spy_events, start_cheat_block_timestamp,
};
use starknet::ContractAddress;
use crate::token::extensions::minter::interface::{
    IMinigameTokenMinterDispatcher, IMinigameTokenMinterDispatcherTrait,
};
use crate::token::interface::IMINIGAME_TOKEN_ID;
use crate::token::structs::{unpack_game_id, unpack_objective_id, unpack_token_id};
use crate::token_lite::interface::{
    IMINIGAME_TOKEN_LITE_ID, IMinigameTokenLiteDispatcher, IMinigameTokenLiteDispatcherTrait,
};
use crate::token_lite::token_lite_component::CoreTokenLiteComponent;

fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn GAME() -> ContractAddress {
    addr('GAME')
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

fn deploy_token_lite() -> (
    IMinigameTokenLiteDispatcher, ERC721ABIDispatcher, IMinigameTokenMinterDispatcher,
) {
    let contract = declare("TokenLiteContract").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "LiteToken";
    let symbol: ByteArray = "LITE";
    let base_uri: ByteArray = "https://lite.test/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    GAME().serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    (
        IMinigameTokenLiteDispatcher { contract_address },
        ERC721ABIDispatcher { contract_address },
        IMinigameTokenMinterDispatcher { contract_address },
    )
}

/// Mint with lifecycle only — every unsupported parameter at its required
/// neutral value, mirroring how death-mountain-style dungeons call mint.
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
    token
        .mint(
            GAME(),
            player_name,
            settings_id,
            start,
            end,
            Option::None, // objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            Option::None, // skills_address
            to,
            soulbound,
            false, // paymaster
            salt,
            0 // metadata
        )
}

// ================================================================================================
// DEPLOYMENT / INTERFACE REGISTRATION
// ================================================================================================

#[test]
fn test_deployment_and_interfaces() {
    let (token, erc721, _) = deploy_token_lite();

    assert!(token.game_address() == GAME(), "Game address should match constructor arg");
    assert!(token.game_registry_address() == addr(0), "Registry address should always be zero");
    assert!(erc721.name() == "LiteToken", "Name mismatch");
    assert!(erc721.symbol() == "LITE", "Symbol mismatch");

    let src5 = ISRC5Dispatcher { contract_address: token.contract_address };
    assert!(src5.supports_interface(IMINIGAME_TOKEN_LITE_ID), "Should register lite interface id");
    // Legacy id registered so MinigameComponent::initializer accepts a lite token
    assert!(src5.supports_interface(IMINIGAME_TOKEN_ID), "Should register full token id");
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

    let packed = unpack_token_id(token_id);
    assert!(packed.game_id == 0, "game_id must be 0 for single game");
    assert!(packed.settings_id == 42, "settings_id mismatch");
    assert!(packed.minted_at == 1000, "minted_at mismatch");
    assert!(packed.start_delay == 1000, "start_delay mismatch");
    assert!(packed.end_delay == 1000, "end_delay mismatch");
    assert!(packed.objective_id == 0, "objective_id must be 0");
    assert!(packed.soulbound, "soulbound flag should be set");
    assert!(!packed.has_context, "has_context must be 0");
    assert!(!packed.paymaster, "paymaster must be 0");
    assert!(packed.salt == 7, "salt mismatch");
    assert!(packed.metadata == 0, "metadata must be 0");

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
// MINT — REJECTED PARAMETERS
// ================================================================================================

#[test]
#[should_panic(expected: "MinigameTokenLite: objectives not supported")]
fn test_mint_rejects_objective_id() {
    let (token, _, _) = deploy_token_lite();
    token
        .mint(
            GAME(),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );
}

#[test]
#[should_panic(expected: "MinigameTokenLite: context not supported")]
fn test_mint_rejects_context() {
    let (token, _, _) = deploy_token_lite();
    let context = crate::token::structs::GameContextDetails {
        name: "ctx", description: "ctx", id: Option::None, context: array![].span(),
    };
    token
        .mint(
            GAME(),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(context),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );
}

#[test]
#[should_panic(expected: "MinigameTokenLite: client_url not supported")]
fn test_mint_rejects_client_url() {
    let (token, _, _) = deploy_token_lite();
    token
        .mint(
            GAME(),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some("https://x.test"),
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );
}

#[test]
#[should_panic(expected: "MinigameTokenLite: per-token renderer not supported")]
fn test_mint_rejects_renderer() {
    let (token, _, _) = deploy_token_lite();
    token
        .mint(
            GAME(),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(addr('RENDERER')),
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );
}

#[test]
#[should_panic(expected: "MinigameTokenLite: skills not supported")]
fn test_mint_rejects_skills() {
    let (token, _, _) = deploy_token_lite();
    token
        .mint(
            GAME(),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(addr('SKILLS')),
            ALICE(),
            false,
            false,
            0,
            0,
        );
}

#[test]
#[should_panic(expected: "MinigameTokenLite: paymaster flag not supported")]
fn test_mint_rejects_paymaster() {
    let (token, _, _) = deploy_token_lite();
    token
        .mint(
            GAME(),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            true,
            0,
            0,
        );
}

#[test]
#[should_panic(expected: "MinigameTokenLite: metadata field not supported")]
fn test_mint_rejects_metadata() {
    let (token, _, _) = deploy_token_lite();
    token
        .mint(
            GAME(),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            5,
        );
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Game address does not match configured game")]
fn test_mint_rejects_wrong_game_address() {
    let (token, _, _) = deploy_token_lite();
    token
        .mint(
            addr('OTHER_GAME'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );
}

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
    token.assert_is_playable(token_id);
    token.assert_owner_and_playable(token_id, ALICE());

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

#[test]
#[should_panic(expected: "MinigameTokenLite: Token is not playable - game has expired")]
fn test_assert_is_playable_panics_after_expiry() {
    let (token, _, _) = deploy_token_lite();
    start_cheat_block_timestamp(token.contract_address, 1000);
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::Some(2000), ALICE(), false, 0,
    );
    start_cheat_block_timestamp(token.contract_address, 2000);
    token.assert_is_playable(token_id);
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Token is not playable - game has not started")]
fn test_assert_is_playable_panics_before_start() {
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
    token.assert_is_playable(token_id);
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Address is not owner of token")]
fn test_assert_owner_and_playable_rejects_wrong_owner() {
    let (token, _, _) = deploy_token_lite();
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    token.assert_owner_and_playable(token_id, BOB());
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Address is not owner of token")]
fn test_assert_owner_and_playable_rejects_nonexistent_token() {
    let (token, _, _) = deploy_token_lite();
    token.assert_owner_and_playable(12345, ALICE());
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Expected owner cannot be zero")]
fn test_assert_owner_and_playable_rejects_zero_owner() {
    let (token, _, _) = deploy_token_lite();
    let token_id = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    token.assert_owner_and_playable(token_id, addr(0));
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
fn test_refresh_metadata_batch_emits_events() {
    let (token, _, _) = deploy_token_lite();
    let id_a = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 0,
    );
    let id_b = mint_basic(
        token, Option::None, Option::None, Option::None, Option::None, ALICE(), false, 1,
    );

    let mut spy = spy_events();
    token.refresh_metadata_batch(array![id_a, id_b].span());
    spy
        .assert_emitted(
            @array![
                (
                    token.contract_address,
                    CoreTokenLiteComponent::Event::MetadataUpdate(
                        CoreTokenLiteComponent::MetadataUpdate { token_id: id_a.into() },
                    ),
                ),
                (
                    token.contract_address,
                    CoreTokenLiteComponent::Event::MetadataUpdate(
                        CoreTokenLiteComponent::MetadataUpdate { token_id: id_b.into() },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: "MinigameTokenLite: token_ids array cannot be empty")]
fn test_refresh_metadata_batch_rejects_empty() {
    let (token, _, _) = deploy_token_lite();
    token.refresh_metadata_batch(array![].span());
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
// PACKING PARITY HELPERS
// ================================================================================================

#[test]
fn test_helper_unpackers_agree_with_full_unpack() {
    let (token, _, _) = deploy_token_lite();
    start_cheat_block_timestamp(token.contract_address, 1234);
    let token_id = mint_basic(
        token, Option::None, Option::Some(9), Option::None, Option::Some(9999), ALICE(), true, 3,
    );

    // The lite token reuses the canonical 251-bit layout, so the standalone
    // helper unpackers (what game/dungeon contracts use on their side) must
    // agree with the full unpack.
    let packed = unpack_token_id(token_id);
    assert!(unpack_game_id(token_id) == packed.game_id, "game_id helper mismatch");
    assert!(unpack_objective_id(token_id) == packed.objective_id, "objective helper mismatch");
    assert!(packed.game_id == 0 && packed.objective_id == 0, "lite invariants");
}
