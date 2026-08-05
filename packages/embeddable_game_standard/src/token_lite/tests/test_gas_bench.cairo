// Gas benchmarks: CoreTokenLiteComponent vs the full CoreTokenComponent in its
// deployed-denshokan configuration (multi-game registry + all extensions).
//
// Method: paired tests. Each `*_baseline` test performs setup only; each op
// test repeats the measured operation 10 times on top of the same setup.
// Per-op cost = (op_test_l2_gas - baseline_l2_gas) / 10. Deployment noise
// cancels out within a pair; snforge prints l2_gas per test.
//
// Caveats when reading the numbers:
// * MockGame's `game_over()`/`score()` return from trivial storage. On a real
//   game (e.g. death mountain) each callback re-runs full asset loading —
//   measured on mainnet at ~1.56M L2 gas per callback — so the real
//   `update_game` vs `refresh_metadata` gap is far larger than shown here.
// * FullTokenContract does not include EnumerableComponent; the deployed
//   denshokan does, adding two storage writes per mint and per transfer on
//   top of the full-token numbers.

use openzeppelin_interfaces::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
    start_cheat_block_timestamp,
};
use starknet::ContractAddress;
use crate::registry::interface::{IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait};
use crate::token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use crate::token_lite::interface::{IMinigameTokenLiteDispatcher, IMinigameTokenLiteDispatcherTrait};

const START_TIME: u64 = 1000;
const END_TIME: u64 = 100000;

fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn ALICE() -> ContractAddress {
    addr('ALICE')
}

fn OWNER() -> ContractAddress {
    addr('OWNER')
}

// ================================================================================================
// SETUP
// ================================================================================================

