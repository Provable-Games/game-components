//! Token Components - Component-Level Feature Composition
//!
//! This package demonstrates an alternative approach to selective feature enablement
//! through component composition rather than callbacks.
//!
//! ## Architecture Philosophy
//!
//! Instead of having one TokenComponent with callbacks for optional features,
//! we provide different component variants that can be composed together:
//!
//! - `CoreTokenComponent`: Basic ERC721 + token functionality
//! - `MinterTokenComponent`: Adds minter tracking functionality
//! - `MultiGameTokenComponent`: Adds multi-game support
//! - `ObjectivesTokenComponent`: Adds objectives support
//! - `FullFeaturedTokenComponent`: Composes all features together
//!
//! ## Usage Patterns
//!
//! ```cairo
//! // Basic token (no optional features)
//! component!(path: CoreTokenComponent, storage: token, event: TokenEvent);
//!
//! // Token with minter tracking
//! component!(path: MinterTokenComponent, storage: token, event: TokenEvent);
//!
//! // Token with all features
//! component!(path: FullFeaturedTokenComponent, storage: token, event: TokenEvent);
//! ```

pub mod components;
pub mod examples;
pub mod interface; 