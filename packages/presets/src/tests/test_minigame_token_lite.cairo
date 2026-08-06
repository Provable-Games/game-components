use game_components_embeddable_game_standard::token_lite::interface::{
    IMinigameTokenLiteDispatcher, IMinigameTokenLiteDispatcherTrait,
};
use openzeppelin_interfaces::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::ContractAddress;
use crate::minigame_token_lite::{
    IMinigameTokenLiteAdminDispatcher, IMinigameTokenLiteAdminDispatcherTrait,
};

fn addr(v: felt252) -> ContractAddress {
    v.try_into().unwrap()
}

fn OWNER() -> ContractAddress {
    addr('OWNER')
}

fn GAME() -> ContractAddress {
    addr('GAME')
}

fn ALICE() -> ContractAddress {
    addr('ALICE')
}

fn deploy(game: Option<ContractAddress>) -> ContractAddress {
    let class = declare("MinigameTokenLite").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    let name: ByteArray = "Lite";
    let symbol: ByteArray = "LT";
    let base_uri: ByteArray = "https://lite.test/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    game.serialize(ref calldata);
    let (address, _) = class.deploy(@calldata).unwrap();
    address
}

fn mint_neutral(token: IMinigameTokenLiteDispatcher, game: ContractAddress) -> felt252 {
    token
        .mint(
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
            ALICE(),
            false,
            false,
            0,
            0,
        )
}

#[test]
fn test_bound_at_construction_mints() {
    let address = deploy(Option::Some(GAME()));
    let token = IMinigameTokenLiteDispatcher { contract_address: address };
    assert!(token.game_address() == GAME(), "Game should be bound at construction");
    let token_id = mint_neutral(token, GAME());
    let erc721 = ERC721ABIDispatcher { contract_address: address };
    assert!(erc721.owner_of(token_id.into()) == ALICE(), "Mint should work when bound");
}

#[test]
fn test_two_phase_bind_then_mint() {
    let address = deploy(Option::None);
    let token = IMinigameTokenLiteDispatcher { contract_address: address };
    assert!(token.game_address() == addr(0), "Unbound token has zero game");

    cheat_caller_address(address, OWNER(), CheatSpan::TargetCalls(1));
    IMinigameTokenLiteAdminDispatcher { contract_address: address }.bind_game(GAME());
    assert!(token.game_address() == GAME(), "Game should be bound");

    let token_id = mint_neutral(token, GAME());
    let erc721 = ERC721ABIDispatcher { contract_address: address };
    assert!(erc721.owner_of(token_id.into()) == ALICE(), "Mint should work after binding");
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Game address does not match configured game")]
fn test_unbound_token_cannot_mint() {
    let address = deploy(Option::None);
    mint_neutral(IMinigameTokenLiteDispatcher { contract_address: address }, GAME());
}

#[test]
#[should_panic(expected: "MinigameTokenLite: Game is already bound")]
fn test_bind_game_only_once() {
    let address = deploy(Option::Some(GAME()));
    cheat_caller_address(address, OWNER(), CheatSpan::TargetCalls(1));
    IMinigameTokenLiteAdminDispatcher { contract_address: address }.bind_game(addr('OTHER'));
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_bind_game_owner_only() {
    let address = deploy(Option::None);
    cheat_caller_address(address, ALICE(), CheatSpan::TargetCalls(1));
    IMinigameTokenLiteAdminDispatcher { contract_address: address }.bind_game(GAME());
}
