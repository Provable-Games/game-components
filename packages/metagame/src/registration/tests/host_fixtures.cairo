use game_components_interfaces::registration::Registration;
use metagame_extensions_interfaces::extension::ExtensionConfig;
use starknet::ContractAddress;
use crate::entry_fee::structs::{
    AdditionalShare, EntryFee, EntryFeeClaimType, EntryFeeConfig, EntryFeeDeposit,
};

#[starknet::interface]
pub trait IHostRegistrationFee<T> {
    fn _get_entry(self: @T, context_id: u64, entry_id: u32) -> Registration;
    fn set_entry(ref self: T, registration: Registration);
    fn _get_entry_count(self: @T, context_id: u64) -> u32;
    fn increment_entry_count(ref self: T, context_id: u64) -> u32;
    fn mark_token_submitted(ref self: T, context_id: u64, token_id: felt252);
    fn ban_token(ref self: T, context_id: u64, token_id: felt252);
    fn _entry_exists(self: @T, context_id: u64, entry_id: u32) -> bool;
    fn assert_valid_for_submission(self: @T, registration: Registration, context_id: u64);
    fn _get_token_context(self: @T, context_id: u64, token_id: felt252) -> u64;
    fn _is_token_submitted(self: @T, context_id: u64, token_id: felt252) -> bool;
    fn _is_token_banned(self: @T, context_id: u64, token_id: felt252) -> bool;
    fn _get_entry_fee(self: @T, context_id: u64) -> Option<EntryFeeConfig>;
    fn _get_additional_shares(self: @T, context_id: u64) -> Span<AdditionalShare>;
    fn _store_distribution_shares(ref self: T, context_id: u64, shares: Span<u16>);
    fn _get_distribution_shares(self: @T, context_id: u64, count: u32) -> Array<u16>;
    fn _get_custom_share_at(self: @T, context_id: u64, position: u32) -> u16;
    fn set_entry_fee(ref self: T, context_id: u64, entry_fee: EntryFee) -> Option<EntryFeeConfig>;
    fn _set_entry_fee_config(ref self: T, context_id: u64, config: EntryFeeConfig);
    fn _set_extension(ref self: T, context_id: u64, ext: ExtensionConfig);
    fn deposit_entry_fee(ref self: T, context_id: u64, deposit: EntryFeeDeposit);
    fn payout_entry_fee_extension(
        ref self: T, context_id: u64, token_id: Option<felt252>, claim_params: Span<felt252>,
    );
    fn get_entry_fee_extension_config(
        self: @T, context_owner: ContractAddress, context_id: u64,
    ) -> Span<felt252>;
    fn payout(
        ref self: T, token_address: ContractAddress, recipient: ContractAddress, amount: u128,
    );
    fn is_claimed(self: @T, context_id: u64, claim_type: EntryFeeClaimType) -> bool;
    fn set_claimed(ref self: T, context_id: u64, claim_type: EntryFeeClaimType);
    fn get_extension_address(self: @T, context_id: u64) -> ContractAddress;
}

#[starknet::embeddable]
pub impl HostRegistrationFeeApi<
    TContractState,
    +crate::registration::store::Store<TContractState>,
    +crate::entry_fee::store::Store<TContractState>,
    +Drop<TContractState>,
