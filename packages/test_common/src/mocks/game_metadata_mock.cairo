/// Minimal contract embedding `GameMetadataComponent`.
#[starknet::contract]
pub mod GameMetadataMock {
    use game_components_embeddable_game_standard::minigame::game_metadata_component::GameMetadataComponent;
    use game_components_interfaces::structs::minigame::GameMetadata;

    component!(path: GameMetadataComponent, storage: game_metadata, event: GameMetadataEvent);

    #[abi(embed_v0)]
    impl GameMetadataImpl = GameMetadataComponent::GameMetadataImpl<ContractState>;
    impl GameMetadataInternalImpl = GameMetadataComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        game_metadata: GameMetadataComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        GameMetadataEvent: GameMetadataComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, game_metadata: GameMetadata) {
        self.game_metadata.initializer(game_metadata);
    }
}
