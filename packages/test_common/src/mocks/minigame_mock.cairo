/// Minimal contract embedding `MinigameComponent`.
#[starknet::contract]
pub mod MinigameMock {
    use game_components_embeddable_game_standard::minigame::minigame_component::MinigameComponent;
    use game_components_interfaces::structs::minigame::GameMetadata;

    component!(path: MinigameComponent, storage: game_metadata, event: GameMetadataEvent);

    #[abi(embed_v0)]
    impl MinigameImpl = MinigameComponent::MinigameImpl<ContractState>;
    impl MinigameInternalImpl = MinigameComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        game_metadata: MinigameComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        GameMetadataEvent: MinigameComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, game_metadata: GameMetadata) {
        self.game_metadata.initializer(game_metadata);
    }
}
