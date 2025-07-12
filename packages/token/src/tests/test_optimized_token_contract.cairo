use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, spy_events, EventSpyAssertionsTrait,
    start_cheat_block_timestamp, stop_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_caller_address
};

use openzeppelin_token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

use game_components_token::core::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use crate::tests::mocks::mock_game::{IMockGameDispatcher, IMockGameDispatcherTrait};

// Test addresses
fn ALICE() -> ContractAddress {
    contract_address_const::<'ALICE'>()
}

fn BOB() -> ContractAddress {
    contract_address_const::<'BOB'>()
}

fn ZERO_ADDRESS() -> ContractAddress {
    contract_address_const::<0>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

// Deploy helpers
fn deploy_mock_game() -> ContractAddress {
    let contract = declare("MockGame").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

fn deploy_test_token_contract() -> (ContractAddress, IMinigameTokenDispatcher, ERC721ABIDispatcher) {
    let contract = declare("OptimizedTokenContract").unwrap().contract_class();
    
    let mut constructor_calldata = array![];
    let name: ByteArray = "TestToken";
    let symbol: ByteArray = "TT";
    let base_uri: ByteArray = "https://test.com/token/";
    
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    base_uri.serialize(ref constructor_calldata);
    constructor_calldata.append(1); // None variant
    constructor_calldata.append(1); // None variant
    
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    
    let core_dispatcher = IMinigameTokenDispatcher { contract_address };
    let erc721_dispatcher = ERC721ABIDispatcher { contract_address };
    
    (contract_address, core_dispatcher, erc721_dispatcher)
}

// ================================================================================================
// ERC721 FUNCTIONALITY TESTS
// ================================================================================================

#[test]
fn test_token_erc721_name() {
    let (_, _, erc721) = deploy_test_token_contract();
    assert!(erc721.name() == "TestToken");
    assert!(erc721.symbol() == "TT");
    assert!(erc721.base_uri() == "https://test.com/token/");
}

// #[test]
// fn test_token_erc721_mint_and_owner() {
//     let (_, core_token, erc721) = deploy_test_token_contract();
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     assert!(erc721.owner_of(token_id.into()) == ALICE());
//     assert!(erc721.balance_of(ALICE()) == 1);
// }

// #[test]
// fn test_token_erc721_transfer() {
//     let (contract_address, core_token, erc721) = deploy_test_token_contract();
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     start_cheat_caller_address(contract_address, ALICE());
//     erc721.transfer_from(ALICE(), BOB(), token_id.into());
//     stop_cheat_caller_address(contract_address);
    
//     assert!(erc721.owner_of(token_id.into()) == BOB());
//     assert!(erc721.balance_of(ALICE()) == 0);
//     assert!(erc721.balance_of(BOB()) == 1);
// }

// #[test]
// fn test_token_erc721_approve() {
//     let (contract_address, core_token, erc721) = deploy_test_token_contract();
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     start_cheat_caller_address(contract_address, ALICE());
//     erc721.approve(BOB(), token_id.into());
//     stop_cheat_caller_address(contract_address);
    
//     assert!(erc721.get_approved(token_id.into()) == BOB());
// }

// #[test]
// fn test_token_erc721_token_uri() {
//     let (_, core_token, erc721) = deploy_test_token_contract();
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     let uri = erc721.token_uri(token_id.into());
//     assert!(uri == "https://test.com/1");
// }

// // ================================================================================================
// // CORE TOKEN FUNCTIONALITY TESTS
// // ================================================================================================

// #[test]
// fn test_token_core_mint_minimal() {
//     let (_, core_token, _) = deploy_test_token_contract();
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     assert!(token_id == 1);
//     let metadata = core_token.token_metadata(token_id);
//     assert!(metadata.soulbound == false);
//     assert!(metadata.game_over == false);
//     assert!(metadata.objectives_count == 0);
// }

// #[test]
// fn test_token_core_mint_with_full_parameters() {
//     let (_, core_token, _) = deploy_test_token_contract();
//     let game_address = deploy_mock_game();
    
//     let objective_ids = array![1, 2, 3].span();
//     let token_id = core_token.mint(
//         Option::Some(game_address),
//         Option::Some("TestPlayer"),
//         Option::Some(42),
//         Option::Some(1000),
//         Option::Some(2000),
//         Option::Some(objective_ids),
//         Option::Some('context_id'),
//         Option::Some("https://client.game.com"),
//         Option::Some(contract_address_const::<'RENDERER'>()),
//         ALICE(),
//         true
//     );
    
//     assert!(token_id == 1);
//     let metadata = core_token.token_metadata(token_id);
//     assert!(metadata.soulbound == true);
//     assert!(metadata.settings_id == 42);
//     assert!(metadata.lifecycle.start == 1000);
//     assert!(metadata.lifecycle.end == 2000);
//     assert!(metadata.objectives_count == 3);
    
//     assert!(core_token.player_name(token_id) == "TestPlayer");
//     assert!(core_token.game_address(token_id) == game_address);
//     assert!(core_token.is_soulbound(token_id) == true);
// }

// #[test]
// fn test_token_core_update_game() {
//     let (_, core_token, _) = deploy_test_token_contract();
//     let game_address = deploy_mock_game();
    
//     let token_id = core_token.mint(
//         Option::Some(game_address),
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     // Update game state
//     let mock_game = IMockGameDispatcher { contract_address: game_address };
//     mock_game.set_score(token_id, 100);
//     mock_game.set_game_over(token_id, true);
    
//     // Update token
//     core_token.update_game(token_id);
    
//     let metadata = core_token.token_metadata(token_id);
//     assert!(metadata.game_over == true);
// }

// #[test]
// fn test_token_core_is_playable() {
//     let (contract_address, core_token, _) = deploy_test_token_contract();
    
//     // Set timestamp to within lifecycle
//     start_cheat_block_timestamp(contract_address, 1500);
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::Some(1000),
//         Option::Some(2000),
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     assert!(core_token.is_playable(token_id) == true);
    
//     stop_cheat_block_timestamp(contract_address);
// }

// #[test]
// fn test_token_core_burn() {
//     let (contract_address, core_token, erc721) = deploy_test_token_contract();
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     start_cheat_caller_address(contract_address, ALICE());
//     core_token.burn(token_id);
//     stop_cheat_caller_address(contract_address);
    
//     assert!(erc721.balance_of(ALICE()) == 0);
// }

// // ================================================================================================
// // SOULBOUND FUNCTIONALITY TESTS
// // ================================================================================================

// #[test]
// fn test_token_soulbound_behavior() {
//     let (_, core_token, _) = deploy_test_token_contract();
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         true // soulbound
//     );
    
//     assert!(core_token.is_soulbound(token_id) == true);
// }

// #[test]
// fn test_token_non_soulbound_behavior() {
//     let (_, core_token, _) = deploy_test_token_contract();
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false // not soulbound
//     );
    
//     assert!(core_token.is_soulbound(token_id) == false);
// }

// // ================================================================================================
// // SRC5 INTROSPECTION TESTS
// // ================================================================================================

// #[test]
// fn test_token_src5_support() {
//     let (contract_address, _, _) = deploy_test_token_contract();
//     let src5 = ISRC5Dispatcher { contract_address };
    
//     // Test ERC721 interface support
//     assert!(src5.supports_interface(0x80ac58cd) == true); // ERC721 interface ID
    
//     // Test SRC5 interface support
//     assert!(src5.supports_interface(0x01ffc9a7) == true); // SRC5 interface ID
// }

// // ================================================================================================
// // EDGE CASE AND ERROR CONDITION TESTS
// // ================================================================================================

// #[test]
// #[should_panic(expected: "ERC721: invalid receiver")]
// fn test_token_mint_to_zero_address() {
//     let (_, core_token, _) = deploy_test_token_contract();
    
//     core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ZERO_ADDRESS(),
//         false
//     );
// }

// #[test]
// #[should_panic(expected: "ERC721: invalid token ID")]
// fn test_token_query_nonexistent_token() {
//     let (_, core_token, _) = deploy_test_token_contract();
    
//     core_token.token_metadata(999);
// }

// #[test]
// #[should_panic(expected: "ERC721: unauthorized")]
// fn test_token_burn_unauthorized() {
//     let (contract_address, core_token, _) = deploy_test_token_contract();
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     start_cheat_caller_address(contract_address, BOB());
//     core_token.burn(token_id);
//     stop_cheat_caller_address(contract_address);
// }

// #[test]
// fn test_token_lifecycle_boundaries() {
//     let (contract_address, core_token, _) = deploy_test_token_contract();
    
//     // Test at exact start time
//     start_cheat_block_timestamp(contract_address, 1000);
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::Some(1000),
//         Option::Some(2000),
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     assert!(core_token.is_playable(token_id) == true);
    
//     // Test at exact end time
//     start_cheat_block_timestamp(contract_address, 2000);
//     assert!(core_token.is_playable(token_id) == true);
    
//     // Test after end time
//     start_cheat_block_timestamp(contract_address, 2001);
//     assert!(core_token.is_playable(token_id) == false);
    
//     stop_cheat_block_timestamp(contract_address);
// }

// #[test]
// fn test_token_sequential_minting() {
//     let (_, core_token, _) = deploy_test_token_contract();
    
//     let token_id_1 = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     let token_id_2 = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         BOB(),
//         false
//     );
    
//     assert!(token_id_1 == 1);
//     assert!(token_id_2 == 2);
// }

// #[test]
// fn test_token_max_objectives() {
//     let (_, core_token, _) = deploy_test_token_contract();
    
//     // Test with large number of objectives
//     let mut objectives = array![];
//     let mut i: u32 = 0;
//     while i < 100 {
//         objectives.append(i);
//         i += 1;
//     };
    
//     let token_id = core_token.mint(
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::None,
//         Option::Some(objectives.span()),
//         Option::None,
//         Option::None,
//         Option::None,
//         ALICE(),
//         false
//     );
    
//     assert!(core_token.objectives_count(token_id) == 100);
// }