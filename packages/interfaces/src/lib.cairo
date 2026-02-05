// Game Components Interfaces
// Standalone interface definitions for game component contracts

// Struct definitions
pub mod structs;
pub use structs::{
    leaderboard as leaderboard_structs, metagame as metagame_structs, minigame as minigame_structs,
    registry as registry_structs, token as token_structs,
};
pub mod leaderboard;

// Interface modules
pub mod metagame;
pub mod minigame;
pub mod registry;
pub mod token;
pub mod tokenomics;

// Leaderboard
pub use leaderboard::{
    IGameDetails, IGameDetailsDispatcher, IGameDetailsDispatcherTrait, ILEADERBOARD_ID,
    ILeaderboard, ILeaderboardAdmin, ILeaderboardAdminDispatcher, ILeaderboardAdminDispatcherTrait,
    ILeaderboardDispatcher, ILeaderboardDispatcherTrait,
};

// Re-export commonly used items at top level for convenience
// Metagame
pub use metagame::{
    IMETAGAME_CALLBACK_ID, IMETAGAME_CONTEXT_ID, IMETAGAME_ID, IMetagame, IMetagameCallback,
    IMetagameCallbackDispatcher, IMetagameCallbackDispatcherTrait, IMetagameContext,
    IMetagameContextDetails, IMetagameContextDetailsDispatcher,
    IMetagameContextDetailsDispatcherTrait, IMetagameContextDispatcher,
    IMetagameContextDispatcherTrait, IMetagameContextSVG, IMetagameContextSVGDispatcher,
    IMetagameContextSVGDispatcherTrait, IMetagameDispatcher, IMetagameDispatcherTrait,
};

// Minigame
pub use minigame::{
    IMINIGAME_ID, IMINIGAME_OBJECTIVES_ID, IMINIGAME_SETTINGS_ID, IMinigame, IMinigameDetails,
    IMinigameDetailsDispatcher, IMinigameDetailsDispatcherTrait, IMinigameDetailsSVG,
    IMinigameDetailsSVGDispatcher, IMinigameDetailsSVGDispatcherTrait, IMinigameDispatcher,
    IMinigameDispatcherTrait, IMinigameObjectives, IMinigameObjectivesDetails,
    IMinigameObjectivesDetailsDispatcher, IMinigameObjectivesDetailsDispatcherTrait,
    IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait, IMinigameObjectivesSVG,
    IMinigameObjectivesSVGDispatcher, IMinigameObjectivesSVGDispatcherTrait, IMinigameSettings,
    IMinigameSettingsDetails, IMinigameSettingsDetailsDispatcher,
    IMinigameSettingsDetailsDispatcherTrait, IMinigameSettingsDispatcher,
    IMinigameSettingsDispatcherTrait, IMinigameSettingsSVG, IMinigameSettingsSVGDispatcher,
    IMinigameSettingsSVGDispatcherTrait, IMinigameTokenData, IMinigameTokenDataDispatcher,
    IMinigameTokenDataDispatcherTrait, IMinigameTokenUri, IMinigameTokenUriDispatcher,
    IMinigameTokenUriDispatcherTrait,
};

// Registry
pub use registry::{
    IMINIGAME_REGISTRY_ID, IMinigameRegistry, IMinigameRegistryDispatcher,
    IMinigameRegistryDispatcherTrait,
};

// Structs
pub use structs::{
    GameContext, GameContextDetails, GameDetail, GameMetadata, GameObjective, GameObjectiveDetails,
    GameSetting, GameSettingDetails, LeaderboardConfig, LeaderboardEntry, LeaderboardResult,
    LeaderboardStoreConfig, Lifecycle, MintGameParams, MintParams, PlayerNameUpdate, TokenMetadata,
};

// Token
pub use token::{
    IMINIGAME_TOKEN_CONTEXT_ID, IMINIGAME_TOKEN_ID, IMINIGAME_TOKEN_MINTER_ID,
    IMINIGAME_TOKEN_OBJECTIVES_ID, IMINIGAME_TOKEN_RENDERER_ID, IMINIGAME_TOKEN_SETTINGS_ID,
    IMinigameToken, IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait, IMinigameTokenMinter,
    IMinigameTokenMinterDispatcher, IMinigameTokenMinterDispatcherTrait, IMinigameTokenObjectives,
    IMinigameTokenObjectivesDispatcher, IMinigameTokenObjectivesDispatcherTrait,
    IMinigameTokenRenderer, IMinigameTokenRendererDispatcher, IMinigameTokenRendererDispatcherTrait,
    IMinigameTokenSettings, IMinigameTokenSettingsDispatcher, IMinigameTokenSettingsDispatcherTrait,
};

// Tokenomics (existing)
pub use tokenomics::{buyback, stream};
