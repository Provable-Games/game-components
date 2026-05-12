use alexandria_merkle_tree::merkle_tree::poseidon::PoseidonHasherImpl;
use alexandria_merkle_tree::merkle_tree::{Hasher, MerkleTree, MerkleTreeImpl};
use core::poseidon::poseidon_hash_span;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, mock_call, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use crate::merkledrop::merkledrop_component::MerkledropComponent;
use crate::merkledrop::signature::EthereumSignature;
use crate::merkledrop::tests::mocks::mock_dungeon::{
    IMockDungeonDispatcher, IMockDungeonDispatcherTrait,
};

// Test vectors from cartridge-gg/merkle_drop -- pk=0x420 → this eth address.
const ETH_ADDRESS: felt252 = 0x4884ABe82470adf54f4e19Fa39712384c05112be;

// Recipient used in the upstream signature test vector.
const RECIPIENT_FELT: felt252 = 0x7db9cc4a5e5485becbde0c40e71af59d72c543dea4cdeddf3c54ba03fdf14eb;

const NFT_HOLDER_FELT: felt252 = 0x2222;
const NFT_COLLECTION_FELT: felt252 = 0xc011ec7;
const NFT_TOKEN_ID_LO: felt252 = 42;
const NFT_TOKEN_ID_HI: felt252 = 0;
const DUNGEON_ID: u32 = 1;

fn deploy_dungeon() -> IMockDungeonDispatcher {
    let contract = declare("MockDungeon").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    IMockDungeonDispatcher { contract_address: address }
}

fn test_signature() -> EthereumSignature {
    EthereumSignature {
        v: 28,
        r: 0x8a616cce850f16086b7f189ca3075e730cc8e3c891adb3ce6ff32e2ae5441fa4,
        s: 0x20b6bd7126554394b4d9ebc9b57f95aa21f0d84a1211499d5bc6ec4faad266e3,
    }
}

fn eth_leaf_data() -> Array<felt252> {
    array![ETH_ADDRESS, DUNGEON_ID.into()]
}

fn nft_leaf_data() -> Array<felt252> {
    array![NFT_COLLECTION_FELT, NFT_TOKEN_ID_LO, NFT_TOKEN_ID_HI, DUNGEON_ID.into()]
}

// ------------------------ ETH-signature path -------------------------

#[test]
fn test__eth_sig_register_and_claim_succeeds() {
    let dungeon = deploy_dungeon();
    let recipient: ContractAddress = RECIPIENT_FELT.try_into().unwrap();

    let leaf = eth_leaf_data();
    let all_data = array![leaf.span()];
    let root = dungeon.register_drop(all_data.span(), 0xffffffffffffffff);
    assert!(dungeon.tree_expiry(root) == 0xffffffffffffffff, "tree not registered");

    // For a tree of size 1, alexandria pads to [leaf, 0]; sibling proof is [0].
    let proof: Array<felt252> = array![0];
    dungeon.claim_with_eth_signature(root, proof.span(), leaf.span(), recipient, test_signature());

    assert!(dungeon.has_access(recipient, DUNGEON_ID), "access not granted");
}

#[test]
#[should_panic(expected: "merkledrop: already claimed")]
fn test__eth_sig_double_claim_fails() {
    let dungeon = deploy_dungeon();
    let recipient: ContractAddress = RECIPIENT_FELT.try_into().unwrap();

    let leaf = eth_leaf_data();
    let all_data = array![leaf.span()];
    let root = dungeon.register_drop(all_data.span(), 0xffffffffffffffff);
    let proof: Array<felt252> = array![0];
    dungeon.claim_with_eth_signature(root, proof.span(), leaf.span(), recipient, test_signature());

    // Second claim against the same leaf must revert.
    dungeon.claim_with_eth_signature(root, proof.span(), leaf.span(), recipient, test_signature());
}

#[test]
#[should_panic(expected: 'Invalid signature')]
fn test__eth_sig_wrong_recipient_fails() {
    let dungeon = deploy_dungeon();
    let leaf = eth_leaf_data();
    let all_data = array![leaf.span()];
    let root = dungeon.register_drop(all_data.span(), 0xffffffffffffffff);

    // The signature was made for the canonical recipient. Submitting it
    // with a different recipient should fail signature verification.
    let other_recipient: ContractAddress = 0xdead.try_into().unwrap();
    let proof: Array<felt252> = array![0];
    dungeon
        .claim_with_eth_signature(
            root, proof.span(), leaf.span(), other_recipient, test_signature(),
        );
}

// ------------------------ Arcade / NFT-ownership path -------------------------

#[test]
fn test__nft_register_and_claim_succeeds() {
    let dungeon = deploy_dungeon();
    let nft_holder: ContractAddress = NFT_HOLDER_FELT.try_into().unwrap();
    let collection: ContractAddress = NFT_COLLECTION_FELT.try_into().unwrap();

    let leaf = nft_leaf_data();
    let all_data = array![leaf.span()];
    let root = dungeon.register_drop(all_data.span(), 0xffffffffffffffff);

    // Mock the ERC721 `owner_of` so it reports `nft_holder` owns the token.
    mock_call(collection, selector!("owner_of"), nft_holder, 1);

    start_cheat_caller_address(dungeon.contract_address, nft_holder);
    let proof: Array<felt252> = array![0];
    dungeon.claim(root, proof.span(), leaf.span(), nft_holder);
    stop_cheat_caller_address(dungeon.contract_address);

    assert!(dungeon.has_access(nft_holder, DUNGEON_ID), "access not granted");
}

