///
/// Game Component
///
#[starknet::component]
pub mod MetagameComponent {
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::metagame::extensions::context::interface::IMETAGAME_CONTEXT_ID;
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
    use game_components_embeddable_game_standard::token::interface::IMINIGAME_TOKEN_ID;
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use starknet::contract_address::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::metagame::interface::{IMETAGAME_ID, IMetagame};
    use crate::metagame::metagame as libs;
    use crate::metagame::structs::MintMetagameParams;
    use crate::minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
    use crate::registry::interface::{IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait};
    use crate::token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};

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
            skills_address: Option<ContractAddress>,
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
                skills_address,
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

        /// Reads fee from registry, calculates amount, transfers via ERC20
        /// to the game's creator token owner. Returns fee amount (0 if no fee).
        fn pay_game_fee(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            payment_token: ContractAddress,
            revenue: u128,
        ) -> u128 {
            let fee_info = libs::get_game_fee_info(game_address);
            let fee_amount = libs::calculate_game_fee(revenue, fee_info.fee_numerator);
            if fee_amount == 0 {
                return 0;
            }

            // Get the creator token owner (fee recipient)
            let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
            let token_address = minigame_dispatcher.token_address();
            let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
            let registry_address = token_dispatcher.game_registry_address();
            let registry_dispatcher = IMinigameRegistryDispatcher {
                contract_address: registry_address,
            };
            let game_id = registry_dispatcher.game_id_from_address(game_address);

            // Get creator token owner via ERC721 owner_of
            let erc721 = IERC721Dispatcher { contract_address: registry_address };
            let recipient = erc721.owner_of(game_id.into());

            // Transfer fee
            let erc20 = IERC20Dispatcher { contract_address: payment_token };
            erc20.transfer(recipient, fee_amount.into());

            fee_amount
        }
    }
}
