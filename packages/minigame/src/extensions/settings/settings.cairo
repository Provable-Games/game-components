//
// Settings Component
//
#[starknet::component]
pub mod SettingsComponent {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::{ContractAddress, get_caller_address};
    use crate::extensions::settings::interface::{IMINIGAME_SETTINGS_ID, IMinigameSettings};
    use crate::extensions::settings::libs;
    use crate::extensions::settings::structs::GameSettingDetails;

    #[storage]
    pub struct Storage {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +IMinigameSettings<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            self.register_settings_interface();
        }

        fn get_settings_id(
            self: @ComponentState<TContractState>,
            token_id: felt252,
            minigame_token_address: ContractAddress,
        ) -> u32 {
            libs::get_settings_id(minigame_token_address, token_id)
        }

        fn register_settings_interface(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_SETTINGS_ID);
        }

        fn create_settings(
            self: @ComponentState<TContractState>,
            game_address: ContractAddress,
            settings_id: u32,
            settings_details: GameSettingDetails,
            minigame_token_address: ContractAddress,
        ) {
            libs::create_settings(
                minigame_token_address,
                game_address,
                get_caller_address(),
                settings_id,
                settings_details,
            );
        }
    }
}