> of IHostRegistrationFee<TContractState> {
    fn _get_entry(self: @TContractState, context_id: u64, entry_id: u32) -> Registration {
        crate::registration::api::RegistrationInternalImpl::_get_entry(self, context_id, entry_id)
    }
    fn set_entry(ref self: TContractState, registration: Registration) {
        crate::registration::api::RegistrationInternalImpl::set_entry(ref self, @registration)
    }
    fn _get_entry_count(self: @TContractState, context_id: u64) -> u32 {
        crate::registration::api::RegistrationInternalImpl::_get_entry_count(self, context_id)
    }
    fn increment_entry_count(ref self: TContractState, context_id: u64) -> u32 {
        crate::registration::api::RegistrationInternalImpl::increment_entry_count(
            ref self, context_id,
        )
    }
    fn mark_token_submitted(ref self: TContractState, context_id: u64, token_id: felt252) {
        crate::registration::api::RegistrationInternalImpl::mark_token_submitted(
            ref self, context_id, token_id,
        )
    }
    fn ban_token(ref self: TContractState, context_id: u64, token_id: felt252) {
        crate::registration::api::RegistrationInternalImpl::ban_token(
            ref self, context_id, token_id,
        )
    }
    fn _entry_exists(self: @TContractState, context_id: u64, entry_id: u32) -> bool {
        crate::registration::api::RegistrationInternalImpl::_entry_exists(
            self, context_id, entry_id,
        )
    }
    fn assert_valid_for_submission(
        self: @TContractState, registration: Registration, context_id: u64,
    ) {
        crate::registration::api::RegistrationInternalImpl::assert_valid_for_submission(
            self, @registration, context_id,
        )
    }
    fn _get_token_context(self: @TContractState, context_id: u64, token_id: felt252) -> u64 {
        crate::registration::api::RegistrationInternalImpl::_get_token_context(
            self, context_id, token_id,
        )
    }
    fn _is_token_submitted(self: @TContractState, context_id: u64, token_id: felt252) -> bool {
        crate::registration::api::RegistrationInternalImpl::_is_token_submitted(
            self, context_id, token_id,
        )
    }
    fn _is_token_banned(self: @TContractState, context_id: u64, token_id: felt252) -> bool {
        crate::registration::api::RegistrationInternalImpl::_is_token_banned(
            self, context_id, token_id,
        )
    }
    fn _get_entry_fee(self: @TContractState, context_id: u64) -> Option<EntryFeeConfig> {
        crate::entry_fee::api::EntryFeeInternalImpl::_get_entry_fee(self, context_id)
    }
    fn _get_additional_shares(self: @TContractState, context_id: u64) -> Span<AdditionalShare> {
        crate::entry_fee::api::EntryFeeInternalImpl::_get_additional_shares(self, context_id)
    }
    fn _store_distribution_shares(ref self: TContractState, context_id: u64, shares: Span<u16>) {
        crate::entry_fee::api::EntryFeeInternalImpl::_store_distribution_shares(
            ref self, context_id, shares,
        )
    }
    fn _get_distribution_shares(self: @TContractState, context_id: u64, count: u32) -> Array<u16> {
        crate::entry_fee::api::EntryFeeInternalImpl::_get_distribution_shares(
            self, context_id, count,
        )
    }
    fn _get_custom_share_at(self: @TContractState, context_id: u64, position: u32) -> u16 {
        crate::entry_fee::api::EntryFeeInternalImpl::_get_custom_share_at(
            self, context_id, position,
        )
    }
    fn set_entry_fee(
        ref self: TContractState, context_id: u64, entry_fee: EntryFee,
    ) -> Option<EntryFeeConfig> {
        crate::entry_fee::api::EntryFeeInternalImpl::set_entry_fee(ref self, context_id, entry_fee)
    }
    fn _set_entry_fee_config(ref self: TContractState, context_id: u64, config: EntryFeeConfig) {
        crate::entry_fee::api::EntryFeeInternalImpl::_set_entry_fee_config(
            ref self, context_id, @config,
        )
    }
    fn _set_extension(ref self: TContractState, context_id: u64, ext: ExtensionConfig) {
        crate::entry_fee::api::EntryFeeInternalImpl::_set_extension(ref self, context_id, ext)
    }
    fn deposit_entry_fee(ref self: TContractState, context_id: u64, deposit: EntryFeeDeposit) {
        crate::entry_fee::api::EntryFeeInternalImpl::deposit_entry_fee(
            ref self, context_id, deposit,
        )
    }
    fn payout_entry_fee_extension(
        ref self: TContractState,
        context_id: u64,
        token_id: Option<felt252>,
        claim_params: Span<felt252>,
    ) {
        crate::entry_fee::api::EntryFeeInternalImpl::payout_entry_fee_extension(
            ref self, context_id, token_id, claim_params,
        )
    }
    fn get_entry_fee_extension_config(
        self: @TContractState, context_owner: ContractAddress, context_id: u64,
    ) -> Span<felt252> {
        crate::entry_fee::api::EntryFeeInternalImpl::get_entry_fee_extension_config(
            self, context_owner, context_id,
        )
    }
    fn payout(
        ref self: TContractState,
        token_address: ContractAddress,
        recipient: ContractAddress,
        amount: u128,
    ) {
        crate::entry_fee::api::EntryFeeInternalImpl::payout(
            ref self, token_address, recipient, amount,
        )
    }
    fn is_claimed(self: @TContractState, context_id: u64, claim_type: EntryFeeClaimType) -> bool {
        crate::entry_fee::api::EntryFeeInternalImpl::is_claimed(self, context_id, claim_type)
    }
    fn set_claimed(ref self: TContractState, context_id: u64, claim_type: EntryFeeClaimType) {
        crate::entry_fee::api::EntryFeeInternalImpl::set_claimed(ref self, context_id, claim_type)
    }
    fn get_extension_address(self: @TContractState, context_id: u64) -> ContractAddress {
        crate::entry_fee::api::EntryFeeInternalImpl::get_extension_address(self, context_id)
    }
}

