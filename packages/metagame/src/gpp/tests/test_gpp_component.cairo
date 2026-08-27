// SPDX-License-Identifier: BUSL-1.1

//! GPP cross-context tests.
//!
//! A game token id is unique only within the contract that minted it, and this
//! component is metagame state that sees many game contracts. Every test here
//! runs TWO contexts sharing one token id -- the case no single-context test
//! can reach, and the reason the collision shipped unnoticed.

use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

#[starknet::interface]
trait IGppMock<TContractState> {
    fn configure(ref self: TContractState, context_id: u64, capacity: u32, game_lifetime: u32);
    fn fund_erc721(
        ref self: TContractState,
        context_id: u64,
        sponsor: ContractAddress,
        token_address: ContractAddress,
        nft_id: u128,
    );
    fn reserve_slot(ref self: TContractState, context_id: u64, game_token_id: felt252);
    fn release_slot(ref self: TContractState, context_id: u64, game_token_id: felt252);
    fn claim_prize(
        ref self: TContractState,
        context_id: u64,
        game_token_id: felt252,
        recipient: ContractAddress,
    );
    fn reserved_nft(self: @TContractState, context_id: u64, game_token_id: felt252) -> u128;
    fn nft_at(self: @TContractState, context_id: u64, index: u32) -> u128;
    fn nft_top(self: @TContractState, context_id: u64) -> u32;
}

#[starknet::interface]
trait IERC721Mock<TContractState> {
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn mint(ref self: TContractState, to: ContractAddress, token_id: u256);
}

fn SPONSOR() -> ContractAddress {
    'sponsor'.try_into().unwrap()
}
fn ALICE() -> ContractAddress {
    'alice'.try_into().unwrap()
}
fn BOB() -> ContractAddress {
    'bob'.try_into().unwrap()
}

/// The colliding id. Not a small number by accident: ids are packed felts, and
/// two games arrive at the same one only when every packed field matches.
const SHARED_TOKEN: felt252 = 45672623064878172811178214246783879468223037540;

const CTX_A: u64 = 1;
const CTX_B: u64 = 2;

fn deploy_gpp() -> IGppMockDispatcher {
    let contract = declare("GppMock").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    IGppMockDispatcher { contract_address: address }
}

fn deploy_erc721() -> IERC721MockDispatcher {
    let contract = declare("ERC721TransferMock").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    IERC721MockDispatcher { contract_address: address }
}

/// Fund `context_id` with one NFT, minted to the sponsor and pulled in.
fn fund_one(gpp: IGppMockDispatcher, erc721: IERC721MockDispatcher, context_id: u64, nft_id: u128) {
    erc721.mint(SPONSOR(), nft_id.into());
    gpp.configure(context_id, 4, 3600);
    gpp.fund_erc721(context_id, SPONSOR(), erc721.contract_address, nft_id);
}

/// Two contexts sharing ONE ERC721 collection is the dangerous case: the wrong
/// NFT is a valid token of the right contract, so the payout SUCCEEDS and pays
/// the wrong person. A revert would at least be loud.
#[test]
fn test_claim_pays_this_contexts_nft_not_the_other_contexts() {
    let gpp = deploy_gpp();
    let erc721 = deploy_erc721();

    fund_one(gpp, erc721, CTX_A, 1001);
    fund_one(gpp, erc721, CTX_B, 2002);

    // Same token id enters both contexts. B's reservation used to overwrite A's.
    gpp.reserve_slot(CTX_A, SHARED_TOKEN);
    gpp.reserve_slot(CTX_B, SHARED_TOKEN);

    assert!(gpp.reserved_nft(CTX_A, SHARED_TOKEN) == 1001, "A keeps its own reservation");
    assert!(gpp.reserved_nft(CTX_B, SHARED_TOKEN) == 2002, "B keeps its own reservation");

    // Alice claims in A. Before the fix this transferred 2002 -- B's NFT --
    // and succeeded, because 2002 is a real token of the same collection.
    gpp.claim_prize(CTX_A, SHARED_TOKEN, ALICE());
    assert!(erc721.owner_of(1001_u256) == ALICE(), "A's claimant receives A's NFT");

    // And B's prize is still there for B's claimant, rather than already gone.
    gpp.claim_prize(CTX_B, SHARED_TOKEN, BOB());
    assert!(erc721.owner_of(2002_u256) == BOB(), "B's claimant receives B's NFT");
}

/// Different collections per context: the cross-context read produced an id the
/// context's own collection could not transfer, so the prize was permanently
/// unclaimable. Here each context resolves within its own collection.
///
/// The NFT ids must DIFFER between the two collections. An earlier version of
/// this test funded both with id 7, so the cross-context overwrite wrote an
/// identical value and the test passed against the broken code -- it could not
/// fail, which makes it worse than no test.
#[test]
fn test_claim_works_when_contexts_use_different_collections() {
    let gpp = deploy_gpp();
    let collection_a = deploy_erc721();
    let collection_b = deploy_erc721();

    fund_one(gpp, collection_a, CTX_A, 7);
    fund_one(gpp, collection_b, CTX_B, 99);

    gpp.reserve_slot(CTX_A, SHARED_TOKEN);
    gpp.reserve_slot(CTX_B, SHARED_TOKEN);

    // Before the fix, A's claim read 99 -- B's id -- and asked A's collection
    // to transfer a token it has never minted, so this reverted and A's prize
    // was unclaimable forever.
    gpp.claim_prize(CTX_A, SHARED_TOKEN, ALICE());
    gpp.claim_prize(CTX_B, SHARED_TOKEN, BOB());

    assert!(collection_a.owner_of(7_u256) == ALICE(), "A pays from A's collection");
    assert!(collection_b.owner_of(99_u256) == BOB(), "B pays from B's collection");
}

/// Releasing a slot returns the reservation to the pool. Reading it
/// cross-context pushed the OTHER context's NFT onto this context's stack,
/// so one pool gained an NFT it did not hold while its own was orphaned.
#[test]
fn test_release_returns_this_contexts_nft_to_its_own_pool() {
    let gpp = deploy_gpp();
    let erc721 = deploy_erc721();

    fund_one(gpp, erc721, CTX_A, 1001);
    fund_one(gpp, erc721, CTX_B, 2002);

    gpp.reserve_slot(CTX_A, SHARED_TOKEN);
    gpp.reserve_slot(CTX_B, SHARED_TOKEN);

    // Both pools drained to empty by the reservations.
    assert!(gpp.nft_top(CTX_A) == 0, "A's stack emptied by its reservation");
    assert!(gpp.nft_top(CTX_B) == 0, "B's stack emptied by its reservation");

    gpp.release_slot(CTX_A, SHARED_TOKEN);

    // A must get 1001 back, not 2002. Before the fix this pushed B's NFT into
    // A's stack, leaving A's own 1001 orphaned out of both pools.
    assert!(gpp.nft_top(CTX_A) == 1, "A's stack has one NFT again");
    assert!(gpp.nft_at(CTX_A, 0) == 1001, "A recovers its OWN NFT");
    assert!(gpp.nft_top(CTX_B) == 0, "B's stack is untouched");

    // B's reservation still stands and still pays B.
    gpp.claim_prize(CTX_B, SHARED_TOKEN, BOB());
    assert!(erc721.owner_of(2002_u256) == BOB(), "B's prize survived A's release");
}
