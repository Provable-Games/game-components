// SPDX-License-Identifier: BUSL-1.1

/// Deployable deposit lock: `DepositLockComponent` (permissionless
/// lock/release/views) + `OwnableComponent` (gates `set_beneficiary`).
/// Constructor: `owner` (redirects the beneficiary; hand to a timelock),
/// `token` and `lock_duration` (both fixed), `beneficiary`. No emergency exit.
#[starknet::contract]
pub mod DepositLock {
    use game_components_economy::tokenomics::deposit_lock::deposit_lock::DepositLockComponent;
    use game_components_interfaces::tokenomics::deposit_lock::IDepositLockAdmin;
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    component!(path: DepositLockComponent, storage: deposit_lock, event: DepositLockEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl DepositLockImpl = DepositLockComponent::DepositLockImpl<ContractState>;
    impl DepositLockInternalImpl = DepositLockComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        deposit_lock: DepositLockComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        DepositLockEvent: DepositLockComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        token: ContractAddress,
        beneficiary: ContractAddress,
        lock_duration: u64,
    ) {
        self.ownable.initializer(owner);
        self.deposit_lock.initializer(token, beneficiary, lock_duration);
    }

    #[abi(embed_v0)]
    impl DepositLockAdminImpl of IDepositLockAdmin<ContractState> {
        fn set_beneficiary(ref self: ContractState, beneficiary: ContractAddress) {
            self.ownable.assert_only_owner();
            self.deposit_lock.set_beneficiary(beneficiary);
        }
    }
}
