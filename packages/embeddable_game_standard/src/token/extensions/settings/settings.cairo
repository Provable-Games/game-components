#[starknet::component]
pub mod SettingsComponent {
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::minigame::extensions::settings::interface::{
        IMINIGAME_SETTINGS_ID, IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait,
    };
    use game_components_embeddable_game_standard::minigame::extensions::settings::structs::{
        GameSetting, GameSettingDetails,
    };
    use game_components_embeddable_game_standard::minigame::interface::{
        IMinigameDispatcher, IMinigameDispatcherTrait,
    };
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::token::core::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
    use crate::token::core::traits::OptionalSettings;
    use crate::token::extensions::settings::interface::{
        IMINIGAME_TOKEN_SETTINGS_ID, IMinigameTokenSettings,
    };
    use crate::token::interface::{IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait};

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SettingsCreated: SettingsCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct SettingsCreated {
        #[key]
        pub game_address: ContractAddress,
        #[key]
        pub settings_id: u32,
        pub creator_address: ContractAddress,
        pub name: ByteArray,
        pub description: ByteArray,
        pub settings: Span<GameSetting>,
    }

    #[embeddable_as(SettingsImpl)]
    impl Settings<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IMinigameTokenSettings<ComponentState<TContractState>> {
        fn create_settings(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            creator_address: ContractAddress,
            settings_id: u32,
            settings_details: GameSettingDetails,
        ) {
            // Check caller is settings address
            let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
            let settings_address = minigame_dispatcher.settings_address();
            let settings_address_display: felt252 = settings_address.into();
            let caller = get_caller_address();
            assert!(
                settings_address == caller,
                "MinigameTokenSettings: Settings address {} not registered by caller",
                settings_address_display,
            );

            // Check game address is supported
            let minigame_token_dispatcher = IMinigameTokenDispatcher {
                contract_address: get_contract_address(),
            };
            let is_single_game = game_address == minigame_token_dispatcher.game_address();
            let mut is_multi_game = false;
            let game_registry_address = minigame_token_dispatcher.game_registry_address();
            if !game_registry_address.is_zero() {
                let game_registry_dispatcher = IMinigameRegistryDispatcher {
                    contract_address: game_registry_address,
                };
                let game_id = game_registry_dispatcher.game_id_from_address(game_address);
                is_multi_game = game_id != 0;
            }
            let game_address_display: felt252 = game_address.into();
            assert!(
                is_single_game || is_multi_game,
                "MinigameTokenSettings: Game address {} not supported",
                game_address_display,
            );

            // Emit native event with struct fields directly
            self
                .emit(
                    SettingsCreated {
                        game_address,
                        settings_id,
                        creator_address,
                        name: settings_details.name,
                        description: settings_details.description,
                        settings: settings_details.settings,
                    },
                );
        }
    }

    // Implementation of the OptionalSettings trait for integration with CoreTokenComponent
    pub impl SettingsOptionalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of OptionalSettings<TContractState> {
        fn validate_settings(
            self: @TContractState, game_address: ContractAddress, settings_id: u32,
        ) {
            let settings_component = HasComponent::get_component(self);
            let mut src5_component = get_dep_component!(settings_component, SRC5);
            let supports_settings = src5_component.supports_interface(IMINIGAME_TOKEN_SETTINGS_ID);
            assert!(supports_settings, "MinigameTokenSettings: Contract does not support settings");
            // Get settings address from game
            let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
            let settings_address = minigame_dispatcher.settings_address();

            if !settings_address.is_zero() {
                // Validate settings contract supports interface
                let settings_src5_dispatcher = ISRC5Dispatcher {
                    contract_address: settings_address,
                };
                assert!(
                    settings_src5_dispatcher.supports_interface(IMINIGAME_SETTINGS_ID),
                    "MinigameTokenSettings: Settings contract does not support IMinigameSettings interface",
                );

                // Validate settings exist
                let settings_dispatcher = IMinigameSettingsDispatcher {
                    contract_address: settings_address,
                };
                assert!(
                    settings_dispatcher.settings_exist(settings_id),
                    "MinigameTokenSettings: Settings ID {} does not exist",
                    settings_id,
                );
            }
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_TOKEN_SETTINGS_ID);
        }
    }
}
