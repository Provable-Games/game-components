// SPDX-License-Identifier: BUSL-1.1
//! Storage-independent APIs. The host supplies Store and enforces access control,
//! lifecycle eligibility and reentrancy protection before internal mutations.
use core::num::traits::Zero;
use game_components_interfaces::prize::IPrize;
use metagame_extensions_interfaces::extension::ExtensionConfig;
use metagame_extensions_interfaces::prize_extension::{
    IPRIZE_EXTENSION_ID, IPrizeExtensionDispatcher, IPrizeExtensionDispatcherTrait,
};
use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::{ContractAddress, get_caller_address, get_contract_address};
use crate::prize::prize::prize::hash_prize_type;
use crate::prize::prize_store::{PrizeStoreImpl, PrizeStoreTrait};
use crate::prize::store::Store;
use crate::prize::structs::{
    ExtensionPrizePayload, Prize, PrizeRecord, PrizeType, TokenPrizePayload, TokenTypeData,
};

/// Resolve a `prize_id` to its full `Prize` sum-type view.
///
/// Branching: the `Prize_extension_prize_context` reverse index is
/// populated only for extension prizes. A non-zero read identifies
/// the prize as an extension, lets us reconstruct the
/// `(context_id, prize_id)` key, and we dispatch to the
/// extension's `get_config` view to fetch the original config
/// blob. Built-in prizes fall through to the
/// `PrizeStoreTrait::get_token_prize` store-bridge path.
fn resolve_prize<TContractState, +Store<TContractState>, +Drop<TContractState>>(
    self: @TContractState, prize_id: u64,
) -> PrizeRecord {
    let context_id = Store::get_extension_prize_context(self, prize_id);
    if context_id == 0 {
        return PrizeStoreTrait::get_token_record(self, prize_id);
    }
    let extension_address = Store::get_extension_address(self, context_id, prize_id);
    let sponsor_address = Store::get_extension_prize_sponsor(self, prize_id);
    let context_owner = get_contract_address();
    let dispatcher = IPrizeExtensionDispatcher { contract_address: extension_address };
    let extension_config = dispatcher.get_config(context_owner, context_id, prize_id);
    PrizeRecord {
        id: prize_id,
        context_id,
        sponsor_address,
        prize: Prize::Extension(
            ExtensionPrizePayload { address: extension_address, config: extension_config },
        ),
    }
}

#[starknet::embeddable]
pub impl PrizeImpl<
    TContractState, +Store<TContractState>, +Drop<TContractState>,
> of IPrize<TContractState> {
    fn get_prize(self: @TContractState, prize_id: u64) -> PrizeRecord {
        resolve_prize(self, prize_id)
    }

    fn get_total_prizes(self: @TContractState) -> u64 {
        PrizeStoreTrait::get_total_prizes(self)
    }

    fn is_prize_claimed(self: @TContractState, context_id: u64, prize_type: PrizeType) -> bool {
        PrizeStoreTrait::is_prize_claimed(self, context_id, prize_type)
    }
}

#[generate_trait]
pub impl PrizeInternalImpl<
    TContractState, +Store<TContractState>, +Drop<TContractState>,
