// SPDX-License-Identifier: BUSL-1.1

use core::num::traits::Zero;
use starknet::ContractAddress;
use crate::prize::prize::prize::hash_prize_type;
use crate::prize::store::Store;
use crate::prize::structs::{
    CUSTOM_SHARES_PER_SLOT, CustomSharesImpl, ERC20Data, Prize, PrizeRecord, PrizeType,
    StoredPrizeTrait, TokenPrizePayload, TokenTypeData,
};

/// Store bridge: composes Store<T> reads with pure lib operations
pub trait PrizeStoreTrait<T> {
    /// Get a built-in token prize as a `PrizeRecord`, converting from
    /// storage format and restoring custom shares. Extension prizes
    /// are routed via the component's `resolve_prize` before this is
    /// called and never reach the store bridge.
    fn get_token_record(self: @T, prize_id: u64) -> PrizeRecord;
    /// Get custom shares for a prize (reconstructs from packed storage).
    ///
    /// O(count/15) storage reads. Only view surfaces need the whole curve —
    /// a claim wants exactly one share, so it calls `get_custom_share_at`.
    fn get_custom_shares(self: @T, prize_id: u64) -> Array<u16>;
    /// One share by 1-indexed position, without rebuilding the array.
    ///
    /// Mirrors `EntryFeeStoreTrait::get_custom_share_at`. Shares are packed
    /// 15 to a felt, so this is a single storage read at any position.
    fn get_custom_share_at(self: @T, prize_id: u64, position: u32) -> u16;
    /// Store a token prize. Takes the host-assigned context + sponsor
    /// alongside the variant payload; converts to StoredPrize for
    /// storage.
    fn set_token_record(
        ref self: T,
        prize_id: u64,
        context_id: u64,
        sponsor_address: ContractAddress,
        payload: TokenPrizePayload,
    );
    /// Get total prizes count
    fn get_total_prizes(self: @T) -> u64;
    /// Increment total prizes and return the new prize ID
    fn increment_prize_count(ref self: T) -> u64;
    /// Check if a prize has been claimed
    fn is_prize_claimed(self: @T, context_id: u64, prize_type: PrizeType) -> bool;
    /// Check if a prize has been claimed using pre-computed hash
    fn is_prize_claimed_by_hash(self: @T, context_id: u64, hash: felt252) -> bool;
    /// Mark a prize as claimed
    fn set_prize_claimed(ref self: T, context_id: u64, prize_type: PrizeType);
    /// Mark a prize as claimed using pre-computed hash
    fn set_prize_claimed_by_hash(ref self: T, context_id: u64, hash: felt252);
    /// Assert that a prize exists (has non-zero token address)
    fn assert_prize_exists(self: @T, prize_id: u64);
    /// Assert that a prize has not been claimed
    fn assert_prize_not_claimed(self: @T, context_id: u64, prize_type: PrizeType);
    /// Assert that a prize has not been claimed using pre-computed hash
    fn assert_prize_not_claimed_by_hash(self: @T, context_id: u64, hash: felt252);
    /// Store custom shares in packed format
    fn store_custom_shares(ref self: T, prize_id: u64, shares: Span<u16>);
}

pub impl PrizeStoreImpl<T, +Store<T>, +Drop<T>> of PrizeStoreTrait<T> {
    fn get_token_record(self: @T, prize_id: u64) -> PrizeRecord {
        let stored = Store::get_prize(self, prize_id);
        let mut record = stored.to_token_record(prize_id);

        // For custom distributions, restore the shares from separate storage.
        // Reach into the Token payload (we know it's Token because
        // `to_token_record` always builds the Token variant for the
        // built-in store path).
        let new_payload = match record.prize {
            Prize::Token(payload) => {
                let new_token_type = match payload.token_type {
                    TokenTypeData::erc20(erc20_data) => {
                        let distribution = match erc20_data.distribution {
                            Option::Some(dist) => {
                                match dist {
                                    game_components_utilities::distribution::structs::Distribution::Custom(_) => {
                                        // Return the shape with an empty span
                                        // rather than rebuilding the curve.
                                        // Loading it is O(count/15) storage
                                        // reads on a path that runs on every
                                        // claim, and a claim needs exactly one
                                        // share — `get_custom_share_at`.
                                        // View surfaces call
                                        // `get_custom_shares` explicitly.
                                        // Mirrors the entry-fee store, which
                                        // has always done this.
                                        Option::Some(
                                            game_components_utilities::distribution::structs::Distribution::Custom(
                                                array![].span(),
                                            ),
                                        )
                                    },
                                    _ => Option::Some(dist),
                                }
                            },
                            Option::None => Option::None,
                        };
                        TokenTypeData::erc20(
                            ERC20Data {
                                amount: erc20_data.amount,
                                distribution,
                                distribution_count: erc20_data.distribution_count,
                            },
                        )
                    },
                    TokenTypeData::erc721(erc721_data) => TokenTypeData::erc721(erc721_data),
                };
                TokenPrizePayload {
                    token_address: payload.token_address, token_type: new_token_type,
                }
            },
            Prize::Extension(_) => panic!("get_token_record: storage returned Extension variant"),
        };
        record.prize = Prize::Token(new_payload);
        record
    }

