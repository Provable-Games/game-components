//! Individual Feature Components for Composition
//!
//! This module provides individual components that can be composed together
//! in any combination to create tokens with exactly the features you need.
//!
//! ## Composition Philosophy
//!
//! Instead of choosing between pre-built variants, you compose the exact
//! feature set you need by including the relevant components:
//!
//! ```cairo
//! // Basic token + minter tracking + objectives
//! component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
//! component!(path: MinterComponent, storage: minter, event: MinterEvent);
//! component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);
//! ```

pub mod core_token;           // Basic ERC721 + minigame token functionality
pub mod minter;              // Minter tracking functionality
pub mod multi_game;          // Multi-game support functionality  
pub mod objectives;          // Objectives tracking functionality

// Export individual components for composition
pub use core_token::CoreTokenComponent;
pub use minter::MinterComponent;
pub use multi_game::MultiGameComponent;
pub use objectives::ObjectivesComponent; 