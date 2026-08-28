// SPDX-License-Identifier: BUSL-1.1

/// Deployable token splitter: `SplitterComponent` with an immutable split set
/// at construction. Ownerless and permissionless — `distribute` is the only
/// way funds leave, so no admin surface is needed. No emergency withdrawal.
#[starknet::contract]
pub mod Splitter {
    use game_components_economy::tokenomics::splitter::splitter::SplitterComponent;
    use game_components_interfaces::tokenomics::splitter::SplitLeg;

    component!(path: SplitterComponent, storage: splitter, event: SplitterEvent);

    #[abi(embed_v0)]
    impl SplitterImpl = SplitterComponent::SplitterImpl<ContractState>;
    impl SplitterInternalImpl = SplitterComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        splitter: SplitterComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SplitterEvent: SplitterComponent::Event,
    }

    /// `legs` — the weighted split, summing to 10000 bps. Fixed hereafter.
    #[constructor]
    fn constructor(ref self: ContractState, legs: Span<SplitLeg>) {
        self.splitter.initializer(legs);
    }
}
