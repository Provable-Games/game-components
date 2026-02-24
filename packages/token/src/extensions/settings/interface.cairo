use game_components_minigame::extensions::settings::structs::GameSetting;
use starknet::ContractAddress;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - create_settings(ContractAddress,ContractAddress,u32,ByteArray,ByteArray,Span<GameSetting>)
pub const IMINIGAME_TOKEN_SETTINGS_ID: felt252 =
    0x35f83f541ee6ba95f19c5c8f3f76cee93d28253005ca2e407570297e6ce97db;

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
