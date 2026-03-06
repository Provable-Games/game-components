// Token settings extension interface
use starknet::ContractAddress;
use crate::structs::minigame::GameSettingDetails;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// -
/// create_settings(ContractAddress,ContractAddress,u32,((Array<bytes31>,felt252,usize),(Array<bytes31>,felt252,usize),(@Array<(felt252,felt252)>)))
pub const IMINIGAME_TOKEN_SETTINGS_ID: felt252 =
    0x3c6f5c714fef5141bb7edbbbf738c80782154e825a5675355c937aa9bc07bae;

#[starknet::interface]
pub trait IMinigameTokenSettings<TState> {
    fn create_settings(
        ref self: TState,
        game_address: ContractAddress,
        creator_address: ContractAddress,
        settings_id: u32,
        settings_details: GameSettingDetails,
    );
}
