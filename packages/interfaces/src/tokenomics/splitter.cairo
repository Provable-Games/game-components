// Token splitter interface. `distribute` is permissionless and works for any
// ERC20 — it only reads the contract's own balance and pays fractions onward.
// The split is fixed at initialization (no setter, no owner).
use starknet::ContractAddress;

/// One destination and its share, in basis points.
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Debug)]
pub struct SplitLeg {
    pub destination: ContractAddress,
    pub bps: u16,
}

#[starknet::interface]
pub trait ISplitter<TState> {
    /// Split this contract's entire balance of `token` across the legs.
    /// Permissionless; works for any ERC20. Returns the amount distributed.
    fn distribute(ref self: TState, token: ContractAddress) -> u256;

    /// `distribute` over several tokens in one call; empty balances are skipped.
    fn distribute_many(ref self: TState, tokens: Span<ContractAddress>);

    /// The configured weighted split.
    fn split(self: @TState) -> Span<SplitLeg>;
}
