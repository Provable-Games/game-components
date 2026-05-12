//! Merkle-drop component with two claim paths sharing one nullifier + hook.
//!
//! Shared mechanics:
//!   - On-chain tree building (alexandria Poseidon). The operator submits
//!     raw leaf data; the contract computes the root, stores it, and emits
//!     one `LeafRegistered` event per leaf carrying the proof. Off-chain
//!     pipelines parse these events from the registration receipt to
//!     assemble per-leaf claim URLs / proofs.
//!   - Per-leaf single-use nullifier keyed by `(root, leaf_hash)`.
//!   - The implementing contract receives an `on_merkledrop_claim`
//!     callback after verification succeeds.
//!
//! Claim paths:
//!
//!   A. `claim(root, proofs, data, receiver)` (arcade-style).
//!      The implementing contract overrides `get_recipient` to extract the
//!      expected claimer from `data`. The component asserts
//!      `get_caller_address() == get_recipient(data)`. This gates
//!      NFT-ownership flows, allowlists, etc.
//!
//!   B. `claim_with_eth_signature(root, proofs, data, receiver, signature)`
//!      (bearer credential). Leaf's `data[0]` is an EVM address; the caller
//!      submits a secp256k1 signature over `receiver` that recovers to
//!      that address. Used for QR-code drops where the bearer key is the
//!      credential.

#[starknet::component]
pub mod MerkledropComponent {
    use alexandria_merkle_tree::merkle_tree::poseidon::PoseidonHasherImpl;
    use alexandria_merkle_tree::merkle_tree::{
        Hasher, MerkleTree, MerkleTreeImpl, StoredMerkleTreeImpl,
    };
    use core::poseidon::poseidon_hash_span;
    use starknet::eth_address::EthAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::merkledrop::signature::{EthereumSignature, verify_claim_signature};

    /// Implementing contracts override both methods.
    pub trait MerkledropTrait<TContractState, +HasComponent<TContractState>> {
        /// Extract the expected claimer from a leaf's `data`. Called only by
        /// `claim` (the arcade-style path). Implementations decide the
        /// binding -- e.g. read `data[0]` as a Starknet address, or call
        /// `ERC721.owner_of` on `(data[0], u256 { low: data[1], high: data[2] })`
        /// for NFT-gating.
        fn get_recipient(
            self: @ComponentState<TContractState>, data: Span<felt252>,
        ) -> ContractAddress;

        /// Distribute the asset/access after verification succeeds.
        fn on_merkledrop_claim(
            ref self: ComponentState<TContractState>,
            root: felt252,
            leaf: felt252,
            receiver: ContractAddress,
            data: Span<felt252>,
        );
    }

