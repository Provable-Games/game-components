use starknet::ContractAddress;
use game_components_minigame::extensions::settings::structs::GameSetting;

pub const IMINIGAME_TOKEN_SETTINGS_ID: felt252 =
    0x02e0b4b2324e3b0a64da1d2c55dbbcaf8c369f0dd3f44e23babe98f8de7d6a89;

#[starknet::interface]
pub trait IMinigameTokenSettings<TState> {
    fn create_settings(
        ref self: TState,
        game_address: ContractAddress,
        creator_address: ContractAddress,
        settings_id: u32,
        name: ByteArray,
        description: ByteArray,
        settings_data: Span<GameSetting>,
    );
}
