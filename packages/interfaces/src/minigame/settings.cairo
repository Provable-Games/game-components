// Minigame settings extension interface
use crate::structs::minigame::GameSettingDetails;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - settings_exist(u32)->E((),())
/// - settings_exist_batch((@Array<u32>))->Array<E((),())>
pub const IMINIGAME_SETTINGS_ID: felt252 =
    0x1a58ab3ee416cc018f93236fd0bb995de89ee536626c268491121e51a46a0f4;

#[starknet::interface]
pub trait IMinigameSettings<TState> {
    fn settings_exist(self: @TState, settings_id: u32) -> bool;

    // Batch operations
    fn settings_exist_batch(self: @TState, settings_ids: Span<u32>) -> Array<bool>;
}

#[starknet::interface]
pub trait IMinigameSettingsDetails<TState> {
    fn settings_count(self: @TState) -> u32;
    fn settings_details(self: @TState, settings_id: u32) -> GameSettingDetails;

    // Batch operations
    fn settings_details_batch(self: @TState, settings_ids: Span<u32>) -> Array<GameSettingDetails>;
}

#[starknet::interface]
pub trait IMinigameSettingsSVG<TState> {
    fn settings_svg(self: @TState, settings_id: u32) -> ByteArray;
}
