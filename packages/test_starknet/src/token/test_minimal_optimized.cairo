use starknet::{contract_address_const};
use snforge_std::{cheat_caller_address, CheatSpan};

use game_components_token::interface::{
    IMinigameTokenMixinDispatcher, IMinigameTokenMixinDispatcherTrait,
};
use openzeppelin_token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};

// Import setup helpers
use super::setup::{deploy_minimal_optimized_contract, ALICE, BOB};

// Deploy helper
fn deploy_minimal_token() -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher) {
    deploy_minimal_optimized_contract("MinimalToken", "MIN", "https://minimal.test/")
}

#[test]
fn test_minimal_contract_deployment() {
    let (token_dispatcher, _erc721_dispatcher) = deploy_minimal_token();

    // Verify basic token interface is working
    // Note: The minimal contract may not expose all metadata functions
    // Let's just verify the contract was deployed correctly
    assert!(
        token_dispatcher.contract_address != contract_address_const::<0>(),
        "Contract should be deployed",
    );
}

#[test]
fn test_minimal_contract_minting() {
    let (token_dispatcher, erc721_dispatcher) = deploy_minimal_token();

    // Mint a token with minimal parameters
    let token_id = token_dispatcher
        .mint(
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
        );

    // Verify token was minted
    assert!(token_id == 1, "First token ID should be 1");
    assert!(
        erc721_dispatcher.owner_of(token_id.into()) == ALICE(), "Token should be owned by ALICE",
    );
    assert!(erc721_dispatcher.balance_of(ALICE()) == 1, "Balance should be 1");
}

#[test]
fn test_minimal_contract_minter_tracking() {
    let (token_dispatcher, _) = deploy_minimal_token();

    // Mint tokens from different addresses
    cheat_caller_address(token_dispatcher.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    let token_id1 = token_dispatcher
        .mint(
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
        );

    cheat_caller_address(token_dispatcher.contract_address, BOB(), CheatSpan::TargetCalls(1));
    let token_id2 = token_dispatcher
        .mint(
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
        );

    // Verify minter tracking
    assert!(token_dispatcher.minter_exists(ALICE()), "ALICE should be a minter");
    assert!(token_dispatcher.minter_exists(BOB()), "BOB should be a minter");
    assert!(token_dispatcher.total_minters() >= 2, "Should have at least 2 minters");

    // Verify minted_by
    let minter_id1 = token_dispatcher.minted_by(token_id1);
    let minter_id2 = token_dispatcher.minted_by(token_id2);
    assert!(minter_id1 != minter_id2, "Different minters should have different IDs");
}

#[test]
fn test_minimal_contract_transfers() {
    let (token_dispatcher, erc721_dispatcher) = deploy_minimal_token();

    // Mint a token
    let token_id = token_dispatcher
        .mint(
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
        );

    // Transfer token
    cheat_caller_address(token_dispatcher.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721_dispatcher.transfer_from(ALICE(), BOB(), token_id.into());

    // Verify transfer
    assert!(erc721_dispatcher.owner_of(token_id.into()) == BOB(), "Token should be owned by BOB");
    assert!(erc721_dispatcher.balance_of(ALICE()) == 0, "ALICE balance should be 0");
    assert!(erc721_dispatcher.balance_of(BOB()) == 1, "BOB balance should be 1");
}

#[test]
fn test_minimal_contract_disabled_features() {
    let (token_dispatcher, _) = deploy_minimal_token();

    // Mint a token
    let token_id = token_dispatcher
        .mint(
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
        );

    // Verify disabled features return default values
    assert!(token_dispatcher.settings_id(token_id) == 0, "Settings should be disabled");
    assert!(token_dispatcher.objectives_count(token_id) == 0, "Objectives should be disabled");
    assert!(!token_dispatcher.is_soulbound(token_id), "Soulbound should be disabled");
    assert!(
        token_dispatcher.renderer_address(token_id) == contract_address_const::<0>(),
        "Renderer should be disabled",
    );
}

#[test]
fn test_minimal_contract_token_metadata() {
    let (token_dispatcher, _) = deploy_minimal_token();

    // Mint a token
    let token_id = token_dispatcher
        .mint(
            Option::None,
            Option::Some("MinimalPlayer"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // Check metadata
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.minted_by > 0, "Should have minter ID");
    assert!(metadata.game_id == 0, "No game ID in minimal contract");
    assert!(!metadata.soulbound, "Should not be soulbound");

    // Check player name
    assert!(token_dispatcher.player_name(token_id) == "MinimalPlayer", "Player name should be set");
}
