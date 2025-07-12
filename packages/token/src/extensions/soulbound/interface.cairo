#[starknet::interface]
pub trait IMinigameTokenSoulbound<TState> {
    fn is_soulbound(self: @TState, token_id: u64) -> bool;
    fn make_soulbound(ref self: TState, token_id: u64);
    fn revoke_soulbound(ref self: TState, token_id: u64);
}