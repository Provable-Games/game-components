/// Mock registry contract with custom hooks for tracking hook invocations
/// This contract allows testing that hooks are called correctly
#[starknet::interface]
pub trait IMockRegistryHookTracker<TContractState> {
    fn was_before_hook_called(self: @TContractState) -> bool;
    fn was_after_hook_called(self: @TContractState) -> bool;
    fn get_hook_game_id(self: @TContractState) -> u64;
    fn get_hook_creator(self: @TContractState) -> starknet::ContractAddress;
    fn get_before_hook_caller(self: @TContractState) -> starknet::ContractAddress;
}

#[starknet::contract]
pub mod MockRegistryWithCustomHooks {
    use game_components_embeddable_game_standard::registry::interface::DEFAULT_GAME_FEE_BPS;
    use game_components_embeddable_game_standard::registry::registry_component::MinigameRegistryComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

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
        // Hook tracking storage
        before_hook_called: bool,
        after_hook_called: bool,
        hook_game_id: u64,
        hook_creator: ContractAddress,
        before_hook_caller: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        RegistryEvent: MinigameRegistryComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    // Custom hooks implementation that tracks invocations
    impl RegistryHooksImpl of MinigameRegistryComponent::MinigameRegistryHooksTrait<ContractState> {
        fn before_register_game(
            ref self: ContractState,
            caller_address: ContractAddress,
            creator_address: ContractAddress,
        ) {
            self.before_hook_called.write(true);
            self.before_hook_caller.write(caller_address);
        }

        fn after_register_game(
            ref self: ContractState, game_id: u64, creator_address: ContractAddress,
        ) {
            self.after_hook_called.write(true);
            self.hook_game_id.write(game_id);
            self.hook_creator.write(creator_address);
        }

        fn assert_registry_owner(self: @ContractState) { // No-op for testing
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.registry.initializer(DEFAULT_GAME_FEE_BPS);
    }

    #[abi(embed_v0)]
    impl MockRegistryHookTrackerImpl of super::IMockRegistryHookTracker<ContractState> {
        fn was_before_hook_called(self: @ContractState) -> bool {
            self.before_hook_called.read()
        }

        fn was_after_hook_called(self: @ContractState) -> bool {
            self.after_hook_called.read()
        }

        fn get_hook_game_id(self: @ContractState) -> u64 {
            self.hook_game_id.read()
        }

        fn get_hook_creator(self: @ContractState) -> ContractAddress {
            self.hook_creator.read()
        }

        fn get_before_hook_caller(self: @ContractState) -> ContractAddress {
            self.before_hook_caller.read()
        }
    }
}
