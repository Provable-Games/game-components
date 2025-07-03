///
/// Game Component
///
#[starknet::component]
pub mod MetagameComponent {
    use core::num::traits::Zero;
    use crate::interface::{IMetagame, IMETAGAME_ID};
    use game_components_metagame::extensions::context::interface::IMETAGAME_CONTEXT_ID;
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use crate::libs;

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

    use starknet::contract_address::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        minigame_token_address: ContractAddress,
        context_address: ContractAddress,
    }

    #[embeddable_as(MetagameImpl)]
    impl Metagame<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMetagame<ComponentState<TContractState>> {
        fn minigame_token_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.minigame_token_address.read()
        }

        fn context_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.context_address.read()
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
            minigame_token_address: ContractAddress,
        ) {
            self.register_src5_interfaces();
            self.minigame_token_address.write(minigame_token_address.clone());
            match context_address {
                Option::Some(address) => self.context_address.write(address.clone()),
                Option::None => {},
            };
        }

        fn register_src5_interfaces(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMETAGAME_ID);
        }

        fn assert_game_registered(
            ref self: ComponentState<TContractState>, game_address: ContractAddress,
        ) {
            let minigame_token_address = self.minigame_token_address.read();
            libs::assert_game_registered(minigame_token_address, game_address);
        }

        fn mint(
            ref self: ComponentState<TContractState>,
            game_address: Option<ContractAddress>,
            player_name: Option<ByteArray>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_ids: Option<Span<u32>>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            match @context {
                Option::Some(_) => {
                    let context_address = self.context_address.read();
                    if !context_address.is_zero() {
                        let context_src5_dispatcher = ISRC5Dispatcher { contract_address: context_address };
                        assert!(
                            context_src5_dispatcher.supports_interface(IMETAGAME_CONTEXT_ID),
                            "Metagame: Context contract does not support IMetagameContext",
                        );
                    } else {
                        let src5_component = get_dep_component_mut!(ref self, SRC5);
                        assert!(
                            src5_component.supports_interface(IMETAGAME_CONTEXT_ID),
                            "Metagame: Caller does not support IMetagameContext",
                        );
                    }
                },
                Option::None => {},
            }
            let minigame_token_address = self.minigame_token_address.read();
            libs::mint(
                minigame_token_address, 
                game_address, 
                player_name, 
                settings_id, 
                start, 
                end, 
                objective_ids, 
                context, 
                client_url, 
                renderer_address, 
                to, 
                soulbound
            )
        }
    }
}
