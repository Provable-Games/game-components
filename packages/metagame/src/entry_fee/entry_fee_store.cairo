// SPDX-License-Identifier: BUSL-1.1

use core::num::traits::Zero;
use game_components_interfaces::distribution::Distribution;
use game_components_interfaces::entry_fee::{AdditionalShare, EntryFeeConfig};
use game_components_utilities::distribution::packed_shares::{
    CustomSharesImpl, CustomSharesTrait, SHARES_PER_SLOT as DISTRIBUTION_SHARES_PER_SLOT,
    calculate_slot_position,
};
use game_components_utilities::distribution::structs::{
    DIST_TYPE_CUSTOM, DIST_TYPE_EXPONENTIAL, DIST_TYPE_LINEAR, DIST_TYPE_UNIFORM,
    PackedDistribution,
};
use starknet::ContractAddress;
use crate::entry_fee::store::Store;
use crate::entry_fee::structs::{
    EntryFeeClaimType, EntryFeeData, EntryFeeDataStorePacking, PackedAdditionalSharesImpl,
    PackedAdditionalSharesTrait, SHARES_PER_SLOT, StoredAdditionalShare, unpack_additional_count,
    unpack_game_creator_claimed,
};

/// Store bridge: composes Store<T> reads with pure lib operations
pub trait EntryFeeStoreTrait<T> {
    /// Get entry fee configuration for a context.
    /// Returns None if no entry fee is set (token address is zero).
    fn get_entry_fee(self: @T, context_id: u64) -> Option<EntryFeeConfig>;
    /// Get additional shares for a context.
    /// Reconstructs from packed storage: reads 1 slot per 16 shares.
    fn get_additional_shares(self: @T, context_id: u64) -> Span<AdditionalShare>;
    /// Store entry fee config data (token, packed data, and additional shares).
    fn set_entry_fee_config(ref self: T, context_id: u64, config: @EntryFeeConfig);
    /// Check if an entry fee or extension has been set for a context.
    fn is_entry_fee_set(self: @T, context_id: u64) -> bool;
    /// Check if a claim has been made.
    fn is_claimed(self: @T, context_id: u64, claim_type: EntryFeeClaimType) -> bool;
    /// Mark a claim as completed.
    fn set_claimed(ref self: T, context_id: u64, claim_type: EntryFeeClaimType);
    /// Read extension config for a context.
    fn read_extension_config(self: @T, context_id: u64) -> Span<felt252>;
    /// Write extension config for a context.
    fn write_extension_config(ref self: T, context_id: u64, config: Span<felt252>);
    /// Store extension address.
    fn store_extension_address(ref self: T, context_id: u64, address: ContractAddress);
    /// Get extension address.
    fn get_extension(self: @T, context_id: u64) -> ContractAddress;
    /// Persist a custom distribution shares array for a context, packed 15
    /// per `felt252` slot. The share count is not stored here — callers must
    /// ensure the sibling `PackedDistribution.positions` for this context
    /// equals `shares.len()` (which `set_entry_fee_config` does atomically).
    fn store_distribution_shares(ref self: T, context_id: u64, shares: Span<u16>);
    /// Read `count` custom distribution shares for a context. Callers supply
    /// the count (typically `get_distribution().positions`); returns an empty
    /// array when `count == 0`.
    fn get_distribution_shares(self: @T, context_id: u64, count: u32) -> Array<u16>;
    /// Read a single custom distribution share at a 1-indexed position. Only
    /// one packed slot is read — this is the O(1) fast path for claim sites
    /// that need just one share, bypassing the full-array reconstruction.
    /// Callers must ensure the position is in range (1..=positions) since no
    /// bounds check is performed against the configured count.
    fn get_custom_share_at(self: @T, context_id: u64, position: u32) -> u16;
}

