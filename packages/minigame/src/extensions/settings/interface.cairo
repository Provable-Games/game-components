use crate::extensions::settings::structs::GameSettingDetails;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - settings_exist(u32)->E((),())
pub const IMINIGAME_SETTINGS_ID: felt252 =
    0x36ec07245baa003895b30a91b753ae24f6b17ed9625a056875ad26763f3ec9c;

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