    fn get_custom_share_at(self: @T, prize_id: u64, position: u32) -> u16 {
        let index: u32 = position - 1;
        let slot_index: u8 = (index / CUSTOM_SHARES_PER_SLOT.into()).try_into().unwrap();
        let index_in_slot: u8 = (index % CUSTOM_SHARES_PER_SLOT.into()).try_into().unwrap();
        Store::get_custom_shares_packed(self, prize_id, slot_index).get_share(index_in_slot)
    }

    fn get_custom_shares(self: @T, prize_id: u64) -> Array<u16> {
        let count = Store::get_custom_shares_count(self, prize_id);
        let mut shares = ArrayTrait::new();
        if count == 0 {
            return shares;
        }

        let mut current_slot: u8 = 0;
        let mut packed_shares = CustomSharesImpl::new();

        let mut i: u32 = 0;
        while i < count {
            let slot_index: u8 = (i / CUSTOM_SHARES_PER_SLOT.into()).try_into().unwrap();
            let index_in_slot: u8 = (i % CUSTOM_SHARES_PER_SLOT.into()).try_into().unwrap();

            // Load new slot if needed
            if slot_index != current_slot || i == 0 {
                packed_shares = Store::get_custom_shares_packed(self, prize_id, slot_index);
                current_slot = slot_index;
            }

            shares.append(packed_shares.get_share(index_in_slot));
            i += 1;
        }
        shares
    }

    fn set_token_record(
        ref self: T,
        prize_id: u64,
        context_id: u64,
        sponsor_address: ContractAddress,
        payload: TokenPrizePayload,
    ) {
        let stored = StoredPrizeTrait::from_token_record(context_id, sponsor_address, payload);
        Store::set_prize(ref self, prize_id, stored);
    }

    fn get_total_prizes(self: @T) -> u64 {
        Store::get_total_prizes(self)
    }

    fn increment_prize_count(ref self: T) -> u64 {
        let current = Store::get_total_prizes(@self);
        let new_count = current + 1;
        Store::set_total_prizes(ref self, new_count);
        new_count
    }

    fn is_prize_claimed(self: @T, context_id: u64, prize_type: PrizeType) -> bool {
        let prize_type_hash = hash_prize_type(prize_type);
        self.is_prize_claimed_by_hash(context_id, prize_type_hash)
    }

    fn is_prize_claimed_by_hash(self: @T, context_id: u64, hash: felt252) -> bool {
        Store::get_claim(self, context_id, hash)
    }

    fn set_prize_claimed(ref self: T, context_id: u64, prize_type: PrizeType) {
        let prize_type_hash = hash_prize_type(prize_type);
        self.set_prize_claimed_by_hash(context_id, prize_type_hash);
    }

    fn set_prize_claimed_by_hash(ref self: T, context_id: u64, hash: felt252) {
        Store::set_claim(ref self, context_id, hash, true);
    }

    fn assert_prize_exists(self: @T, prize_id: u64) {
        let stored = Store::get_prize(self, prize_id);
        assert!(!stored.token_address.is_zero(), "Prize: Prize key {} does not exist", prize_id);
    }

    fn assert_prize_not_claimed(self: @T, context_id: u64, prize_type: PrizeType) {
        let prize_type_hash = hash_prize_type(prize_type);
        self.assert_prize_not_claimed_by_hash(context_id, prize_type_hash);
    }

    fn assert_prize_not_claimed_by_hash(self: @T, context_id: u64, hash: felt252) {
        let claimed = Store::get_claim(self, context_id, hash);
        assert!(!claimed, "Prize: Prize has already been claimed");
    }

    fn store_custom_shares(ref self: T, prize_id: u64, shares: Span<u16>) {
        let shares_len: u32 = shares.len().try_into().unwrap();
        Store::set_custom_shares_count(ref self, prize_id, shares_len);

        // Pack shares into slots (15 shares per slot)
        let mut current_slot: u8 = 0;
        let mut packed_shares = CustomSharesImpl::new();

        let mut i: u32 = 0;
        for share in shares {
            let slot_index: u8 = (i / CUSTOM_SHARES_PER_SLOT.into()).try_into().unwrap();
            let index_in_slot: u8 = (i % CUSTOM_SHARES_PER_SLOT.into()).try_into().unwrap();

            // If we moved to a new slot, write the previous one and start fresh
            if slot_index != current_slot && i > 0 {
                Store::set_custom_shares_packed(ref self, prize_id, current_slot, packed_shares);
                packed_shares = CustomSharesImpl::new();
                current_slot = slot_index;
            }

            packed_shares.set_share(index_in_slot, *share);
            i += 1;
        }

        // Write the last slot if we have any shares
        if shares_len > 0 {
            Store::set_custom_shares_packed(ref self, prize_id, current_slot, packed_shares);
        }
    }
}
