// Test categories - private (no external access needed)
mod examples;
pub mod fixtures;
mod fuzz;

// Shared utilities - public for cross-module access
pub mod helpers;
mod integration;
mod unit;
