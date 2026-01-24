/// Mock registry contract with a hook that rejects registration
/// This contract tests that hooks can prevent game registration
#[starknet::contract]
pub mod MockRegistryWithRejectingHook {
    use game_components_registry::component::MinigameRegistryComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: MinigameRegistryComponent, storage: registry, event: RegistryEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Embed the registry implementation
    #[abi(embed_v0)]
    impl RegistryImpl =
        MinigameRegistryComponent::MinigameRegistryImpl<ContractState>;
    impl RegistryInternalImpl = MinigameRegistryComponent::InternalImpl<ContractState>;

    // SRC5 implementation
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        registry: MinigameRegistryComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        RegistryEvent: MinigameRegistryComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    // Custom hooks implementation that rejects all registrations
    impl RegistryHooksImpl of MinigameRegistryComponent::MinigameRegistryHooksTrait<ContractState> {
        fn before_register_game(
            ref self: ContractState,
            caller_address: ContractAddress,
            creator_address: ContractAddress,
        ) {
            panic!("Registration rejected");
        }

        fn after_register_game(
            ref self: ContractState, game_id: u64, creator_address: ContractAddress,
        ) { // Never reached because before_register_game panics
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.registry.initializer();
    }
}
