#[starknet::contract]
pub mod EntryFeeExtensionMock {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::entry_fee_extension::EntryFeeExtensionComponent;

    component!(
        path: EntryFeeExtensionComponent,
        storage: entry_fee_extension,
        event: EntryFeeExtensionEvent,
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl EntryFeeExtensionImpl =
        EntryFeeExtensionComponent::EntryFeeExtensionImpl<ContractState>;

    impl EntryFeeExtensionInternalImpl = EntryFeeExtensionComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        entry_fee_extension: EntryFeeExtensionComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EntryFeeExtensionEvent: EntryFeeExtensionComponent::Event,
        SRC5Event: SRC5Component::Event,
    }

    impl EntryFeeExtensionTraitImpl of EntryFeeExtensionComponent::EntryFeeExtension<
        ContractState,
    > {
        fn calculate_fee(
            self: @ContractState,
            context_id: u64,
            base_amount: u128,
            player: ContractAddress,
            config: Span<felt252>,
        ) -> u128 {
            // Simple: return base amount unchanged
            base_amount
        }

        fn validate_deposit(
            self: @ContractState,
            context_id: u64,
            player: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        ) -> bool {
            // Simple: always valid
            true
        }

        fn on_deposit(
            ref self: ContractState,
            context_id: u64,
            token_address: ContractAddress,
            amount: u128,
            player: ContractAddress,
            config: Span<felt252>,
        ) { // No-op for test mock
        }

        fn on_claim(
            ref self: ContractState,
            context_id: u64,
            claim_type: Span<felt252>,
            claimer: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        ) { // No-op for test mock
        }

        fn on_refund(
            ref self: ContractState,
            context_id: u64,
            recipient: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        ) { // No-op for test mock
        }

        fn add_config(
            ref self: ContractState, context_id: u64, config: Span<felt252>,
        ) { // No-op for test mock
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.entry_fee_extension.initializer(owner);
    }
}
