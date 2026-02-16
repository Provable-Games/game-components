#[starknet::contract]
pub mod PrizeExtensionMock {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::prize_extension::PrizeExtensionComponent;

    component!(path: PrizeExtensionComponent, storage: prize_extension, event: PrizeExtensionEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl PrizeExtensionImpl =
        PrizeExtensionComponent::PrizeExtensionImpl<ContractState>;

    impl PrizeExtensionInternalImpl = PrizeExtensionComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        prize_extension: PrizeExtensionComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PrizeExtensionEvent: PrizeExtensionComponent::Event,
        SRC5Event: SRC5Component::Event,
    }

    impl PrizeExtensionTraitImpl of PrizeExtensionComponent::PrizeExtension<ContractState> {
        fn add_prize(
            ref self: ContractState, context_id: u64, config: Span<felt252>,
        ) { // No-op for test mock
        }

        fn claim_prize(
            ref self: ContractState, context_id: u64, claim_params: Span<felt252>,
        ) { // No-op for test mock
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.prize_extension.initializer(owner);
    }
}
