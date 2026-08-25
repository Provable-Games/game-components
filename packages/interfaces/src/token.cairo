// Token interfaces module
//
// The legacy generation's surfaces (`legacy`, and the `context`, `objectives`,
// `renderer`, `settings`, `skills` token extensions) were removed with the
// registry-backed token. Deployed legacy contracts still carry their ids
// on-chain — pin v2.0.0 or earlier to build against them.

pub mod core;
pub mod game_fee;
pub mod minter;

// Re-export commonly used items at top level
pub use core::{
    IMINIGAME_TOKEN_ID, IMinigameToken, IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    MinigameTokenABI, MinigameTokenABIDispatcher, MinigameTokenABIDispatcherTrait,
};
pub use game_fee::{
    DEFAULT_GAME_FEE_BPS, FEE_DENOMINATOR, IMINIGAME_TOKEN_GAME_FEE_ID, IMinigameTokenGameFee,
    IMinigameTokenGameFeeDispatcher, IMinigameTokenGameFeeDispatcherTrait, default_license,
};
pub use minter::{
    IMINIGAME_TOKEN_MINTER_ID, IMinigameTokenMinter, IMinigameTokenMinterDispatcher,
    IMinigameTokenMinterDispatcherTrait,
};
