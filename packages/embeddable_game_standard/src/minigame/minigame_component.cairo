/// A game's own data — the identity an indexer or client needs to present it.
/// Recorded once at construction and served over `IMinigameGameMetadata`.
///
/// A game that keeps its identity elsewhere should implement the interface
/// itself; this is one convenient way to satisfy it.
#[starknet::component]
pub mod MinigameComponent {
    use game_components_interfaces::minigame::core::IMinigameGameMetadata;
    use game_components_interfaces::structs::minigame::GameMetadata;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        Minigame_game_metadata: GameMetadata,
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
            self.Minigame_game_metadata.write(game_metadata);
        }
    }

    #[embeddable_as(MinigameImpl)]
    pub impl Minigame<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IMinigameGameMetadata<ComponentState<TContractState>> {
        fn game_metadata(self: @ComponentState<TContractState>) -> GameMetadata {
            self.Minigame_game_metadata.read()
        }
    }
}