fn deploy_mock_game() -> ContractAddress {
    let contract = declare("MockGame").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

fn setup_lite() -> (IMinigameTokenLiteDispatcher, ERC721ABIDispatcher, ContractAddress) {
    let game = deploy_mock_game();
    let contract = declare("TokenLiteContract").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "LiteToken";
    let symbol: ByteArray = "LITE";
    let base_uri: ByteArray = "https://lite.test/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    game.serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    start_cheat_block_timestamp(contract_address, START_TIME);
    (
        IMinigameTokenLiteDispatcher { contract_address },
        ERC721ABIDispatcher { contract_address },
        game,
    )
}

/// Full token in the deployed-denshokan shape: multi-game registry with the
/// mock game registered, all optional extensions compiled in.
fn setup_full() -> (IMinigameTokenDispatcher, ERC721ABIDispatcher, ContractAddress) {
    let game = deploy_mock_game();

    let registry_class = declare("MinigameRegistryContract").unwrap().contract_class();
    let mut registry_calldata: Array<felt252> = array![];
    let reg_name: ByteArray = "GameCreatorToken";
    let reg_symbol: ByteArray = "GCT";
    let reg_base_uri: ByteArray = "";
    reg_name.serialize(ref registry_calldata);
    reg_symbol.serialize(ref registry_calldata);
    reg_base_uri.serialize(ref registry_calldata);
    registry_calldata.append(1); // event_relayer_address: None
    let (registry_address, _) = registry_class.deploy(@registry_calldata).unwrap();

    // register_game records the caller as the game contract
    let registry = IMinigameRegistryDispatcher { contract_address: registry_address };
    cheat_caller_address(registry_address, game, CheatSpan::TargetCalls(1));
    registry
        .register_game(
            OWNER(),
            "MockGame",
            "d",
            "dev",
            "pub",
            "genre",
            "img",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            1,
            Option::None,
            Option::None,
        );

    let token_class = declare("FullTokenContract").unwrap().contract_class();
    let mut token_calldata: Array<felt252> = array![];
    let name: ByteArray = "FullToken";
    let symbol: ByteArray = "FULL";
    let base_uri: ByteArray = "https://full.test/";
    name.serialize(ref token_calldata);
    symbol.serialize(ref token_calldata);
    base_uri.serialize(ref token_calldata);
    OWNER().serialize(ref token_calldata);
    OWNER().serialize(ref token_calldata); // royalty receiver
    let royalty_fraction: u128 = 500;
    royalty_fraction.serialize(ref token_calldata);
    token_calldata.append(0); // game_registry_address: Some
    registry_address.serialize(ref token_calldata);
    let (token_address, _) = token_class.deploy(@token_calldata).unwrap();
    start_cheat_block_timestamp(token_address, START_TIME);
    (
        IMinigameTokenDispatcher { contract_address: token_address },
        ERC721ABIDispatcher { contract_address: token_address },
        game,
    )
}

fn mint_lite(token: IMinigameTokenLiteDispatcher, game: ContractAddress, salt: u16) -> felt252 {
    token
        .mint(
            game,
            Option::Some('bench'),
            Option::None,
            Option::Some(START_TIME),
            Option::Some(END_TIME),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            salt,
            0,
        )
}

fn mint_full(token: IMinigameTokenDispatcher, game: ContractAddress, salt: u16) -> felt252 {
    token
        .mint(
            game,
            Option::Some('bench'),
            Option::None,
            Option::Some(START_TIME),
            Option::Some(END_TIME),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            salt,
            0,
        )
}

// ================================================================================================
// BASELINES (setup only)
// ================================================================================================

#[test]
fn bench_lite_deploy_baseline() {
    let (_, _, _) = setup_lite();
}

#[test]
fn bench_full_deploy_baseline() {
    let (_, _, _) = setup_full();
}

// ================================================================================================
// MINT — first mint (x1, cold minter registration) and x10 (9 warm mints)
// ================================================================================================

#[test]
fn bench_lite_mint_x1() {
    let (token, _, game) = setup_lite();
    mint_lite(token, game, 0);
}

#[test]
fn bench_full_mint_x1() {
    let (token, _, game) = setup_full();
    mint_full(token, game, 0);
}

#[test]
fn bench_lite_mint_x10() {
    let (token, _, game) = setup_lite();
    let mut salt: u16 = 0;
    while salt < 10 {
        mint_lite(token, game, salt);
        salt += 1;
    }
}

#[test]
fn bench_full_mint_x10() {
    let (token, _, game) = setup_full();
    let mut salt: u16 = 0;
    while salt < 10 {
        mint_full(token, game, salt);
        salt += 1;
    }
}

// ================================================================================================
// PER-ACTION GUARD — full: owner_of + assert_is_playable (2 calls, as
// death-mountain's game_core does today) vs lite: assert_owner_and_playable (1)
// ================================================================================================

#[test]
fn bench_lite_guard_x10() {
    let (token, _, game) = setup_lite();
    let token_id = mint_lite(token, game, 0);
    let mut i: u32 = 0;
    while i < 10 {
        token.assert_owner_and_playable(token_id, ALICE());
        i += 1;
    }
}

#[test]
fn bench_full_guard_x10() {
    let (token, erc721, game) = setup_full();
    let token_id = mint_full(token, game, 0);
    let mut i: u32 = 0;
    while i < 10 {
        let owner = erc721.owner_of(token_id.into());
        assert!(owner == ALICE(), "owner check");
        token.assert_is_playable(token_id);
        i += 1;
    }
}

// ================================================================================================
// POST-ACTION — full: update_game (SRC5 + registry resolve + game_over +
// score callbacks + minter SRC5 probe) vs lite: refresh_metadata (event only)
// ================================================================================================

#[test]
fn bench_lite_post_action_x10() {
    let (token, _, game) = setup_lite();
    let token_id = mint_lite(token, game, 0);
    let mut i: u32 = 0;
    while i < 10 {
        token.refresh_metadata(token_id);
        i += 1;
    }
}

#[test]
fn bench_full_post_action_x10() {
    let (token, _, game) = setup_full();
    let token_id = mint_full(token, game, 0);
    let mut i: u32 = 0;
    while i < 10 {
        token.update_game(token_id);
        i += 1;
    }
}
