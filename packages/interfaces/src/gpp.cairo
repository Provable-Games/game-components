// GPP (Guaranteed Prize Pool) interfaces and types

use starknet::ContractAddress;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - get_gpp_config(u64)->(u32,u32)
/// - get_gpp_pool_state(u64)->(u128,u32,u32,u8,u32,ContractAddress)
/// - get_gpp_active_count(u64)->u32
/// - get_gpp_funded_slots(u64)->u32
/// - is_gpp_claimed(u64,felt252)->E((),())
pub const IGPP_ID: felt252 = 0x27e9df08e4ac0ddb88b352a1c8d1abb988afaff0d362bc83f97a8ca4ae0a70;

/// Configuration for a GPP context (rules only, set at creation)
#[derive(Copy, Drop, Serde)]
pub struct GppConfig {
    pub capacity: u32,
    pub game_lifetime: u32,
}

/// Prize funding type
#[derive(Drop, Serde)]
pub enum GppPrizeType {
    ERC20: GppERC20Prize,
    ERC721: GppERC721Prize,
}

#[derive(Copy, Drop, Serde)]
pub struct GppERC20Prize {
    pub amount: u128,
    pub per_entrant: u128,
}

#[derive(Copy, Drop, Serde)]
pub struct GppERC721Prize {
    pub token_id: u128,
}

/// Pool state view (returned by get_gpp_pool_state)
#[derive(Copy, Drop, Serde)]
pub struct GppPoolState {
    pub pool_balance: u128,
    pub active_count: u32,
    pub nft_top: u32,
    pub prize_type: u8,
    pub capacity: u32,
    pub prize_token: ContractAddress,
}

/// Read-only interface for GPP state
#[starknet::interface]
pub trait IGpp<TState> {
    fn get_gpp_config(self: @TState, context_id: u64) -> GppConfig;
    fn get_gpp_pool_state(self: @TState, context_id: u64) -> GppPoolState;
    fn get_gpp_active_count(self: @TState, context_id: u64) -> u32;
    fn get_gpp_funded_slots(self: @TState, context_id: u64) -> u32;
    fn is_gpp_claimed(self: @TState, context_id: u64, token_id: felt252) -> bool;
}