    #[storage]
    pub struct Storage {
        /// root -> expiry timestamp (0 means tree not registered).
        pub trees: Map<felt252, u64>,
        /// (root, leaf_hash) -> already consumed (nullifier).
        pub claims: Map<(felt252, felt252), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MerkleTreeCreated: MerkleTreeCreated,
        LeafRegistered: LeafRegistered,
        ClaimSucceeded: ClaimSucceeded,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MerkleTreeCreated {
        #[key]
        pub root: felt252,
        pub end: u64,
        pub leaf_count: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LeafRegistered {
        #[key]
        pub root: felt252,
        #[key]
        pub index: u32,
        pub leaf_hash: felt252,
        pub proofs: Span<felt252>,
        pub data: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ClaimSucceeded {
        #[key]
        pub root: felt252,
        #[key]
        pub leaf_hash: felt252,
        pub receiver: ContractAddress,
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Merkledrop: MerkledropTrait<TContractState>,
    > of InternalTrait<TContractState> {
        /// Build a tree from raw leaf data, store the root, and emit per-leaf
        /// proofs as events. Returns the root, which doubles as the tree id.
        fn register(
            ref self: ComponentState<TContractState>, data: Span<Span<felt252>>, end: u64,
        ) -> felt252 {
            assert!(data.len() > 0, "merkledrop: empty data");

            let mut leaves: Array<felt252> = array![];
            let mut i: u32 = 0;
            while i < data.len() {
                leaves.append(poseidon_hash_span(*data.at(i)));
                i += 1;
            }

            let mut tree = StoredMerkleTreeImpl::<_, PoseidonHasherImpl>::new(leaves.clone());
            let root = StoredMerkleTreeImpl::<_, PoseidonHasherImpl>::get_root(ref tree);

            assert!(self.trees.entry(root).read() == 0, "merkledrop: tree exists");
            self.trees.entry(root).write(end);

            self.emit(MerkleTreeCreated { root, end, leaf_count: data.len() });

            let mut index: u32 = 0;
            while index < data.len() {
                let proofs = StoredMerkleTreeImpl::<
                    _, PoseidonHasherImpl,
                >::get_proof(ref tree, index);
                self
                    .emit(
                        LeafRegistered {
                            root,
                            index,
                            leaf_hash: *leaves.at(index),
                            proofs,
                            data: *data.at(index),
                        },
                    );
                index += 1;
            }

            root
        }

        /// Arcade-style claim. The implementing contract's `get_recipient`
        /// decides who is allowed to claim this leaf; the component just
        /// asserts the caller matches.
        fn claim(
            ref self: ComponentState<TContractState>,
            root: felt252,
            proofs: Span<felt252>,
            data: Span<felt252>,
            receiver: ContractAddress,
        ) {
            let end = self.trees.entry(root).read();
            assert!(end != 0, "merkledrop: tree not found");
            assert!(get_block_timestamp() < end, "merkledrop: tree expired");
            assert!(data.len() > 0, "merkledrop: empty leaf data");

            let expected = Merkledrop::get_recipient(@self, data);
            assert!(expected == get_caller_address(), "merkledrop: not recipient");

            self.verify_consume_and_forward(root, proofs, data, receiver);
        }

        /// Bearer-credential claim. The leaf's `data[0]` must equal the EVM
        /// address recovered from `signature` over `receiver`.
        fn claim_with_eth_signature(
            ref self: ComponentState<TContractState>,
            root: felt252,
            proofs: Span<felt252>,
            data: Span<felt252>,
            receiver: ContractAddress,
            signature: EthereumSignature,
        ) {
            let end = self.trees.entry(root).read();
            assert!(end != 0, "merkledrop: tree not found");
            assert!(get_block_timestamp() < end, "merkledrop: tree expired");
            assert!(data.len() > 0, "merkledrop: empty leaf data");

            let eth_address: EthAddress = (*data.at(0)).try_into().unwrap();
            verify_claim_signature(signature, eth_address, receiver);

            self.verify_consume_and_forward(root, proofs, data, receiver);
        }

        fn is_consumed(
            self: @ComponentState<TContractState>, root: felt252, leaf_hash: felt252,
        ) -> bool {
            self.claims.entry((root, leaf_hash)).read()
        }

        fn tree_expiry(self: @ComponentState<TContractState>, root: felt252) -> u64 {
            self.trees.entry(root).read()
        }

        /// Shared tail used by both claim paths after credential verification:
        /// merkle proof check, nullifier consume, event, hook callback.
        fn verify_consume_and_forward(
            ref self: ComponentState<TContractState>,
            root: felt252,
            proofs: Span<felt252>,
            data: Span<felt252>,
            receiver: ContractAddress,
        ) {
            let leaf = poseidon_hash_span(data);
            let mut mt: MerkleTree<Hasher> = MerkleTreeImpl::<_, PoseidonHasherImpl>::new();
            let valid = MerkleTreeImpl::<_, PoseidonHasherImpl>::verify(ref mt, root, leaf, proofs);
            assert!(valid, "merkledrop: invalid proof");

            let already = self.claims.entry((root, leaf)).read();
            assert!(!already, "merkledrop: already claimed");
            self.claims.entry((root, leaf)).write(true);

            self.emit(ClaimSucceeded { root, leaf_hash: leaf, receiver });

            Merkledrop::on_merkledrop_claim(ref self, root, leaf, receiver, data);
        }
    }
}
