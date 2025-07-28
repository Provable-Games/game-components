// Configuration constants for compile-time feature toggles
// These can be overridden at the contract level to enable/disable features

// Core features - usually always enabled
pub const CORE_TOKEN_ENABLED: bool = true;
pub const ERC721_ENABLED: bool = true;
pub const SRC5_ENABLED: bool = true;

// Optional features - can be disabled to reduce contract size
pub const MINTER_ENABLED: bool = true;
pub const MULTI_GAME_ENABLED: bool = true;
pub const OBJECTIVES_ENABLED: bool = true;
pub const SETTINGS_ENABLED: bool = true;
pub const SOULBOUND_ENABLED: bool = true;
pub const CONTEXT_ENABLED: bool = true;
pub const RENDERER_ENABLED: bool = true;

// Advanced features
pub const LIFECYCLE_ENABLED: bool = true;
pub const PLAYABILITY_ENABLED: bool = true;

// Interface IDs for compile-time optimization
pub const COMPILE_TIME_INTERFACES: bool = true;