#[starknet::contract]
pub mod HostRegistrationFee {
    use game_components_utilities::distribution::packed_shares::CustomShares;
    use game_components_utilities::distribution::structs::PackedDistribution;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::entry_fee::store::Store as FeeStore;
    use crate::entry_fee::structs::PackedAdditionalShares;
    use crate::registration::store::Store as RegistrationStore;
    #[storage]
    struct Storage {
        Registration_token_ids: Map<(u64, u32), felt252>,
        Registration_entry_counts: Map<u64, u32>,
        EntryFee_token: Map<u64, ContractAddress>,
        EntryFee_data: Map<u64, felt252>,
        EntryFee_additional_recipient: Map<(u64, u8), ContractAddress>,
        EntryFee_additional_shares_packed: Map<(u64, u8), PackedAdditionalShares>,
        EntryFee_distribution_shares_packed: Map<(u64, u8), CustomShares>,
        EntryFee_distribution: Map<u64, PackedDistribution>,
        EntryFee_position_claimed: Map<(u64, u32), bool>,
        EntryFee_extension_address: Map<u64, ContractAddress>,
        entry_state: Map<(u64, felt252), u128>,
    }
    pub impl RegistrationHostStore of RegistrationStore<ContractState> {
        fn get_token_id(self: @ContractState, context_id: u64, entry_id: u32) -> felt252 {
            self.Registration_token_ids.entry((context_id, entry_id)).read()
        }

        fn set_token_id(
            ref self: ContractState, context_id: u64, entry_id: u32, token_id: felt252,
        ) {
            self.Registration_token_ids.entry((context_id, entry_id)).write(token_id);
        }

        fn get_entry_count(self: @ContractState, context_id: u64) -> u32 {
            self.Registration_entry_counts.entry(context_id).read()
        }

        fn set_entry_count(ref self: ContractState, context_id: u64, count: u32) {
            self.Registration_entry_counts.entry(context_id).write(count);
        }

        fn get_token_state_raw(
            self: @ContractState, context_id: u64, token_id: felt252,
        ) -> felt252 {
            (self.entry_state.entry((context_id, token_id)).read() & 0x3ffffffffffffffff).into()
        }

        fn set_token_state_raw(
            ref self: ContractState, context_id: u64, token_id: felt252, state: felt252,
        ) {
            let old = self.entry_state.entry((context_id, token_id)).read();
            let raw: u128 = state.try_into().unwrap();
            assert!(raw <= 0x3ffffffffffffffff, "invalid registration bits");
            self.entry_state.entry((context_id, token_id)).write((old & 0x40000000000000000) | raw);
        }
    }
    pub impl EntryFeeHostStore of FeeStore<ContractState> {
        fn get_token(self: @ContractState, context_id: u64) -> ContractAddress {
            self.EntryFee_token.entry(context_id).read()
        }

        fn set_token(ref self: ContractState, context_id: u64, token: ContractAddress) {
            self.EntryFee_token.entry(context_id).write(token);
        }

        fn get_data_raw(self: @ContractState, context_id: u64) -> felt252 {
            self.EntryFee_data.entry(context_id).read()
        }

        fn set_data_raw(ref self: ContractState, context_id: u64, data: felt252) {
            self.EntryFee_data.entry(context_id).write(data);
        }

        fn get_additional_recipient(
            self: @ContractState, context_id: u64, index: u8,
        ) -> ContractAddress {
            self.EntryFee_additional_recipient.entry((context_id, index)).read()
        }

        fn set_additional_recipient(
            ref self: ContractState, context_id: u64, index: u8, recipient: ContractAddress,
        ) {
            self.EntryFee_additional_recipient.entry((context_id, index)).write(recipient);
        }

