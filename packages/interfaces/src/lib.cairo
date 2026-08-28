// Game Components Interfaces
// Standalone interface definitions for game component contracts

// Struct definitions
pub mod structs;
pub use structs::{
    leaderboard as leaderboard_structs, metagame as metagame_structs, minigame as minigame_structs,
    token as token_structs,
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
    IMETAGAME_CONTEXT_ID, IMetagameContext, IMetagameContextDetails,
    IMetagameContextDetailsDispatcher, IMetagameContextDetailsDispatcherTrait,
    IMetagameContextDispatcher, IMetagameContextDispatcherTrait, IMetagameContextSVG,
    IMetagameContextSVGDispatcher, IMetagameContextSVGDispatcherTrait,
};

// Minigame
pub use minigame::{
    IMINIGAME_OBJECTIVES_ID, IMINIGAME_SETTINGS_ID, IMinigameObjectives, IMinigameObjectivesDetails,
    IMinigameObjectivesDetailsDispatcher, IMinigameObjectivesDetailsDispatcherTrait,
    IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait, IMinigameObjectivesSVG,
    IMinigameObjectivesSVGDispatcher, IMinigameObjectivesSVGDispatcherTrait, IMinigameSettings,
    IMinigameSettingsDetails, IMinigameSettingsDetailsDispatcher,
    IMinigameSettingsDetailsDispatcherTrait, IMinigameSettingsDispatcher,
    IMinigameSettingsDispatcherTrait, IMinigameSettingsSVG, IMinigameSettingsSVGDispatcher,
    IMinigameSettingsSVGDispatcherTrait, IMinigameTokenData, IMinigameTokenDataDispatcher,
    IMinigameTokenDataDispatcherTrait,
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

// Structs
pub use structs::{
    GameContext, GameContextDetails, GameDetail, GameFeeTerms, GameMetadata, GameObjective,
    GameObjectiveDetails, GameSetting, GameSettingDetails, LeaderboardConfig, LeaderboardEntry,
    LeaderboardResult, LeaderboardStoreConfig, Lifecycle, MintBatchRecipient, TokenMetadata,
};

// Token
pub use token::{
    DEFAULT_GAME_FEE_BPS, FEE_DENOMINATOR, IMINIGAME_TOKEN_GAME_FEE_ID, IMINIGAME_TOKEN_ID,
    IMINIGAME_TOKEN_MINTER_ID, IMinigameToken, IMinigameTokenDispatcher,
    IMinigameTokenDispatcherTrait, IMinigameTokenGameFee, IMinigameTokenGameFeeDispatcher,
    IMinigameTokenGameFeeDispatcherTrait, IMinigameTokenMinter, IMinigameTokenMinterDispatcher,
    IMinigameTokenMinterDispatcherTrait, default_license,
};

// Tokenomics (existing)
pub use tokenomics::{buyback, deposit_lock, splitter, stream};
