/// # MinigameComponent
///
/// A game's own data: the identity an indexer or client needs to present it —
/// name, description, developer, publisher, genre, image, color, client url,
/// royalty. Recorded once at construction and served over
/// `IMinigameGameMetadata`.
///
/// This is all a "minigame" is now. The game IS its token — minting, playability
/// and ownership all live in `MinigameTokenComponent` on the same contract — so
/// what remains distinctly game-level is this description of the game itself,
/// plus the state the game answers for its tokens (`IMinigameTokenData`) and
/// the optional settings/objectives extensions.
///
/// Deliberately NOT derived from a rendered token URI: reading a game's name
/// should not require minting a token, rendering it, and parsing traits back
/// out of the document, which would make identity depend on a renderer.
/// Per-contract and constant, so a consumer reads it once rather than once per
/// token.
///
/// Deliberately tiny: it holds one value and returns it. A game that keeps its
/// identity elsewhere should implement `IMinigameGameMetadata` itself — the
/// INTERFACE is what consumers depend on; this is one convenient way to satisfy
/// it.
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