> of PrizeInternalTrait<TContractState> {
    /// Get a prize by its ID.
    ///
    /// For built-in (`Prize::Config`) prizes this reads the
    /// `StoredPrize` slot and assembles a `PrizeData { kind: Config, ... }`.
    ///
    /// For extension (`Prize::Extension`) prizes this:
    ///   1. detects the kind via the `prize_id -> context_id`
    ///      reverse index populated by `_set_extension`,
    ///   2. reads the extension address from
    ///      `Prize_extension_address[(context_id, prize_id)]`,
    ///   3. dispatches `IPrizeExtension.get_config(...)` to fetch
    ///      the original config blob the sponsor passed at
    ///      `add_prize` time,
    ///   4. assembles a `PrizeData { kind: Extension, ... }`.
    ///
    /// Note: extension prizes incur a cross-contract call on every
    /// read. Callers wanting bulk reads should batch / cache
    /// accordingly.
    fn _get_prize(self: @TContractState, prize_id: u64) -> PrizeRecord {
        resolve_prize(self, prize_id)
    }

    /// Get custom shares for a prize (used for Custom distribution)
    /// Uses packed storage: reads 1 slot per 15 shares instead of 1 slot per share
    fn _get_custom_shares(self: @TContractState, prize_id: u64) -> Array<u16> {
        PrizeStoreTrait::get_custom_shares(self, prize_id)
    }

    /// One custom share by 1-indexed position — a single storage read.
    ///
    /// `_get_prize` deliberately returns Custom with an empty span, so a
    /// claim settling one position reads its share through here instead of
    /// paying to rebuild the whole curve.
    fn _get_custom_share_at(self: @TContractState, prize_id: u64, position: u32) -> u16 {
        PrizeStoreTrait::get_custom_share_at(self, prize_id, position)
    }

    /// Store a token-prize record (converts to StoredPrize for storage).
    /// Extension prizes are not persisted via this path.
    fn set_token_record(
        ref self: TContractState,
        prize_id: u64,
        context_id: u64,
        sponsor_address: ContractAddress,
        payload: TokenPrizePayload,
    ) {
        PrizeStoreTrait::set_token_record(ref self, prize_id, context_id, sponsor_address, payload);
    }

    /// Get total prizes count (internal)
    fn _get_total_prizes(self: @TContractState) -> u64 {
        PrizeStoreTrait::get_total_prizes(self)
    }

    /// Increment total prizes and return the new prize ID
    fn increment_prize_count(ref self: TContractState) -> u64 {
        PrizeStoreTrait::increment_prize_count(ref self)
    }

    /// Hash a prize type for use as storage key
    fn hash_prize_type(self: @TContractState, prize_type: PrizeType) -> felt252 {
        hash_prize_type(prize_type)
    }

    /// Check if a prize has been claimed (internal)
    fn _is_prize_claimed(self: @TContractState, context_id: u64, prize_type: PrizeType) -> bool {
        PrizeStoreTrait::is_prize_claimed(self, context_id, prize_type)
    }

    /// Check if a prize has been claimed using pre-computed hash (gas optimization)
    fn _is_prize_claimed_by_hash(
        self: @TContractState, context_id: u64, prize_type_hash: felt252,
    ) -> bool {
        PrizeStoreTrait::is_prize_claimed_by_hash(self, context_id, prize_type_hash)
    }

    /// Mark a prize as claimed
    fn set_prize_claimed(ref self: TContractState, context_id: u64, prize_type: PrizeType) {
        PrizeStoreTrait::set_prize_claimed(ref self, context_id, prize_type);
    }

    /// Mark a prize as claimed using pre-computed hash (gas optimization)
    fn _set_prize_claimed_by_hash(
        ref self: TContractState, context_id: u64, prize_type_hash: felt252,
    ) {
        PrizeStoreTrait::set_prize_claimed_by_hash(ref self, context_id, prize_type_hash);
    }

    /// Assert that a prize exists (has non-zero token address)
    fn assert_prize_exists(self: @TContractState, prize_id: u64) {
        PrizeStoreTrait::assert_prize_exists(self, prize_id);
    }

    /// Assert that a prize has not been claimed
    fn assert_prize_not_claimed(self: @TContractState, context_id: u64, prize_type: PrizeType) {
        PrizeStoreTrait::assert_prize_not_claimed(self, context_id, prize_type);
    }

    /// Read the leaderboard position a built-in prize pays out to.
    /// Zero when unset (distributed prizes, extension prizes, or
    /// prizes added without a position).
    fn get_payout_position(self: @TContractState, prize_id: u64) -> u32 {
        Store::get_payout_position(self, prize_id)
    }

    /// Record the leaderboard position a built-in prize pays out to.
    /// Hosts call this at add_prize time for non-distributed token
    /// prizes; the component then owns the per-prize position storage
    /// so any other consumer of PrizeComponent shares the same
    /// position-aware claim flow.
    fn set_payout_position(ref self: TContractState, prize_id: u64, position: u32) {
        Store::set_payout_position(ref self, prize_id, position);
    }

    /// Assert that a prize has not been claimed using pre-computed hash (gas optimization)
    fn _assert_prize_not_claimed_by_hash(
        self: @TContractState, context_id: u64, prize_type_hash: felt252,
    ) {
        PrizeStoreTrait::assert_prize_not_claimed_by_hash(self, context_id, prize_type_hash);
    }

    /// Add a prize or set extension for a context.
    /// Returns the prize_id in both cases.
    /// - `Prize::Token(payload)`: deposits tokens, stores prize
    ///   data. Host assigns id/context_id/sponsor_address.
    /// - `Prize::Extension(payload)`: increments prize count,
    ///   registers the extension address keyed by
    ///   `(context_id, prize_id)`, captures sponsor, and
    ///   dispatches `IPrizeExtension.add_prize(...)`.
    fn add_prize(ref self: TContractState, context_id: u64, prize: Prize) -> u64 {
        match prize {
            Prize::Token(payload) => self._add_token_prize(context_id, payload),
            Prize::Extension(payload) => {
                let ext = ExtensionConfig { address: payload.address, config: payload.config };
                assert!(!ext.address.is_zero(), "Prize: Extension address cannot be zero");
                let src5 = ISRC5Dispatcher { contract_address: ext.address };
                let display_address: felt252 = ext.address.into();
                assert!(
                    src5.supports_interface(IPRIZE_EXTENSION_ID),
                    "Prize: Extension {} does not support IPrizeExtension",
                    display_address,
                );
                let prize_id = PrizeStoreTrait::increment_prize_count(ref self);
                self._set_extension(context_id, prize_id, ext);
                prize_id
            },
        }
    }

    /// Internal: deposit tokens, store prize data, return prize_id.
    /// Host fills in the id (assigned), context_id (caller-supplied),
    /// and sponsor_address (`get_caller_address()`) around the
    /// supplied `payload`.
    fn _add_token_prize(
        ref self: TContractState, context_id: u64, payload: TokenPrizePayload,
    ) -> u64 {
        let token_address = payload.token_address;
        let token_type = payload.token_type;

        // Deposit the prize tokens
        match @token_type {
            TokenTypeData::erc20(erc20_data) => {
                let amount = *erc20_data.amount;
                let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
                assert!(amount > 0, "Prize: ERC20 prize token amount must be greater than 0");
                assert!(
                    token_dispatcher
                        .transfer_from(get_caller_address(), get_contract_address(), amount.into()),
                    "Prize: ERC20 transfer_from failed",
                );
            },
            TokenTypeData::erc721(erc721_data) => {
                let token_id = *erc721_data.id;
                let token_dispatcher = IERC721Dispatcher { contract_address: token_address };
                token_dispatcher
                    .transfer_from(get_caller_address(), get_contract_address(), token_id.into());
            },
        }

        // Get next prize ID
        let id = PrizeStoreTrait::increment_prize_count(ref self);

        // Store custom shares if this is a Custom distribution (using packed storage)
        if let TokenTypeData::erc20(erc20_data) = @token_type {
            if let Option::Some(dist) = erc20_data.distribution {
                if let game_components_utilities::distribution::structs::Distribution::Custom(shares) =
                    dist {
                    PrizeStoreTrait::store_custom_shares(ref self, id, *shares);
                }
            }
        }

        // Persist the built-in token prize. Host fills id,
        // context_id, sponsor_address around the supplied payload.
        let sponsor = get_caller_address();
        let payload = TokenPrizePayload { token_address, token_type };
        PrizeStoreTrait::set_token_record(ref self, id, context_id, sponsor, payload);

        id
    }

    /// Internal: persist the extension address + the reverse
    /// `prize_id -> context_id` index, then forward the config to
    /// the extension. The config blob is NOT persisted here — it
    /// lives on the extension contract, and reads (`get_prize`)
    /// fetch it back via `IPrizeExtension.get_config`.
    fn _set_extension(
        ref self: TContractState, context_id: u64, prize_id: u64, ext: ExtensionConfig,
    ) {
        Store::set_extension_address(ref self, context_id, prize_id, ext.address);
        // Reverse index for the prize_id-only `get_prize` lookup.
        Store::set_extension_prize_context(ref self, prize_id, context_id);
        // Capture sponsor (the caller of the host's `add_prize`).
        Store::set_extension_prize_sponsor(ref self, prize_id, get_caller_address());

        let dispatcher = IPrizeExtensionDispatcher { contract_address: ext.address };
        dispatcher.add_prize(context_id, prize_id, ext.config);
    }

    /// Forward a payout call to the prize extension configured for
    /// `(context_id, prize_id)`. Reverts if `prize_id` was added via
    /// the built-in `Prize::Token` path (no extension address stored).
    ///
    /// The host is a pure dispatcher: it passes the supplied
    /// `(token_id, payout_params)` straight through. The extension
    /// resolves recipient, eligibility, and dedupe entirely from its
    /// own state. `token_id = Some(id)` typically signals a claim
    /// (extension derives recipient via `owner_of(id)`); `None`
    /// signals a non-claim flow (sponsor refund, dao distribution,
    /// raffle) and the extension extracts whatever it needs from
    /// `payout_params`.
    ///
    /// Hosts are responsible for any cross-cutting concerns
    /// (finalization checks, reentrancy guards) before invoking this.
    fn payout_prize_extension(
        ref self: TContractState,
        context_id: u64,
        prize_id: u64,
        token_id: Option<felt252>,
        payout_params: Span<felt252>,
    ) {
        let extension_address = Store::get_extension_address(@self, context_id, prize_id);
        assert!(!extension_address.is_zero(), "Prize: No extension configured for prize");
        let dispatcher = IPrizeExtensionDispatcher { contract_address: extension_address };
        dispatcher.payout_prize(context_id, prize_id, token_id, payout_params);
    }

    /// Payout full ERC20 amount to a recipient
    fn payout_erc20(
        ref self: TContractState,
        token_address: ContractAddress,
        amount: u128,
        recipient: ContractAddress,
    ) {
        let erc20 = IERC20Dispatcher { contract_address: token_address };
        assert!(erc20.transfer(recipient, amount.into()), "Prize: ERC20 transfer failed");
    }

    /// Payout ERC721 to a recipient
    fn payout_erc721(
        ref self: TContractState,
        token_address: ContractAddress,
        token_id: u128,
        recipient: ContractAddress,
    ) {
        let erc721 = IERC721Dispatcher { contract_address: token_address };
        erc721.transfer_from(get_contract_address(), recipient, token_id.into());
    }

    /// Refund ERC20 prize to the original sponsor
    fn refund_prize_erc20(ref self: TContractState, prize_id: u64, amount: u128) {
        let record = PrizeStoreTrait::get_token_record(@self, prize_id);
        let token_address = match record.prize {
            Prize::Token(payload) => payload.token_address,
            Prize::Extension(_) => panic!("Prize: extension prize cannot be refunded as ERC20"),
        };
        let erc20 = IERC20Dispatcher { contract_address: token_address };
        assert!(
            erc20.transfer(record.sponsor_address, amount.into()),
            "Prize: ERC20 refund transfer failed",
        );
    }

    /// Refund ERC721 prize to the original sponsor
    fn refund_prize_erc721(ref self: TContractState, prize_id: u64, token_id: u128) {
        let record = PrizeStoreTrait::get_token_record(@self, prize_id);
        let token_address = match record.prize {
            Prize::Token(payload) => payload.token_address,
            Prize::Extension(_) => panic!("Prize: extension prize cannot be refunded as ERC721"),
        };
        let erc721 = IERC721Dispatcher { contract_address: token_address };
        erc721.transfer_from(get_contract_address(), record.sponsor_address, token_id.into());
    }

    // --- Extension helpers ---

    /// Get extension address for a context and prize (zero = built-in).
    fn get_extension_address(
        self: @TContractState, context_id: u64, prize_id: u64,
    ) -> ContractAddress {
        Store::get_extension_address(self, context_id, prize_id)
    }
}
