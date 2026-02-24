use game_components_minigame::extensions::objectives::structs::GameObjective;
use starknet::ContractAddress;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - objectives(u64)->Array<(u32,E((),()))>
/// - objective_ids(u64)->(@Array<u32>)
/// - all_objectives_completed(u64)->E((),())
/// - create_objective(ContractAddress,ContractAddress,u32,GameObjective)
pub const IMINIGAME_TOKEN_OBJECTIVES_ID: felt252 =
    0x24388022f3ac79ab2d16c1e1091938431e1ff4ffe67386872e519257db01525;

#[starknet::interface]
pub trait IMinigameTokenObjectives<TState> {
    // fn objectives_count(self: @TState, token_id: u64) -> u32;
    fn objectives(self: @TState, token_id: u64) -> Array<TokenObjective>;
    fn objective_ids(self: @TState, token_id: u64) -> Span<u32>;
    fn all_objectives_completed(self: @TState, token_id: u64) -> bool;
    fn create_objective(
        ref self: TState,
        game_address: ContractAddress,
        creator_address: ContractAddress,
        objective_id: u32,
        objective_data: GameObjective,
    );
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TokenObjective {
    pub objective_id: u32,
    pub completed: bool,
}