pub impl EntryFeeStoreImpl<T, +Store<T>, +Drop<T>> of EntryFeeStoreTrait<T> {
    fn get_entry_fee(self: @T, context_id: u64) -> Option<EntryFeeConfig> {
        let token_address = self.get_token(context_id);

        // If token address is zero, no entry fee is set
        if token_address.is_zero() {
            return Option::None;
        }

        let packed = self.get_data_raw(context_id);
        let data = EntryFeeDataStorePacking::unpack(packed);
        let additional_shares = self.get_additional_shares(context_id);

        // Convert stored shares back to Option<u16>
        // 0 means None
        let game_creator_share = if data.game_creator_share == 0 {
            Option::None
        } else {
            Option::Some(data.game_creator_share)
        };

        let refund_share = if data.refund_share == 0 {
            Option::None
        } else {
            Option::Some(data.refund_share)
        };

        // Rehydrate distribution shape + paid-places count. `dist_type == 0`
        // paired with `positions == 0` and a zero param is the "unset"
        // sentinel — return None so consumers can distinguish "no
        // distribution configured" from "Linear with weight 0".
        let packed_dist = self.get_distribution(context_id);
        let (distribution, distribution_count) = if packed_dist.dist_type == DIST_TYPE_LINEAR
            && packed_dist.dist_param == 0
            && packed_dist.positions == 0 {
            (Option::None, 0_u32)
        } else if packed_dist.dist_type == DIST_TYPE_LINEAR {
            (Option::Some(Distribution::Linear(packed_dist.dist_param)), packed_dist.positions)
        } else if packed_dist.dist_type == DIST_TYPE_EXPONENTIAL {
            (Option::Some(Distribution::Exponential(packed_dist.dist_param)), packed_dist.positions)
        } else if packed_dist.dist_type == DIST_TYPE_UNIFORM {
            (Option::Some(Distribution::Uniform), packed_dist.positions)
        } else {
            // DIST_TYPE_CUSTOM — return with empty shares span. Loading the
            // full array is O(N/15) storage reads and is only needed for UI
            // views; claim paths read a single share via `_get_custom_share_at`
            // (O(1)). The strict-sum validator (Σshares == available_share
            // at creation) means no dust needs to be tracked. Callers that
            // need the full array (e.g. view functions) call
            // `get_distribution_shares` explicitly, passing
            // `packed_dist.positions` as the count.
            (Option::Some(Distribution::Custom(array![].span())), packed_dist.positions)
        };

        Option::Some(
            EntryFeeConfig {
                token_address,
                amount: data.amount,
                game_creator_share,
                refund_share,
                additional_shares,
                distribution,
                distribution_count,
            },
        )
    }

    fn get_additional_shares(self: @T, context_id: u64) -> Span<AdditionalShare> {
        let packed = self.get_data_raw(context_id);
        let count = unpack_additional_count(packed);
        if count == 0 {
            return array![].span();
        }

        let mut shares: Array<AdditionalShare> = ArrayTrait::new();
        let mut current_slot: u8 = 0;
        let mut packed_shares = PackedAdditionalSharesImpl::new();

        let mut i: u8 = 0;
        while i < count {
            let slot_index: u8 = i / SHARES_PER_SLOT;
            let index_in_slot: u8 = i % SHARES_PER_SLOT;

            // Load new slot if needed
            if slot_index != current_slot || i == 0 {
                packed_shares = self.get_packed_shares(context_id, slot_index);
                current_slot = slot_index;
            }

            let recipient = self.get_additional_recipient(context_id, i);
            let stored = packed_shares.get_share(index_in_slot);
            shares.append(AdditionalShare { recipient, share_bps: stored.share_bps });
            i += 1;
        }

        shares.span()
    }

