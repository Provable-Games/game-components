use interfaces::extension::ExtensionConfig;
use starknet::ContractAddress;

pub const IENTRY_FEE_ID: felt252 =
    0x022972c149377b51478a25ad70c95a0d3df9e6cfc5d7a0757c2a01acc8aedbd1;

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
