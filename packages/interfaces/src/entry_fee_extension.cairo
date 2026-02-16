use starknet::ContractAddress;

pub const IENTRY_FEE_EXTENSION_ID: felt252 =
    0x03b4fbddbe815d9d8839a14cde7e0b500d2ed7e6fa0a0b1f324d477e12819327;

#[starknet::interface]
pub trait IEntryFeeExtension<TState> {
    /// Get the owner contract address (e.g., budokan, quest manager)
    fn owner_address(self: @TState) -> ContractAddress;

    /// Set entry fee configuration for a context (called during setup)
    fn set_entry_fee_config(ref self: TState, context_id: u64, config: Span<felt252>);

    /// Pay entry fee for a context (called during deposit via extension)
    fn pay_entry_fee(ref self: TState, context_id: u64, pay_params: Span<felt252>);

    /// Claim entry fee for a context
    fn claim_entry_fee(ref self: TState, context_id: u64, claim_params: Span<felt252>);
}