    fn set_entry_fee_config(ref self: T, context_id: u64, config: @EntryFeeConfig) {
        // Store token address
        self.set_token(context_id, *config.token_address);

        // Convert Option<u16> to stored values
        let game_creator_share: u16 = match config.game_creator_share {
            Option::Some(share) => *share,
            Option::None => 0,
        };

        let refund_share: u16 = match config.refund_share {
            Option::Some(share) => *share,
            Option::None => 0,
        };

        // Get additional shares count
        let additional_shares = *config.additional_shares;
        let additional_count: u8 = additional_shares.len().try_into().unwrap();

        // Store packed data (game_creator_claimed starts as false)
        let data = EntryFeeData {
            amount: *config.amount,
            game_creator_share,
            refund_share,
            game_creator_claimed: false,
            additional_count,
        };
        self.set_data_raw(context_id, EntryFeeDataStorePacking::pack(data));

        // Store additional shares using packed storage
        let mut current_slot: u8 = 0;
        let mut packed_shares = PackedAdditionalSharesImpl::new();

        let mut i: u32 = 0;
        while i < additional_shares.len() {
            let idx: u8 = i.try_into().unwrap();
            let slot_index: u8 = idx / SHARES_PER_SLOT;
            let index_in_slot: u8 = idx % SHARES_PER_SLOT;

            // If we moved to a new slot, write the previous one and start fresh
            if slot_index != current_slot && i > 0 {
                self.set_packed_shares(context_id, current_slot, packed_shares);
                packed_shares = PackedAdditionalSharesImpl::new();
                current_slot = slot_index;
            }

            let share = *additional_shares.at(i);
            // Store recipient separately (ContractAddress is 251 bits, can't pack)
            self.set_additional_recipient(context_id, idx, share.recipient);
            // Pack share data into current slot
            let stored = StoredAdditionalShare { share_bps: share.share_bps, claimed: false };
            packed_shares.set_share(index_in_slot, stored);
            i += 1;
        }

        // Write the last slot if we have any shares
        if additional_count > 0 {
            self.set_packed_shares(context_id, current_slot, packed_shares);
        }

        // Persist the distribution config (shape + paid-places count), and
        // for Custom, the shares array in packed out-of-band storage.
        let (dist_type, dist_param) = match config.distribution {
            Option::None => (DIST_TYPE_LINEAR, 0_u16),
            Option::Some(dist) => match dist {
                Distribution::Linear(w) => (DIST_TYPE_LINEAR, *w),
                Distribution::Exponential(w) => (DIST_TYPE_EXPONENTIAL, *w),
                Distribution::Uniform => (DIST_TYPE_UNIFORM, 0_u16),
                Distribution::Custom(_) => (DIST_TYPE_CUSTOM, 0_u16),
            },
        };
        // For Custom, paid places are defined by the shares array length;
        // otherwise use the configured count (0 = dynamic).
        let positions: u32 = match config.distribution {
            Option::Some(dist) => match dist {
                Distribution::Custom(shares) => (*shares).len(),
                _ => *config.distribution_count,
            },
            Option::None => 0_u32,
        };

        self.set_distribution(context_id, PackedDistribution { dist_type, dist_param, positions });

        if let Option::Some(dist) = config.distribution {
            if let Distribution::Custom(shares) = dist {
                self.store_distribution_shares(context_id, *shares);
            }
        }
    }

    fn is_entry_fee_set(self: @T, context_id: u64) -> bool {
        let token = self.get_token(context_id);
        let ext = self.get_extension(context_id);
        !token.is_zero() || !ext.is_zero()
    }

    fn is_claimed(self: @T, context_id: u64, claim_type: EntryFeeClaimType) -> bool {
        match claim_type {
            EntryFeeClaimType::GameCreator => {
                let packed = self.get_data_raw(context_id);
                unpack_game_creator_claimed(packed)
            },
            EntryFeeClaimType::Refund(token_id) => {
                self.get_refund_claimed(context_id, token_id)
            },
            EntryFeeClaimType::AdditionalShare(index) => {
                let slot_index: u8 = index / SHARES_PER_SLOT;
                let index_in_slot: u8 = index % SHARES_PER_SLOT;
                let packed = self.get_packed_shares(context_id, slot_index);
                let stored = packed.get_share(index_in_slot);
                stored.claimed
            },
        }
    }

