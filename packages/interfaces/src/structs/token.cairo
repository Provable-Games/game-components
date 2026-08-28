// Token structs
// Note: StorePacking implementations are in the token package for optimized storage
use starknet::ContractAddress;

/// A self-bound standard token's declared monetization terms: the fee
/// recipient (payee), license text and fee rate. Replaces the retired
/// registry's `GameFeeInfo` lookup: the terms live on the game/token
/// contract itself (see `token::game_fee`).
#[derive(Drop, Serde, Clone, PartialEq)]
pub struct GameFeeTerms {
    pub recipient: ContractAddress,
    pub license: ByteArray,
    /// Fee in basis points (against `FEE_DENOMINATOR` = 10_000)
    pub fee_numerator: u16,
}

#[derive(Copy, Drop, Serde)]
pub struct Lifecycle {
    pub start: u64,
    pub end: u64,
}

#[derive(Copy, Drop, Serde)]
pub struct TokenMetadata {
    pub minted_at: u64,
    pub settings_id: u32,
    pub lifecycle: Lifecycle,
    pub minted_by: u64,
    pub soulbound: bool,
    pub game_over: bool,
    pub completed_objective: bool,
    /// Unix timestamp when objective was completed, 0 if not yet completed
    pub completed_at: u32,
    pub has_context: bool,
    pub objective_id: u32,
    pub paymaster: bool,
    /// Inert data the game interprets, 65 bits wide — matching the token id's
    /// packed field exactly, so the value read back is the value minted.
    pub metadata: u128,
}

impl TokenMetadataDefault of Default<TokenMetadata> {
    fn default() -> TokenMetadata {
        TokenMetadata {
            minted_at: 0,
            settings_id: 0,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 0,
            soulbound: false,
            game_over: false,
            completed_objective: false,
            completed_at: 0,
            has_context: false,
            objective_id: 0,
            paymaster: false,
            metadata: 0,
        }
    }
}

/// Per-recipient parameters for `mint_batch_recipients`.
/// Mints `count` tokens to `to` with the shared mint config supplied by the caller.
/// The salt provided to `mint_batch_recipients` increments by one per minted token
/// (across all recipients) for deterministic, collision-free token IDs.
#[derive(Copy, Drop, Serde)]
pub struct MintBatchRecipient {
    pub to: ContractAddress,
    pub count: u16,
}

