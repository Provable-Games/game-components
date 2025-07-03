pub mod game_mock;
pub mod settings_mock;
pub mod objectives_mock;

// Re-export commonly used items
pub use game_mock::{MockMinigameContract, MockMinigameContractTrait, setup_mock_minigame};
pub use settings_mock::{MockSettingsContract, MockSettingsContractTrait, setup_mock_settings, create_default_settings};
pub use objectives_mock::{MockObjectivesContract, MockObjectivesContractTrait, setup_mock_objectives, create_default_objectives};