/// Stores a game's identity and serves it over `IMinigameGameMetadata`.
///
/// `GameMetadata` was only ever a renderer input, so a consumer wanting a
/// game's name had to mint a token, render it, and parse traits back out of
/// the document — making game identity depend on that game's renderer. This
/// component is the boilerplate for answering directly instead.
///
/// Deliberately tiny. It holds one constant value and returns it; a game that
/// keeps its identity elsewhere should implement `IMinigameGameMetadata`
/// itself rather than adopt this. The INTERFACE is what consumers depend on —
/// this is only one convenient way to satisfy it.
#[starknet::component]
pub mod GameMetadataComponent {
    use game_components_interfaces::minigame::core::IMinigameGameMetadata;
    use game_components_interfaces::structs::minigame::GameMetadata;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        GameMetadata_value: GameMetadata,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Record the game's identity. Call once, from the constructor.
        fn initializer(ref self: ComponentState<TContractState>, game_metadata: GameMetadata) {
            self.GameMetadata_value.write(game_metadata);
        }
    }

    #[embeddable_as(GameMetadataImpl)]
    pub impl GameMetadataPublic<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IMinigameGameMetadata<ComponentState<TContractState>> {
        fn game_metadata(self: @ComponentState<TContractState>) -> GameMetadata {
            self.GameMetadata_value.read()
        }
    }
}
