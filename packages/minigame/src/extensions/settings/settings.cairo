//
// Settings Component
//
#[starknet::component]
pub mod SettingsComponent {
    use crate::extensions::settings::interface::{IMinigameSettings, IMINIGAME_SETTINGS_ID};
    use crate::extensions::settings::libs;
    use crate::extensions::settings::structs::{GameSetting};
    use starknet::{ContractAddress, get_contract_address, get_caller_address};

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;

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
            token_id: u64,
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
            settings_id: u32,
            name: ByteArray,
            description: ByteArray,
            settings: Span<GameSetting>,
            minigame_token_address: ContractAddress,
        ) {
            libs::create_settings(
                minigame_token_address,
                get_contract_address(),
                get_caller_address(),
                settings_id,
                name,
                description,
                settings,
            );
        }
    }
}
