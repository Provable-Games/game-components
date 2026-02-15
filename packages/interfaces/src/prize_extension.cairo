use starknet::ContractAddress;

pub const IPRIZE_EXTENSION_ID: felt252 =
    0x008dad9d5fe3760c1acdf89c280a08b4979bf656f595f75bc26f39cf12732ee4;

#[starknet::interface]
pub trait IPrizeExtension<TState> {
    /// Get the owner contract address (e.g., budokan, quest manager)
    fn owner_address(self: @TState) -> ContractAddress;

    // --- Deposit lifecycle ---

    /// Called when a prize is deposited
    fn on_deposit(
        ref self: TState,
        context_id: u64,
        prize_id: u64,
        sponsor: ContractAddress,
        token_address: ContractAddress,
        amount_or_token_id: u128,
        is_erc721: bool,
        config: Span<felt252>,
    );

    // --- Claim lifecycle ---

    /// Validate whether a claim should be allowed
    fn validate_claim(
        self: @TState,
        context_id: u64,
        prize_id: u64,
        claimer: ContractAddress,
        position: Option<u32>,
        config: Span<felt252>,
    ) -> bool;

    /// Called before payout - can modify amount. Returns (should_proceed, adjusted_amount)
    fn before_payout(
        ref self: TState,
        context_id: u64,
        prize_id: u64,
        recipient: ContractAddress,
        amount: u128,
        config: Span<felt252>,
    ) -> (bool, u128);

    /// Called after payout is complete
    fn after_payout(
        ref self: TState,
        context_id: u64,
        prize_id: u64,
        recipient: ContractAddress,
        amount: u128,
        config: Span<felt252>,
    );

    // --- ERC721 dynamic generation ---

    /// Generate a dynamic ERC721 prize token ID
    fn generate_erc721_prize(
        ref self: TState,
        context_id: u64,
        prize_id: u64,
        recipient: ContractAddress,
        base_token_id: u128,
        config: Span<felt252>,
    ) -> u128;

    // --- Configuration ---

    /// Add configuration for a context
    fn add_config(ref self: TState, context_id: u64, config: Span<felt252>);
}
