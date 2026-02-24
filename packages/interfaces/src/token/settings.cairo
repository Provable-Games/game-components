// Token settings extension interface
use starknet::ContractAddress;
use crate::structs::minigame::GameSettingDetails;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - create_settings(ContractAddress,ContractAddress,u32,GameSettingDetails)
pub const IMINIGAME_TOKEN_SETTINGS_ID: felt252 =
    0x229ba85053f3653daaa2e0d3a9f9296e6d3eae099557c7610822f5b556f1bc8;

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
