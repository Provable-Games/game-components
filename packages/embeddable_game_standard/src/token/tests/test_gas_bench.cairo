// Gas benchmarks: MinigameTokenComponent, self-bound in the one-address
// StandardGameMock — game and token are the same contract.
//
// Method: paired tests. Each `*_baseline` test performs setup only; each op
// test repeats the measured operation 10 times on top of the same setup.
// Per-op cost = (op_test_l2_gas - baseline_l2_gas) / 10. Deployment noise
// cancels out within a pair; snforge prints l2_gas per test.
//
// Caveat when reading the numbers: MockGame's `game_over()`/`score()` return
// from trivial storage. On a real game (e.g. death mountain) each callback
// re-runs full asset loading — measured on mainnet at ~1.56M L2 gas per
// callback.
//
// These were paired against the registry-backed token in its
// deployed-denshokan shape until that generation was retired. The comparison
// is settled and recorded in docs/denshokan-lite-migration.md; what remains
// measures the standard token against itself across releases.

use game_components_test_common::mocks::standard_game_mock::{
    IStandardGameMockDispatcher, IStandardGameMockDispatcherTrait,
};
use openzeppelin_interfaces::erc721::ERC721ABIDispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp};
use starknet::ContractAddress;
use crate::token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};

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

/// One-address shape: the StandardGameMock contract is both the game and the
/// token, so the returned "game" address is the token contract itself.
fn setup_standard() -> (IMinigameTokenDispatcher, ERC721ABIDispatcher, ContractAddress) {
    let contract = declare("StandardGameMock").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "StandardToken";
    let symbol: ByteArray = "STD";
    let base_uri: ByteArray = "https://token.test/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    let game_fee_recipient: starknet::ContractAddress = 'FEE_RECIPIENT'.try_into().unwrap();
    game_fee_recipient.serialize(ref calldata);
    let owner: starknet::ContractAddress = 'OWNER'.try_into().unwrap();
    owner.serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    start_cheat_block_timestamp(contract_address, START_TIME);
    (
        IMinigameTokenDispatcher { contract_address },
        ERC721ABIDispatcher { contract_address },
        contract_address,
    )
}


fn mint_standard(token: IMinigameTokenDispatcher, _game: ContractAddress, salt: u16) -> felt252 {
    // Standard mint — no game address (self-bound); the restored legacy-token
    // params (objective/context/client_url/paymaster/metadata) neutral, to
    // stay comparable with the legacy-token bench call below.
    token
        .mint(
            Option::Some('bench'),
            Option::None,
            Option::Some(START_TIME),
            Option::Some(END_TIME),
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
fn bench_standard_deploy_baseline() {
    let (_, _, _) = setup_standard();
}


// ================================================================================================
// MINT — first mint (x1, cold minter registration) and x10 (9 warm mints)
// ================================================================================================

#[test]
fn bench_standard_mint_x1() {
    let (token, _, game) = setup_standard();
    mint_standard(token, game, 0);
}


#[test]
fn bench_standard_mint_x10() {
    let (token, _, game) = setup_standard();
    let mut salt: u16 = 0;
    while salt < 10 {
        mint_standard(token, game, salt);
        salt += 1;
    }
}


// ================================================================================================
// PER-ACTION GUARD — full: owner_of + assert_is_playable (2 calls, as
// death-mountain's game_core does today) vs standard: assert_owner_and_playable —
// an internal call in the real one-address shape, exercised here through the
// game mock's single external entrypoint (1 call)
// ================================================================================================

#[test]
fn bench_standard_guard_x10() {
    let (token, _, game) = setup_standard();
    let token_id = mint_standard(token, game, 0);
    let game_mock = IStandardGameMockDispatcher { contract_address: token.contract_address };
    let mut i: u32 = 0;
    while i < 10 {
        game_mock.assert_owner_and_playable(token_id, ALICE());
        i += 1;
    }
}


// ================================================================================================
// POST-ACTION — full: update_game (SRC5 + registry resolve + game_over +
// score callbacks + minter SRC5 probe) vs standard: refresh_metadata (event only)
// ================================================================================================

#[test]
fn bench_standard_post_action_x10() {
    let (token, _, game) = setup_standard();
    let token_id = mint_standard(token, game, 0);
    let mut i: u32 = 0;
    while i < 10 {
        token.refresh_metadata(token_id);
        i += 1;
    }
}

