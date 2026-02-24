// SPDX-License-Identifier: BUSL-1.1

/// Pure Cairo library for prize operations.
/// This library provides core prize functionality without storage dependencies.
pub mod prize {
    use core::poseidon::poseidon_hash_span;
    use crate::prize::structs::PrizeType;

    /// Hash a prize type for use as storage key
    pub fn hash_prize_type(prize_type: PrizeType) -> felt252 {
        let mut data = ArrayTrait::new();
        prize_type.serialize(ref data);
        poseidon_hash_span(data.span())
    }
}
