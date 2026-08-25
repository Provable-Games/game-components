//
// Settings Component
//
#[starknet::component]
pub mod SettingsComponent {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::ContractAddress;
    use crate::minigame::extensions::settings::interface::{
        IMINIGAME_SETTINGS_ID, IMinigameSettings,
    };
    use crate::minigame::extensions::settings::libs;

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
    }
}
