#[starknet::component]
pub mod SettingsComponent {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address};
    // use crate::token::TokenComponent;
    use crate::core::traits::OptionalSettings;

    use crate::extensions::settings::interface::{
        IMinigameTokenSettings, IMINIGAME_TOKEN_SETTINGS_ID,
    };

    use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
    use game_components_minigame::extensions::settings::structs::GameSetting;
    use game_components_minigame::extensions::settings::interface::{IMINIGAME_SETTINGS_ID, IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait};

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SettingsCreated: SettingsCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct SettingsCreated {
        game_address: ContractAddress,
        settings_id: u32,
        created_by: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        settings_data: Span<GameSetting>,
    }

    #[embeddable_as(SettingsImpl)]
    impl Settings<
        TContractState,
        +HasComponent<TContractState>,
        // impl Token: TokenComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameTokenSettings<ComponentState<TContractState>> {
        fn create_settings(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            settings_id: u32,
            name: ByteArray,
            description: ByteArray,
            settings_data: Span<GameSetting>,
        ) {
            let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
            let settings_address = minigame_dispatcher.settings_address();
            let settings_address_display: felt252 = settings_address.into();
            let caller = get_caller_address();
            assert!(
                settings_address == caller,
                "Denshokan: Settings address {} not registered by caller",
                settings_address_display,
            );

            self
                .emit(
                    SettingsCreated {
                        game_address,
                        settings_id,
                        created_by: caller,
                        name,
                        description,
                        settings_data,
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
        fn validate_settings(self: @TContractState, game_address: ContractAddress, settings_id: Option<u32>) -> u32 {
            match settings_id {
                Option::Some(settings_id) => {
                    let settings_component = HasComponent::get_component(self);
                    let mut src5_component = get_dep_component!(settings_component, SRC5);
                    let supports_settings = src5_component.supports_interface(IMINIGAME_TOKEN_SETTINGS_ID);
                    assert!(supports_settings, "MinigameToken: Contract does not settings");
                    // Get settings address from game
                    let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
                    let settings_address = minigame_dispatcher.settings_address();
                    
                    if !settings_address.is_zero() {
                        // Validate settings contract supports interface
                        let settings_src5_dispatcher = ISRC5Dispatcher { contract_address: settings_address };
                        assert!(
                            settings_src5_dispatcher.supports_interface(IMINIGAME_SETTINGS_ID),
                            "CoreToken: Settings contract does not support IMinigameSettings interface"
                        );
                        
                        // Validate settings exist
                        let settings_dispatcher = IMinigameSettingsDispatcher { contract_address: settings_address };
                        assert!(
                            settings_dispatcher.settings_exist(settings_id),
                            "CoreToken: Settings ID {} does not exist",
                            settings_id
                        );
                    }
                    
                    settings_id
                },
                Option::None => 0
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
