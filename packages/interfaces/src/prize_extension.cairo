use starknet::ContractAddress;

pub const IPRIZE_EXTENSION_ID: felt252 =
    0x008dad9d5fe3760c1acdf89c280a08b4979bf656f595f75bc26f39cf12732ee4;

#[starknet::interface]
pub trait IPrizeExtension<TState> {
    /// Get the owner contract address (e.g., budokan, quest manager)
    fn owner_address(self: @TState) -> ContractAddress;

    /// Add a prize configuration for a context
    fn add_prize(ref self: TState, context_id: u64, prize_id: u64, config: Span<felt252>);

    /// Claim a prize for a context
    fn claim_prize(ref self: TState, context_id: u64, claim_params: Span<felt252>);
}
