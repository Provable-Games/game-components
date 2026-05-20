/// Mock contract that embeds the EntryFeeComponent for testing storage gas
#[starknet::contract]
pub mod EntryFeeMock {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::entry_fee::entry_fee_component::EntryFeeComponent;
    use crate::entry_fee::structs::{AdditionalShare, EntryFee, EntryFeeClaimType};

    component!(path: EntryFeeComponent, storage: entry_fee, event: EntryFeeEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl EntryFeeImpl = EntryFeeComponent::EntryFeeImpl<ContractState>;

    impl EntryFeeInternalImpl = EntryFeeComponent::EntryFeeInternalImpl<ContractState>;

    impl EntryFeeInitializerImpl = EntryFeeComponent::EntryFeeInitializerImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        entry_fee: EntryFeeComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EntryFeeEvent: EntryFeeComponent::Event,
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.entry_fee.initializer();
    }

    #[external(v0)]
    fn set_entry_fee(ref self: ContractState, context_id: u64, entry_fee: EntryFee) {
        let _ = self.entry_fee.set_entry_fee(context_id, entry_fee);
    }

    #[external(v0)]
    fn get_additional_shares(self: @ContractState, context_id: u64) -> Span<AdditionalShare> {
        self.entry_fee._get_additional_shares(context_id)
    }

    #[external(v0)]
    fn is_claimed(self: @ContractState, context_id: u64, claim_type: EntryFeeClaimType) -> bool {
        self.entry_fee.is_claimed(context_id, claim_type)
    }

    #[external(v0)]
    fn set_claimed(ref self: ContractState, context_id: u64, claim_type: EntryFeeClaimType) {
        self.entry_fee.set_claimed(context_id, claim_type);
    }

    #[external(v0)]
    fn get_extension_address(self: @ContractState, context_id: u64) -> ContractAddress {
        self.entry_fee.get_extension_address(context_id)
    }

    #[external(v0)]
    fn store_distribution_shares(ref self: ContractState, context_id: u64, shares: Span<u16>) {
        self.entry_fee._store_distribution_shares(context_id, shares);
    }

    #[external(v0)]
    fn get_distribution_shares(self: @ContractState, context_id: u64, count: u32) -> Array<u16> {
        self.entry_fee._get_distribution_shares(context_id, count)
    }

    #[external(v0)]
    fn payout_entry_fee_extension(
        ref self: ContractState,
        context_id: u64,
        token_id: Option<felt252>,
        claim_params: Span<felt252>,
    ) {
        self.entry_fee.payout_entry_fee_extension(context_id, token_id, claim_params);
    }
}
