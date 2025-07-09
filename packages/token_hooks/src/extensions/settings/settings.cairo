#[starknet::component]
pub mod TokenSettingsComponent {
    use starknet::{ContractAddress, get_caller_address};
    use crate::token::TokenComponent;

    use crate::extensions::settings::interface::{
        IMinigameTokenSettings, IMINIGAME_TOKEN_SETTINGS_ID,
    };

    use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
    use game_components_minigame::extensions::settings::structs::GameSetting;

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;

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

    #[embeddable_as(TokenSettingsImpl)]
    impl TokenSettings<
        TContractState,
        +HasComponent<TContractState>,
        impl Token: TokenComponent::HasComponent<TContractState>,
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
