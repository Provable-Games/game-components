// Game Components Interfaces
// Standalone interface definitions for game component contracts

// Struct definitions
pub mod structs;
pub use structs::{
    leaderboard as leaderboard_structs, metagame as metagame_structs, minigame as minigame_structs,
    registry as registry_structs, token as token_structs,
};

// Budokan-extracted interfaces
pub mod distribution;
pub mod entry_fee;
pub mod entry_requirement;
pub mod gpp;
pub mod leaderboard;

// Interface modules
pub mod metagame;
pub mod minigame;
pub mod prize;
pub mod registration;
pub mod registry;
pub mod token;
pub mod tokenomics;

// Distribution
pub use distribution::Distribution;

// Entry Fee
pub use entry_fee::{
    AdditionalShare, EntryFee, EntryFeeConfig, IEntryFee, IEntryFeeDispatcher,
    IEntryFeeDispatcherTrait,
};

// Entry Requirement
pub use entry_requirement::{
    EntryRequirement, EntryRequirementType, IEntryRequirement, IEntryRequirementDispatcher,
    IEntryRequirementDispatcherTrait, NFTQualification, QualificationEntries, QualificationProof,
};

// GPP
pub use gpp::{
    GppConfig, GppERC20Prize, GppERC721Prize, GppPoolState, GppPrizeType, IGPP_ID, IGpp,
    IGppDispatcher, IGppDispatcherTrait,
};

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

// Prize
pub use prize::{
    ERC20Data, ERC721Data, ExtensionPrizePayload, IPrize, IPrizeDispatcher, IPrizeDispatcherTrait,
    Prize, PrizeRecord, PrizeType, TokenPrizePayload, TokenTypeData,
};

// Registration
pub use registration::{
    IRegistration, IRegistrationDispatcher, IRegistrationDispatcherTrait, Registration,
};

// Registry
pub use registry::{
    DEFAULT_GAME_FEE_BPS, FEE_DENOMINATOR, IMINIGAME_REGISTRY_ID, IMinigameRegistry,
    IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait, default_license,
};

// Structs
pub use structs::{
    GameContext, GameContextDetails, GameCreatorInfo, GameDetail, GameFeeInfo, GameMetadata,
    GameObjective, GameObjectiveDetails, GameSetting, GameSettingDetails, LeaderboardConfig,
    LeaderboardEntry, LeaderboardResult, LeaderboardStoreConfig, Lifecycle, MintBatchRecipient,
    MintGameParams, MintParams, PlayerNameUpdate, TokenMetadata,
};

// Token
pub use token::{
    IMINIGAME_TOKEN_CONTEXT_ID, IMINIGAME_TOKEN_CREATOR_ID, IMINIGAME_TOKEN_ID,
    IMINIGAME_TOKEN_LEGACY_ID, IMINIGAME_TOKEN_MINTER_ID, IMINIGAME_TOKEN_OBJECTIVES_ID,
    IMINIGAME_TOKEN_RENDERER_ID, IMINIGAME_TOKEN_SETTINGS_ID, IMinigameToken, IMinigameTokenCreator,
    IMinigameTokenCreatorDispatcher, IMinigameTokenCreatorDispatcherTrait, IMinigameTokenDispatcher,
    IMinigameTokenDispatcherTrait, IMinigameTokenLegacy, IMinigameTokenLegacyDispatcher,
    IMinigameTokenLegacyDispatcherTrait, IMinigameTokenMinter, IMinigameTokenMinterDispatcher,
    IMinigameTokenMinterDispatcherTrait, IMinigameTokenObjectives,
    IMinigameTokenObjectivesDispatcher, IMinigameTokenObjectivesDispatcherTrait,
    IMinigameTokenRenderer, IMinigameTokenRendererDispatcher, IMinigameTokenRendererDispatcherTrait,
    IMinigameTokenSettings, IMinigameTokenSettingsDispatcher, IMinigameTokenSettingsDispatcherTrait,
};

// Tokenomics (existing)
pub use tokenomics::{buyback, stream};
