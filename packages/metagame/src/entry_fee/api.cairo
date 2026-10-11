// SPDX-License-Identifier: BUSL-1.1
//! Storage-independent APIs. The host supplies Store and enforces access control,
//! lifecycle eligibility and reentrancy protection before internal mutations.
use core::num::traits::Zero;
use game_components_interfaces::entry_fee::IEntryFee;
use game_components_utilities::distribution::structs::PackedDistributionStorePacking;
use metagame_extensions_interfaces::entry_fee_extension::{
    IENTRY_FEE_EXTENSION_ID, IEntryFeeExtensionDispatcher, IEntryFeeExtensionDispatcherTrait,
};
use metagame_extensions_interfaces::extension::ExtensionConfig;
use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::{ContractAddress, get_caller_address, get_contract_address};
use crate::entry_fee::entry_fee_store::{EntryFeeStoreImpl, EntryFeeStoreTrait};
use crate::entry_fee::store::Store;
use crate::entry_fee::structs::{
    AdditionalShare, EntryFee, EntryFeeClaimType, EntryFeeConfig, EntryFeeDeposit,
};


#[starknet::embeddable]
pub impl EntryFeeImpl<
    TContractState, +Store<TContractState>, +Drop<TContractState>,
> of IEntryFee<TContractState> {
    fn get_entry_fee(self: @TContractState, context_id: u64) -> Option<EntryFeeConfig> {
        EntryFeeStoreTrait::get_entry_fee(self, context_id)
    }
}

#[generate_trait]
pub impl EntryFeeInternalImpl<
    TContractState, +Store<TContractState>, +Drop<TContractState>,
