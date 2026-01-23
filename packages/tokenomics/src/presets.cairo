/// Preset contracts for the Autonomous Buyback library
///
/// These are ready-to-deploy contracts that embed the BuybackComponent
/// with appropriate access control.
pub mod autonomous_buyback;
pub mod stream_token;

pub use autonomous_buyback::AutonomousBuyback;
pub use stream_token::StreamToken;
