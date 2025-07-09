// Optimized Token Components - Configurable Direct Components Architecture
// This package provides a revolutionary approach to building token contracts
// with compile-time optimization and runtime sophistication.

pub mod config;
pub mod structs;
pub mod interface;
pub mod libs;
pub mod core;
pub mod features;
pub mod integration;
// pub mod examples;  // Temporarily disabled for compilation

// Re-export key structs and interfaces for convenience
pub use core::interface::ICoreToken;
pub use core::traits::{
    OptionalMinter, OptionalMultiGame, OptionalContext, OptionalObjectives,
    OptionalSoulbound, OptionalRenderer, NoOpMinter, NoOpMultiGame, NoOpContext,
    NoOpObjectives, NoOpSoulbound, NoOpRenderer
};

// Re-export key structs and constants
pub use config::*;
pub use structs::*;
pub use interface::*;
pub use libs::*; 