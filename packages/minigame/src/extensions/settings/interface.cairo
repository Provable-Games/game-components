use crate::extensions::settings::structs::GameSettingDetails;

pub const IMINIGAME_SETTINGS_ID: felt252 =
    0x0379f4343538c65a38349fb1318328629dd950d3624101aeaac1b4bd45a39eff;

#[starknet::interface]
pub trait IMinigameSettings<TState> {
    fn settings_exist(self: @TState, settings_id: u32) -> bool;
}

#[starknet::interface]
pub trait IMinigameSettingsDetails<TState> {
    fn settings_details(self: @TState, settings_id: u32) -> GameSettingDetails;
}

#[starknet::interface]
pub trait IMinigameSettingsSVG<TState> {
    fn settings_svg(self: @TState, settings_id: u32) -> ByteArray;
}
