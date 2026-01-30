///
/// Game Component
///
#[starknet::component]
pub mod MetagameComponent {
    use core::num::traits::Zero;
    use game_components_metagame::extensions::context::interface::IMETAGAME_CONTEXT_ID;
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use game_components_token::core::interface::IMINIGAME_TOKEN_ID;
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use starknet::contract_address::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::interface::{IMETAGAME_ID, IMetagame};
    use crate::libs;
    use crate::structs::MintMetagameParams;

    #[storage]
    pub struct Storage {
        context_address: ContractAddress,
        default_token_address: ContractAddress,
    }

    #[embeddable_as(MetagameImpl)]
    impl Metagame<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMetagame<ComponentState<TContractState>> {
        fn context_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.context_address.read()
        }

        fn default_token_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.default_token_address.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            context_address: Option<ContractAddress>,
            default_token_address: ContractAddress,
        ) {
            self.register_src5_interfaces();
            match context_address {
                Option::Some(context_address) => {
                    assert!(!context_address.is_zero(), "Metagame: Context address is zero");
                    let context_src5_dispatcher = ISRC5Dispatcher {
                        contract_address: context_address,
                    };
                    assert!(
                        context_src5_dispatcher.supports_interface(IMETAGAME_CONTEXT_ID),
                        "Metagame: Context contract does not support IMetagameContext",
                    );
                    self.context_address.write(context_address);
                },
                Option::None => {},
            }
            assert!(!default_token_address.is_zero(), "Metagame: Default token address is zero");
            let minigame_dispatcher = ISRC5Dispatcher { contract_address: default_token_address };
            assert!(
                minigame_dispatcher.supports_interface(IMINIGAME_TOKEN_ID),
                "Metagame: Default token contract does not support IMinigameToken",
            );
            self.default_token_address.write(default_token_address);
        }

        fn register_src5_interfaces(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMETAGAME_ID);
        }

        fn assert_game_registered(
            ref self: ComponentState<TContractState>, game_address: ContractAddress,
        ) {
            libs::assert_game_registered(game_address);
        }

        fn mint(
            ref self: ComponentState<TContractState>,
            game_address: Option<ContractAddress>,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> felt252 {
            libs::mint(
                self.default_token_address.read(),
                game_address,
                player_name,
                settings_id,
                start,
                end,
                objective_id,
                context,
                client_url,
                renderer_address,
                to,
                soulbound,
                paymaster,
                salt,
                metadata,
            )
        }

        fn mint_batch(
            ref self: ComponentState<TContractState>, mints: Array<MintMetagameParams>,
        ) -> Array<felt252> {
            libs::mint_batch(self.default_token_address.read(), mints)
        }
    }
}
