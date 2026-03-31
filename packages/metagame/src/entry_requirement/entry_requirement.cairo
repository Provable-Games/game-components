// SPDX-License-Identifier: BUSL-1.1

/// Pure Cairo library for entry requirement operations.
/// This library provides core entry requirement functionality without storage dependencies.
pub mod entry_requirement {
    use core::poseidon::poseidon_hash_span;
    use crate::entry_requirement::structs::QualificationProof;

    // Entry requirement type constants
    pub const REQ_TYPE_TOKEN: u8 = 0;
    pub const REQ_TYPE_EXTENSION: u8 = 1;
    pub const REQ_TYPE_NONE: u8 = 255;

    /// Hash a qualification proof for use as storage key
    pub fn hash_qualification_proof(proof: QualificationProof) -> felt252 {
        let mut data = ArrayTrait::new();
        proof.serialize(ref data);
        poseidon_hash_span(data.span())
    }
}
