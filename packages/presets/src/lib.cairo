// SPDX-License-Identifier: BUSL-1.1

/// # Game Components Presets
///
/// Ready-to-deploy contracts built with game components.
/// These presets provide simple, generic implementations suitable for
/// common gaming use cases without requiring custom contract development.
///
/// ## Available Presets
/// - **Leaderboard**: Tournament leaderboard management with scoring and ranking
/// - **AutonomousBuyback**: Autonomous token buyback via Ekubo TWAMM
/// - **StreamToken**: ERC20 token with built-in TWAMM distribution

pub mod autonomous_buyback;
pub mod leaderboard;
pub mod stream_token;

pub use autonomous_buyback::AutonomousBuyback;
pub use stream_token::StreamToken;

#[cfg(test)]
mod tests;
