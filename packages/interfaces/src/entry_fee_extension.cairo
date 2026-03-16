use starknet::ContractAddress;

pub const IENTRY_FEE_EXTENSION_ID: felt252 =
    0x03a74a2500216692acc4a3ecbbe1fd617144b136f0233258752183a06a68beba;

#[starknet::interface]
pub trait IEntryFeeExtension<TState> {
    fn owner_address(self: @TState) -> ContractAddress;
    fn set_entry_fee_config(ref self: TState, context_id: u64, config: Span<felt252>);
    fn pay_entry_fee(ref self: TState, context_id: u64, pay_params: Span<felt252>);
    fn claim_entry_fee(ref self: TState, context_id: u64, claim_params: Span<felt252>);
}
