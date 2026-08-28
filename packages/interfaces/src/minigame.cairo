// Minigame interfaces module

pub mod core;
pub mod objectives;
pub mod settings;

// Re-export commonly used items at top level
pub use core::{
    IMinigameDetails, IMinigameDetailsDispatcher, IMinigameDetailsDispatcherTrait,
    IMinigameDetailsSVG, IMinigameDetailsSVGDispatcher, IMinigameDetailsSVGDispatcherTrait,
    IMinigameTokenData, IMinigameTokenDataDispatcher, IMinigameTokenDataDispatcherTrait,
    IMinigameTokenUri, IMinigameTokenUriDispatcher, IMinigameTokenUriDispatcherTrait,
};
pub use objectives::{
    IMINIGAME_OBJECTIVES_ID, IMinigameObjectives, IMinigameObjectivesDetails,
    IMinigameObjectivesDetailsDispatcher, IMinigameObjectivesDetailsDispatcherTrait,
    IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait, IMinigameObjectivesSVG,
    IMinigameObjectivesSVGDispatcher, IMinigameObjectivesSVGDispatcherTrait,
};
pub use settings::{
    IMINIGAME_SETTINGS_ID, IMinigameSettings, IMinigameSettingsDetails,
    IMinigameSettingsDetailsDispatcher, IMinigameSettingsDetailsDispatcherTrait,
    IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait, IMinigameSettingsSVG,
    IMinigameSettingsSVGDispatcher, IMinigameSettingsSVGDispatcherTrait,
};