    fn set_claimed(ref self: T, context_id: u64, claim_type: EntryFeeClaimType) {
        match claim_type {
            EntryFeeClaimType::GameCreator => {
                // Read raw packed, full unpack, modify, repack, write back
                let packed = self.get_data_raw(context_id);
                let mut data = EntryFeeDataStorePacking::unpack(packed);
                data.game_creator_claimed = true;
                self.set_data_raw(context_id, EntryFeeDataStorePacking::pack(data));
            },
            EntryFeeClaimType::Refund(token_id) => {
                self.set_refund_claimed(context_id, token_id, true);
            },
            EntryFeeClaimType::AdditionalShare(index) => {
                // Read packed slot, update the specific share's claimed bit, write back
                let slot_index: u8 = index / SHARES_PER_SLOT;
                let index_in_slot: u8 = index % SHARES_PER_SLOT;
                let mut packed = self.get_packed_shares(context_id, slot_index);
                let mut stored = packed.get_share(index_in_slot);
                stored.claimed = true;
                packed.set_share(index_in_slot, stored);
                self.set_packed_shares(context_id, slot_index, packed);
            },
        }
    }

    fn read_extension_config(self: @T, context_id: u64) -> Span<felt252> {
        let len = self.get_extension_config_len(context_id);
        let mut arr = ArrayTrait::new();
        let mut i: u64 = 0;
        loop {
            if i >= len {
                break;
            }
            arr.append(self.get_extension_config_at(context_id, i));
            i += 1;
        }
        arr.span()
    }

    fn write_extension_config(ref self: T, context_id: u64, config: Span<felt252>) {
        let mut i: u32 = 0;
        loop {
            if i >= config.len() {
                break;
            }
            self.push_extension_config(context_id, *config.at(i));
            i += 1;
        };
    }

    fn store_extension_address(ref self: T, context_id: u64, address: ContractAddress) {
        self.set_extension_address(context_id, address);
    }

    fn get_extension(self: @T, context_id: u64) -> ContractAddress {
        self.get_extension_address(context_id)
    }

    fn store_distribution_shares(ref self: T, context_id: u64, shares: Span<u16>) {
        if shares.len() == 0 {
            return;
        }

        let mut current_slot: u8 = 0;
        let mut packed_shares = CustomSharesImpl::new();

        let mut i: u32 = 0;
        for share in shares {
            let slot_index: u8 = (i / DISTRIBUTION_SHARES_PER_SLOT.into()).try_into().unwrap();
            let index_in_slot: u8 = (i % DISTRIBUTION_SHARES_PER_SLOT.into()).try_into().unwrap();

            if slot_index != current_slot && i > 0 {
                self.set_distribution_shares_packed(context_id, current_slot, packed_shares);
                packed_shares = CustomSharesImpl::new();
                current_slot = slot_index;
            }

            packed_shares.set_share(index_in_slot, *share);
            i += 1;
        }

        self.set_distribution_shares_packed(context_id, current_slot, packed_shares);
    }

    fn get_custom_share_at(self: @T, context_id: u64, position: u32) -> u16 {
        let (slot_index, index_in_slot) = calculate_slot_position(position - 1);
        self.get_distribution_shares_packed(context_id, slot_index).get_share(index_in_slot)
    }

    fn get_distribution_shares(self: @T, context_id: u64, count: u32) -> Array<u16> {
        let mut shares = ArrayTrait::new();
        if count == 0 {
            return shares;
        }

        let mut current_slot: u8 = 0;
        let mut packed_shares = CustomSharesImpl::new();

        let mut i: u32 = 0;
        while i < count {
            let slot_index: u8 = (i / DISTRIBUTION_SHARES_PER_SLOT.into()).try_into().unwrap();
            let index_in_slot: u8 = (i % DISTRIBUTION_SHARES_PER_SLOT.into()).try_into().unwrap();

            if slot_index != current_slot || i == 0 {
                packed_shares = self.get_distribution_shares_packed(context_id, slot_index);
                current_slot = slot_index;
            }

            shares.append(packed_shares.get_share(index_in_slot));
            i += 1;
        }
        shares
    }
}
