//! `GameMetadataComponent` — a game's identity, readable without a token.

use game_components_interfaces::minigame::core::{
    IMinigameGameMetadataDispatcher, IMinigameGameMetadataDispatcherTrait,
};
use game_components_interfaces::structs::minigame::GameMetadata;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

fn addr(v: felt252) -> ContractAddress {
    v.try_into().unwrap()
}

fn sample() -> GameMetadata {
    GameMetadata {
        name: "Test Game",
        description: "A game",
        developer: "Dev",
        publisher: "Pub",
        genre: "Genre",
        image: "img",
        color: "#fff",
        client_url: "https://example.test",
        royalty_fraction: 0,
    }
}

fn deploy() -> IMinigameGameMetadataDispatcher {
    let contract = declare("GameMetadataMock").unwrap().contract_class();
    let mut calldata = array![];
    sample().serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    IMinigameGameMetadataDispatcher { contract_address: address }
}

#[test]
fn test_identity_is_readable_without_minting_a_token() {
    // The whole point: one call, no token, no rendering involved. Previously a
    // consumer had to mint, render, and parse traits back out of the document
    // — so a renderer that omitted "Game Name" left the game nameless
    // everywhere.
    let meta = deploy().game_metadata();
    assert!(meta.name == "Test Game", "name");
    assert!(meta.developer == "Dev", "developer");
    assert!(meta.publisher == "Pub", "publisher");
    assert!(meta.genre == "Genre", "genre");
    assert!(meta.image == "img", "image");
}

#[test]
fn test_round_trips_every_field() {
    // ByteArray-heavy struct through storage: assert the non-string fields
    // too, so a packing change cannot quietly drop one.
    let meta = deploy().game_metadata();
    assert!(meta.client_url == "https://example.test", "client_url");
    assert!(meta.color == "#fff", "color");
    assert!(meta.description == "A game", "description");
    assert!(meta.royalty_fraction == 0, "royalty_fraction");
}
