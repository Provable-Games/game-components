/// Interface for initializing the mock registry contract
#[starknet::interface]
pub trait IMockRegistryInit<TContractState> {
    fn get_game_count(self: @TContractState) -> u64;
}

/// Mock registry contract for testing MinigameRegistryComponent
/// This contract embeds the registry component and provides test access
#[starknet::contract]
pub mod MockRegistryContract {
    use game_components_registry::interface::IMinigameRegistry;
    use game_components_registry::registry::{
        MinigameRegistryComponent, MinigameRegistryHooksEmptyImpl,
    };
    use openzeppelin_introspection::src5::SRC5Component;

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

    // Use empty hooks implementation
    impl RegistryHooksImpl = MinigameRegistryHooksEmptyImpl<ContractState>;

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.registry.initializer();
    }

    #[abi(embed_v0)]
    impl MockRegistryInitImpl of super::IMockRegistryInit<ContractState> {
        fn get_game_count(self: @ContractState) -> u64 {
            self.registry.game_count()
        }
    }
}
