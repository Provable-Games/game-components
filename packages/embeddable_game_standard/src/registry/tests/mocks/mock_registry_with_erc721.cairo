/// Mock registry contract with ERC721 for testing set_game_royalty
/// This contract embeds the registry component with ERC721 for owner_of support
#[starknet::contract]
pub mod MockRegistryWithERC721 {
    use game_components_embeddable_game_standard::registry::registry_component::MinigameRegistryComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: MinigameRegistryComponent, storage: registry, event: RegistryEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Embed the registry implementation
    #[abi(embed_v0)]
    impl RegistryImpl =
        MinigameRegistryComponent::MinigameRegistryImpl<ContractState>;
    impl RegistryInternalImpl = MinigameRegistryComponent::InternalImpl<ContractState>;

    // ERC721 Mixin includes SRC5 - don't embed SRC5Impl separately to avoid duplicate
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // Internal SRC5 for interface registration only (not embedded in ABI)
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        registry: MinigameRegistryComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        RegistryEvent: MinigameRegistryComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
    }

    // Custom hooks implementation that mints ERC721 tokens
    impl RegistryHooksImpl of MinigameRegistryComponent::MinigameRegistryHooksTrait<ContractState> {
        fn before_register_game(
            ref self: ContractState,
            caller_address: ContractAddress,
            creator_address: ContractAddress,
        ) { // No-op for validation
        }

        fn after_register_game(
            ref self: ContractState, game_id: u64, creator_address: ContractAddress,
        ) {
            // Mint creator token to the creator
            self.erc721.mint(creator_address, game_id.into());
        }

        fn assert_registry_owner(self: @ContractState) {// No-op for testing - any caller can set defaults
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialize ERC721
        self.erc721.initializer("Game Creator", "GCREATOR", "");
        // Initialize registry (registers SRC5 interface + sets default game fee)
        self.registry.initializer();
    }
}
