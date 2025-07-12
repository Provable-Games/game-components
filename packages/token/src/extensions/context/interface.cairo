// #[starknet::interface]
// pub trait IMinigameTokenContext<TState> {
//     fn get_context(self: @TState, token_id: u64) -> ContextMetadata;
//     fn context_exists(self: @TState, token_id: u64) -> bool;
// }

// #[derive(Copy, Drop, Serde, starknet::Store)]
// pub struct ContextMetadata {
//     pub token_id: u64,
//     pub game_address: starknet::ContractAddress,
//     pub context_data: felt252,
//     pub timestamp: u64,
// }