#[test]
#[should_panic(expected: "merkledrop: not recipient")]
fn test__nft_non_owner_cannot_claim() {
    let dungeon = deploy_dungeon();
    let nft_holder: ContractAddress = NFT_HOLDER_FELT.try_into().unwrap();
    let imposter: ContractAddress = 0xbeef.try_into().unwrap();
    let collection: ContractAddress = NFT_COLLECTION_FELT.try_into().unwrap();

    let leaf = nft_leaf_data();
    let all_data = array![leaf.span()];
    let root = dungeon.register_drop(all_data.span(), 0xffffffffffffffff);

    // owner_of returns nft_holder, but the imposter is calling.
    mock_call(collection, selector!("owner_of"), nft_holder, 1);

    start_cheat_caller_address(dungeon.contract_address, imposter);
    let proof: Array<felt252> = array![0];
    dungeon.claim(root, proof.span(), leaf.span(), imposter);
}

#[test]
#[should_panic(expected: "merkledrop: already claimed")]
fn test__nft_double_claim_fails() {
    let dungeon = deploy_dungeon();
    let nft_holder: ContractAddress = NFT_HOLDER_FELT.try_into().unwrap();
    let collection: ContractAddress = NFT_COLLECTION_FELT.try_into().unwrap();

    let leaf = nft_leaf_data();
    let all_data = array![leaf.span()];
    let root = dungeon.register_drop(all_data.span(), 0xffffffffffffffff);

    mock_call(collection, selector!("owner_of"), nft_holder, 2);

    start_cheat_caller_address(dungeon.contract_address, nft_holder);
    let proof: Array<felt252> = array![0];
    dungeon.claim(root, proof.span(), leaf.span(), nft_holder);
    dungeon.claim(root, proof.span(), leaf.span(), nft_holder);
}

// ------------------------ Shared mechanics -------------------------

#[test]
#[should_panic(expected: "merkledrop: tree not found")]
fn test__claim_unknown_tree_fails() {
    let dungeon = deploy_dungeon();
    let recipient: ContractAddress = RECIPIENT_FELT.try_into().unwrap();
    let leaf = eth_leaf_data();
    let proof: Array<felt252> = array![0];
    dungeon.claim_with_eth_signature(0x123, proof.span(), leaf.span(), recipient, test_signature());
}

// ------------------------ Off-chain root registration -------------------------

#[test]
fn test__register_root_stores_tree() {
    let dungeon = deploy_dungeon();
    let mut spy = spy_events();

    let root: felt252 = 0xabc;
    let end: u64 = 0xffffffffffffffff;
    let returned = dungeon.register_drop_root(root, end);

    assert!(returned == root, "register_root must return the input root");
    assert!(dungeon.tree_expiry(root) == end, "tree expiry not stored");

    // A single MerkleTreeCreated event with leaf_count = 0 (off-chain detail).
    spy
        .assert_emitted(
            @array![
                (
                    dungeon.contract_address,
                    MerkledropComponent::Event::MerkleTreeCreated(
                        MerkledropComponent::MerkleTreeCreated { root, end, leaf_count: 0 },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: "merkledrop: zero root")]
fn test__register_root_rejects_zero() {
    let dungeon = deploy_dungeon();
    dungeon.register_drop_root(0, 0xffffffffffffffff);
}

#[test]
#[should_panic(expected: "merkledrop: tree exists")]
fn test__register_root_rejects_duplicate() {
    let dungeon = deploy_dungeon();
    let root: felt252 = 0xabc;
    let end: u64 = 0xffffffffffffffff;
    dungeon.register_drop_root(root, end);
    // Second registration of the same root must revert.
    dungeon.register_drop_root(root, end);
}

#[test]
fn test__claim_with_eth_signature_after_register_root_succeeds() {
    let dungeon = deploy_dungeon();
    let recipient: ContractAddress = RECIPIENT_FELT.try_into().unwrap();

    // Compute the root off-chain (here: in the test) using the same Poseidon
    // scheme the component uses for verification. For a 1-leaf tree, the
    // alexandria pad makes the sibling proof `[0]`, so the root is just
    // poseidon-hash of (leaf, 0) in sorted order.
    let leaf = eth_leaf_data();
    let leaf_hash = poseidon_hash_span(leaf.span());
    let proof: Array<felt252> = array![0];
    let mut mt: MerkleTree<Hasher> = MerkleTreeImpl::<_, PoseidonHasherImpl>::new();
    let root = MerkleTreeImpl::<
        _, PoseidonHasherImpl,
    >::compute_root(ref mt, leaf_hash, proof.span());

    // Register only the precomputed root. No per-leaf events emitted.
    let end: u64 = 0xffffffffffffffff;
    let returned = dungeon.register_drop_root(root, end);
    assert!(returned == root, "register_root must return the input root");
    assert!(dungeon.tree_expiry(root) == end, "tree expiry not stored");

    // Claim against the off-chain-built root using the known-good signature.
    dungeon.claim_with_eth_signature(root, proof.span(), leaf.span(), recipient, test_signature());

    assert!(dungeon.has_access(recipient, DUNGEON_ID), "access not granted");
    assert!(dungeon.is_consumed(root, leaf_hash), "nullifier not set");
}
