use starknet::ContractAddress;
use super::extension::ExtensionConfig;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - get_entry_fee(u64)->Option<EntryFeeConfig>
pub const IENTRY_FEE_ID: felt252 =
    0x2386e28587616f249621004456b4ed72932c1f731b2a732d87d8a722ee739a1;

/// Additional share configuration for entry fee distribution
/// These shares are deducted from the total pool before position-based distribution
#[derive(Copy, Drop, Serde, PartialEq)]
pub struct AdditionalShare {
    /// Recipient address for this share
    pub recipient: ContractAddress,
    /// Share in basis points (10000 = 100%)
    pub share_bps: u16,
}

/// Entry fee configuration (the core config fields)
#[derive(Drop, Serde, PartialEq)]
pub struct EntryFeeConfig {
    pub token_address: ContractAddress,
    pub amount: u128,
    /// Game creator share in basis points (10000 = 100%)
    pub game_creator_share: Option<u16>,
    /// Share refunded back to each depositor in basis points
    pub refund_share: Option<u16>,
    /// Additional shares deducted before position distribution
    pub additional_shares: Span<AdditionalShare>,
}

/// Entry fee enum: dispatch to either store config or set extension
#[derive(Drop, Serde)]
pub enum EntryFee {
    Config: EntryFeeConfig,
    Extension: ExtensionConfig,
}

/// Entry fee deposit enum: dispatch to either direct ERC20 transfer or extension payment
#[derive(Drop, Serde)]
pub enum EntryFeeDeposit {
    /// Direct ERC20 deposit using stored config
    Config: EntryFeeConfig,
    /// Extension-based payment with caller-provided params
    Extension: Span<felt252>,
}

#[starknet::interface]
pub trait IEntryFee<TState> {
    /// Get entry fee configuration for a context
    /// Returns None if no entry fee is set
    fn get_entry_fee(self: @TState, context_id: u64) -> Option<EntryFeeConfig>;
}