        fn get_packed_shares(
            self: @ContractState, context_id: u64, slot: u8,
        ) -> PackedAdditionalShares {
            self.EntryFee_additional_shares_packed.entry((context_id, slot)).read()
        }

        fn set_packed_shares(
            ref self: ContractState, context_id: u64, slot: u8, shares: PackedAdditionalShares,
        ) {
            self.EntryFee_additional_shares_packed.entry((context_id, slot)).write(shares);
        }

        fn get_refund_claimed(self: @ContractState, context_id: u64, token_id: felt252) -> bool {
            (self.entry_state.entry((context_id, token_id)).read() & 0x40000000000000000) != 0
        }

        fn set_refund_claimed(
            ref self: ContractState, context_id: u64, token_id: felt252, claimed: bool,
        ) {
            let old = self.entry_state.entry((context_id, token_id)).read();
            let flag = if claimed {
                0x40000000000000000
            } else {
                0
            };
            self
                .entry_state
                .entry((context_id, token_id))
                .write((old & 0x3ffffffffffffffff) | flag);
        }

        fn get_position_claimed(self: @ContractState, context_id: u64, position: u32) -> bool {
            self.EntryFee_position_claimed.entry((context_id, position)).read()
        }

        fn set_position_claimed(
            ref self: ContractState, context_id: u64, position: u32, claimed: bool,
        ) {
            self.EntryFee_position_claimed.entry((context_id, position)).write(claimed);
        }

        fn get_extension_address(self: @ContractState, context_id: u64) -> ContractAddress {
            self.EntryFee_extension_address.entry(context_id).read()
        }

        fn set_extension_address(
            ref self: ContractState, context_id: u64, address: ContractAddress,
        ) {
            self.EntryFee_extension_address.entry(context_id).write(address);
        }

        fn get_distribution_shares_packed(
            self: @ContractState, context_id: u64, slot: u8,
        ) -> CustomShares {
            self.EntryFee_distribution_shares_packed.entry((context_id, slot)).read()
        }

        fn set_distribution_shares_packed(
            ref self: ContractState, context_id: u64, slot: u8, shares: CustomShares,
        ) {
            self.EntryFee_distribution_shares_packed.entry((context_id, slot)).write(shares);
        }

        fn get_distribution(self: @ContractState, context_id: u64) -> PackedDistribution {
            self.EntryFee_distribution.entry(context_id).read()
        }

        fn set_distribution(
            ref self: ContractState, context_id: u64, distribution: PackedDistribution,
        ) {
            self.EntryFee_distribution.entry(context_id).write(distribution);
        }
    }
    #[abi(embed_v0)]
    impl RegistrationViews =
        crate::registration::api::RegistrationImpl<ContractState>;
    #[abi(embed_v0)]
    impl FeeViews = crate::entry_fee::api::EntryFeeImpl<ContractState>;
    #[abi(embed_v0)]
    impl TestApi = super::HostRegistrationFeeApi<ContractState>;
}

#[starknet::contract]
pub mod AdapterRegistrationFee {
    use crate::entry_fee::entry_fee_component::EntryFeeComponent;
    use crate::registration::registration_component::RegistrationComponent;
    component!(path: RegistrationComponent, storage: registration, event: RegistrationEvent);
    component!(path: EntryFeeComponent, storage: fee, event: FeeEvent);
    #[storage]
    struct Storage {
        #[substorage(v0)]
        registration: RegistrationComponent::Storage,
        #[substorage(v0)]
        fee: EntryFeeComponent::Storage,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RegistrationEvent: RegistrationComponent::Event,
        FeeEvent: EntryFeeComponent::Event,
    }
    impl RegistrationStorage = crate::registration::storage_adapter::ComponentStore<ContractState>;
    impl FeeStorage = crate::entry_fee::storage_adapter::ComponentStore<ContractState>;
    #[abi(embed_v0)]
    impl RegistrationViews =
        crate::registration::api::RegistrationImpl<ContractState>;
    #[abi(embed_v0)]
    impl FeeViews = crate::entry_fee::api::EntryFeeImpl<ContractState>;
    #[abi(embed_v0)]
    impl TestApi = super::HostRegistrationFeeApi<ContractState>;
}
