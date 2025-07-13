// Integration patterns for the configurable direct components architecture
// This module provides common patterns and best practices for using the components

// Common pattern: Minimal configuration
pub mod minimal {
    pub const MINTER_ENABLED: bool = true;
    pub const MULTI_GAME_ENABLED: bool = false;
    pub const OBJECTIVES_ENABLED: bool = false;
    pub const SETTINGS_ENABLED: bool = false;
    pub const SOULBOUND_ENABLED: bool = false;
    pub const CONTEXT_ENABLED: bool = false;
    pub const RENDERER_ENABLED: bool = false;
}

// Common pattern: Gaming configuration
pub mod gaming {
    pub const MINTER_ENABLED: bool = true;
    pub const MULTI_GAME_ENABLED: bool = true;
    pub const OBJECTIVES_ENABLED: bool = true;
    pub const SETTINGS_ENABLED: bool = true;
    pub const SOULBOUND_ENABLED: bool = false;
    pub const CONTEXT_ENABLED: bool = false;
    pub const RENDERER_ENABLED: bool = false;
}

// Common pattern: Full-featured configuration
pub mod full_featured {
    pub const MINTER_ENABLED: bool = true;
    pub const MULTI_GAME_ENABLED: bool = true;
    pub const OBJECTIVES_ENABLED: bool = true;
    pub const SETTINGS_ENABLED: bool = true;
    pub const SOULBOUND_ENABLED: bool = true;
    pub const CONTEXT_ENABLED: bool = true;
    pub const RENDERER_ENABLED: bool = true;
}
