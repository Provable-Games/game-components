use starknet::ContractAddress;

pub const IENTRY_FEE_EXTENSION_ID: felt252 =
    0x03b4fbddbe815d9d8839a14cde7e0b500d2ed7e6fa0a0b1f324d477e12819327;

#[starknet::interface]
pub trait IEntryFeeExtension<TState> {
    /// Get the owner contract address (e.g., budokan, quest manager)
    fn owner_address(self: @TState) -> ContractAddress;

    // --- Deposit lifecycle ---

    /// Calculate the actual fee amount for a player (allows dynamic pricing)
    fn calculate_fee(
        self: @TState,
        context_id: u64,
        base_amount: u128,
        player: ContractAddress,
        config: Span<felt252>,
    ) -> u128;

    /// Validate whether a deposit should be accepted
    fn validate_deposit(
        self: @TState,
        context_id: u64,
        player: ContractAddress,
        amount: u128,
        config: Span<felt252>,
    ) -> bool;

    /// Called after a deposit is processed
    fn on_deposit(
        ref self: TState,
        context_id: u64,
        token_address: ContractAddress,
        amount: u128,
        player: ContractAddress,
        config: Span<felt252>,
    );

    // --- Claim/Payout lifecycle ---

    /// Called when a claim is processed
    fn on_claim(
        ref self: TState,
        context_id: u64,
        claim_type: Span<felt252>,
        claimer: ContractAddress,
        amount: u128,
        config: Span<felt252>,
    );

    /// Called when a refund is processed
    fn on_refund(
        ref self: TState,
        context_id: u64,
        recipient: ContractAddress,
        amount: u128,
        config: Span<felt252>,
    );

    // --- Configuration ---

    /// Add configuration for a context
    fn add_config(ref self: TState, context_id: u64, config: Span<felt252>);
}