> of EntryFeeInternalTrait<TContractState> {
    /// Get entry fee for a context (internal)
    /// Returns None if no entry fee is set (token address is zero)
    fn _get_entry_fee(self: @TContractState, context_id: u64) -> Option<EntryFeeConfig> {
        EntryFeeStoreTrait::get_entry_fee(self, context_id)
    }

    /// Get additional shares for a context
    /// Uses packed storage: reads 1 slot per 16 shares instead of 1 slot per share
    fn _get_additional_shares(self: @TContractState, context_id: u64) -> Span<AdditionalShare> {
        EntryFeeStoreTrait::get_additional_shares(self, context_id)
    }

    /// Persist a custom distribution shares array for a context.
    /// Packs 15 `u16` shares per `felt252` slot via `CustomShares`.
    /// Consumers pair this with their own paid-places count semantics.
    fn _store_distribution_shares(ref self: TContractState, context_id: u64, shares: Span<u16>) {
        EntryFeeStoreTrait::store_distribution_shares(ref self, context_id, shares);
    }

    /// Read `count` custom distribution shares for a context. Callers
    /// supply the count (typically sourced from the sibling
    /// `PackedDistribution.positions`); returns an empty array when
    /// `count == 0`.
    fn _get_distribution_shares(self: @TContractState, context_id: u64, count: u32) -> Array<u16> {
        EntryFeeStoreTrait::get_distribution_shares(self, context_id, count)
    }

    /// Read a single custom distribution share at a 1-indexed position.
    /// O(1) — only one packed `felt252` slot is read. Use this in claim
    /// paths instead of `_get_distribution_shares` when only one share
    /// is needed.
    fn _get_custom_share_at(self: @TContractState, context_id: u64, position: u32) -> u16 {
        EntryFeeStoreTrait::get_custom_share_at(self, context_id, position)
    }

    /// Set entry fee or extension for a context.
    /// Asserts that no entry fee has been previously set for this context.
    /// - EntryFee::Config: stores entry fee config, returns Some(EntryFeeConfig)
    /// - EntryFee::Extension: sets extension config, returns None
    fn set_entry_fee(
        ref self: TContractState, context_id: u64, entry_fee: EntryFee,
    ) -> Option<EntryFeeConfig> {
        // Assert entry fee has not already been set (either config or extension)
        assert!(
            !EntryFeeStoreTrait::is_entry_fee_set(@self, context_id),
            "EntryFee: Entry fee already set for context {}",
            context_id,
        );

        match entry_fee {
            EntryFee::Config(config) => {
                EntryFeeStoreTrait::set_entry_fee_config(ref self, context_id, @config);
                Option::Some(config)
            },
            EntryFee::Extension(ext) => {
                assert!(!ext.address.is_zero(), "EntryFee: Extension address cannot be zero");
                let src5 = ISRC5Dispatcher { contract_address: ext.address };
                let display_address: felt252 = ext.address.into();
                assert!(
                    src5.supports_interface(IENTRY_FEE_EXTENSION_ID),
                    "EntryFee: Extension {} does not support IEntryFeeExtension",
                    display_address,
                );
                self._set_extension(context_id, ext);
                Option::None
            },
        }
    }

    /// Internal: store entry fee config data
    fn _set_entry_fee_config(ref self: TContractState, context_id: u64, config: @EntryFeeConfig) {
        EntryFeeStoreTrait::set_entry_fee_config(ref self, context_id, config);
    }

    /// Internal: persist the extension address and forward the config
    /// to the extension contract. The config blob is NOT persisted here
    /// — the extension is the sole source of truth for its own config,
    /// and indexers wanting to recover it should read the original
    /// extension call (e.g. via the host's `TournamentCreated`-style
    /// event) or query the extension's own view methods.
    fn _set_extension(ref self: TContractState, context_id: u64, ext: ExtensionConfig) {
        EntryFeeStoreTrait::store_extension_address(ref self, context_id, ext.address);

        let dispatcher = IEntryFeeExtensionDispatcher { contract_address: ext.address };
        dispatcher.set_entry_fee_config(context_id, ext.config);
    }

    /// Process entry fee deposit.
    /// - EntryFeeDeposit::Config: transfers ERC20 tokens from caller to contract
    /// - EntryFeeDeposit::Extension: calls pay_entry_fee on the extension with
    ///   caller-provided params
    fn deposit_entry_fee(ref self: TContractState, context_id: u64, deposit: EntryFeeDeposit) {
        match deposit {
            EntryFeeDeposit::Config(config) => {
                let erc20_dispatcher = IERC20Dispatcher { contract_address: config.token_address };
                assert!(
                    erc20_dispatcher
                        .transfer_from(
                            get_caller_address(), get_contract_address(), config.amount.into(),
                        ),
                    "EntryFee: ERC20 transfer_from failed",
                );
            },
            EntryFeeDeposit::Extension(pay_params) => {
                let extension_address = EntryFeeStoreTrait::get_extension(@self, context_id);
                assert!(!extension_address.is_zero(), "EntryFee: No extension configured");
                let dispatcher = IEntryFeeExtensionDispatcher {
                    contract_address: extension_address,
                };
                dispatcher.pay_entry_fee(context_id, pay_params);
            },
        }
    }

    /// Forward a payout call to the entry-fee extension configured for
    /// `context_id`. Reverts if no extension was configured (the
    /// built-in deposit/payout path is host-owned and does not flow
    /// through this method).
    ///
    /// The host is a pure dispatcher: it passes the supplied
    /// `(token_id, claim_params)` straight through. The extension
    /// resolves recipient, eligibility, and dedupe entirely from its
    /// own state. `token_id = Some(id)` typically signals a claim
    /// (extension derives recipient via `owner_of(id)`); `None`
    /// signals a non-claim flow (sponsor refund, creator share,
    /// raffle) and the extension extracts whatever it needs from
    /// `claim_params`.
    ///
    /// Hosts are responsible for any cross-cutting concerns
    /// (finalization checks, reentrancy guards) before invoking this.
    fn payout_entry_fee_extension(
        ref self: TContractState,
        context_id: u64,
        token_id: Option<felt252>,
        claim_params: Span<felt252>,
    ) {
        let extension_address = EntryFeeStoreTrait::get_extension(@self, context_id);
        assert!(!extension_address.is_zero(), "EntryFee: No extension configured");
        let dispatcher = IEntryFeeExtensionDispatcher { contract_address: extension_address };
        dispatcher.payout_entry_fee(context_id, token_id, claim_params);
    }

    /// Read-through dispatcher for `IEntryFeeExtension.get_config`. Lets
    /// host viewers (frontends, indexer RPC fallbacks) surface the
    /// original config blob for extension-fee contexts without needing
    /// per-extension knowledge of the extension's internal storage.
    /// Returns an empty span when the context has no extension fee.
    fn get_entry_fee_extension_config(
        self: @TContractState, context_owner: ContractAddress, context_id: u64,
    ) -> Span<felt252> {
        let extension_address = EntryFeeStoreTrait::get_extension(self, context_id);
        if extension_address.is_zero() {
            return array![].span();
        }
        let dispatcher = IEntryFeeExtensionDispatcher { contract_address: extension_address };
        dispatcher.get_config(context_owner, context_id)
    }

    /// Payout to a recipient
    fn payout(
        ref self: TContractState,
        token_address: ContractAddress,
        recipient: ContractAddress,
        amount: u128,
    ) {
        if amount > 0 {
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            assert!(
                erc20_dispatcher.transfer(recipient, amount.into()),
                "EntryFee: ERC20 transfer failed",
            );
        }
    }

    /// Check if a claim has been made
    fn is_claimed(self: @TContractState, context_id: u64, claim_type: EntryFeeClaimType) -> bool {
        EntryFeeStoreTrait::is_claimed(self, context_id, claim_type)
    }

    /// Mark a claim as completed
    fn set_claimed(ref self: TContractState, context_id: u64, claim_type: EntryFeeClaimType) {
        EntryFeeStoreTrait::set_claimed(ref self, context_id, claim_type);
    }

    // --- Extension helpers ---

    /// Get extension address for a context (zero = no extension configured).
    fn get_extension_address(self: @TContractState, context_id: u64) -> ContractAddress {
        EntryFeeStoreTrait::get_extension(self, context_id)
    }
}
