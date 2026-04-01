///
/// Ticket Booth Component
///
/// A payment-enabled metagame component that charges tokens for game access.
///
/// The component provides internal functions for updating configuration.
/// Contracts using this component have two options:
///
/// 1. **Immutable Configuration**: Don't implement update functions
/// 2. **Updatable Configuration**: Implement update functions with proper access control
///
#[feature("safe_dispatcher")]
#[starknet::component]
pub mod TicketBoothComponent {
    use core::byte_array::ByteArray;
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::minigame::minigame::mint;
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use starknet::contract_address::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{get_block_timestamp, get_caller_address};
    use crate::ticket_booth::structs::{GoldenPass, PaymentType};
    use crate::ticket_booth::ticket_booth;

    #[starknet::interface]
    trait IERC20Burnable<TContractState> {
        fn burn_from(ref self: TContractState, account: ContractAddress, amount: u256);
    }

    #[storage]
    pub struct Storage {
        opening_time: u64,
        denshokan_address: ContractAddress,
        game_token_address: ContractAddress,
        game_address: ContractAddress,
        payment_token: ContractAddress,
        cost_to_play: u128,
        ticket_receiver_address: ContractAddress,
        settings_id: Option<u32>,
        start_time: Option<u64>,
        expiration_time: Option<u64>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        golden_passes: Map<ContractAddress, GoldenPass>,
        golden_pass_last_used: Map<(ContractAddress, u128), u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        GameBought: GameBought,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameBought {
        #[key]
        pub player: ContractAddress,
        pub token_id: felt252,
        pub payment_type: PaymentType,
    }

    #[starknet::interface]
    pub trait ITicketBooth<TContractState> {
        fn buy_game(
            ref self: TContractState,
            payment_type: PaymentType,
            player_name: Option<felt252>,
            to: ContractAddress,
            soulbound: bool,
        ) -> felt252;

        fn payment_token(self: @TContractState) -> ContractAddress;
        fn cost_to_play(self: @TContractState) -> u128;
        fn settings_id(self: @TContractState) -> Option<u32>;
        fn start_time(self: @TContractState) -> Option<u64>;
        fn expiration_time(self: @TContractState) -> Option<u64>;
        fn client_url(self: @TContractState) -> Option<ByteArray>;
        fn renderer_address(self: @TContractState) -> Option<ContractAddress>;
        fn get_golden_pass(
            self: @TContractState, golden_pass_address: ContractAddress,
        ) -> Option<GoldenPass>;
        fn golden_pass_last_used(
            self: @TContractState, golden_pass_address: ContractAddress, token_id: u128,
        ) -> u64;
        fn is_golden_pass_usable(
            self: @TContractState, golden_pass_address: ContractAddress, token_id: u128,
        ) -> bool;
        fn ticket_receiver_address(self: @TContractState) -> ContractAddress;
        fn opening_time(self: @TContractState) -> u64;
    }

    #[embeddable_as(TicketBoothImpl)]
    impl TicketBooth<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of ITicketBooth<ComponentState<TContractState>> {
        fn buy_game(
            ref self: ComponentState<TContractState>,
            payment_type: PaymentType,
            player_name: Option<felt252>,
            to: ContractAddress,
            soulbound: bool,
        ) -> felt252 {
            assert!(get_block_timestamp() >= self.opening_time.read(), "Game not open yet");

            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Handle payment based on type and get expiration
            let expiration = match payment_type.clone() {
                PaymentType::Ticket => {
                    self.handle_ticket_payment(caller);
                    ticket_booth::calculate_ticket_expiration(
                        self.expiration_time.read(), current_time,
                    )
                },
                PaymentType::GoldenPass(golden_pass_info) => {
                    self
                        .handle_golden_pass_payment(
                            caller,
                            golden_pass_info.address,
                            golden_pass_info.token_id,
                            current_time,
                            to,
                        )
                },
            };

            // Mint the game token with configured settings
            let token_id = self
                .mint_game(player_name, to, soulbound, self.start_time.read(), expiration);

            // Emit the event
            self.emit(GameBought { player: to, token_id, payment_type });

            token_id
        }


        fn get_golden_pass(
            self: @ComponentState<TContractState>, golden_pass_address: ContractAddress,
        ) -> Option<GoldenPass> {
            let golden_pass = self.golden_passes.read(golden_pass_address);
            if ticket_booth::is_golden_pass_configured(@golden_pass) {
                Option::Some(golden_pass)
            } else {
                Option::None
            }
        }

        fn golden_pass_last_used(
            self: @ComponentState<TContractState>,
            golden_pass_address: ContractAddress,
            token_id: u128,
        ) -> u64 {
            self.golden_pass_last_used.read((golden_pass_address, token_id))
        }

        fn is_golden_pass_usable(
            self: @ComponentState<TContractState>,
            golden_pass_address: ContractAddress,
            token_id: u128,
        ) -> bool {
            let golden_pass_config = self.golden_passes.read(golden_pass_address);
            let current_time = get_block_timestamp();
            let last_used = self.golden_pass_last_used.read((golden_pass_address, token_id));
            ticket_booth::is_golden_pass_usable(@golden_pass_config, last_used, current_time)
        }

        fn ticket_receiver_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.ticket_receiver_address.read()
        }

        fn payment_token(self: @ComponentState<TContractState>) -> ContractAddress {
            self.payment_token.read()
        }

        fn cost_to_play(self: @ComponentState<TContractState>) -> u128 {
            self.cost_to_play.read()
        }

        fn settings_id(self: @ComponentState<TContractState>) -> Option<u32> {
            self.settings_id.read()
        }

        fn start_time(self: @ComponentState<TContractState>) -> Option<u64> {
            self.start_time.read()
        }

        fn expiration_time(self: @ComponentState<TContractState>) -> Option<u64> {
            self.expiration_time.read()
        }


        fn client_url(self: @ComponentState<TContractState>) -> Option<ByteArray> {
            self.client_url.read()
        }

        fn renderer_address(self: @ComponentState<TContractState>) -> Option<ContractAddress> {
            self.renderer_address.read()
        }

        fn opening_time(self: @ComponentState<TContractState>) -> u64 {
            self.opening_time.read()
        }
    }


    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            opening_time: u64,
            denshokan_address: ContractAddress,
            game_token_address: ContractAddress,
            payment_token: ContractAddress,
            cost_to_play: u128,
            ticket_receiver_address: ContractAddress,
            game_address: Option<ContractAddress>,
            settings_id: Option<u32>,
            start_time: Option<u64>,
            expiration_time: Option<u64>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            golden_passes: Option<Span<(ContractAddress, GoldenPass)>>,
        ) {
            // Validate required parameters
            assert!(!denshokan_address.is_zero(), "Denshokan address cannot be zero");
            assert!(!game_token_address.is_zero(), "Game token address cannot be zero");
            assert!(cost_to_play > 0_u128, "Cost to play must be greater than zero");

            self.opening_time.write(opening_time);
            self.denshokan_address.write(denshokan_address);
            self.game_token_address.write(game_token_address);
            self.payment_token.write(payment_token);
            self.cost_to_play.write(cost_to_play);
            match game_address {
                Option::Some(addr) => self.game_address.write(addr),
                Option::None => self.game_address.write(0.try_into().unwrap()),
            }
            self.settings_id.write(settings_id);
            self.start_time.write(start_time);
            self.expiration_time.write(expiration_time);

            self.client_url.write(client_url);
            self.renderer_address.write(renderer_address);
            self.ticket_receiver_address.write(ticket_receiver_address);

            // Configure golden passes if provided
            match golden_passes {
                Option::Some(passes) => {
                    let mut i = 0;
                    loop {
                        if i >= passes.len() {
                            break;
                        }
                        let (address, config) = passes.at(i);
                        assert!(
                            *config.cooldown > 0_u64,
                            "Golden pass cooldown must be greater than zero",
                        );
                        self.golden_passes.write(*address, config.clone());
                        i += 1;
                    };
                },
                Option::None => {},
            };
        }

        fn handle_ticket_payment(
            ref self: ComponentState<TContractState>, caller: ContractAddress,
        ) {
            let cost = self.cost_to_play.read();
            let payment_token_address = self.payment_token.read();
            let ticket_receiver_address = self.ticket_receiver_address.read();

            assert!(!payment_token_address.is_zero(), "Payment token cannot be zero address");

            // Handle payment (redeem the ticket)
            let payment_token = IERC20Dispatcher { contract_address: payment_token_address };
            if !ticket_receiver_address.is_zero() {
                let _ = payment_token.transfer_from(caller, ticket_receiver_address, cost.into());
            } else {
                let burnable_token = IERC20BurnableSafeDispatcher {
                    contract_address: payment_token_address,
                };
                let burn_from_result = burnable_token.burn_from(caller, cost.into());

                match burn_from_result {
                    Result::Ok(_) => { // burn_from was successful
                    },
                    Result::Err(_) => {
                        // burn_from failed, fall back to zero address transfer
                        let zero_address: ContractAddress = 0.try_into().unwrap();
                        let _ = payment_token.transfer_from(caller, zero_address, cost.into());
                    },
                }
            }
        }

        fn handle_golden_pass_payment(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            golden_pass_address: ContractAddress,
            golden_pass_token_id: u128,
            current_time: u64,
            to: ContractAddress,
        ) -> Option<u64> {
            // Get the golden pass configuration
            let golden_pass_config = self.golden_passes.read(golden_pass_address);
            assert!(golden_pass_config.cooldown > 0_u64, "Golden pass not configured");

            // Check if the pass is expired
            if golden_pass_config.pass_expiration > 0_u64 {
                assert!(current_time < golden_pass_config.pass_expiration, "Golden pass expired");
            }

            // Check caller owns the golden pass
            let golden_pass = IERC721Dispatcher { contract_address: golden_pass_address };
            assert!(
                golden_pass.owner_of(golden_pass_token_id.into()) == caller,
                "Not owner of golden pass",
            );

            // Check cooldown
            let last_used = self
                .golden_pass_last_used
                .read((golden_pass_address, golden_pass_token_id));

            assert!(
                current_time >= last_used + golden_pass_config.cooldown, "Golden pass on cooldown",
            );

            // Update last used timestamp
            self
                .golden_pass_last_used
                .write((golden_pass_address, golden_pass_token_id), current_time);

            // Calculate expiration based on GameExpiration enum
            ticket_booth::calculate_golden_pass_expiration(
                @golden_pass_config.game_expiration, current_time,
            )
        }

        fn mint_game(
            ref self: ComponentState<TContractState>,
            player_name: Option<felt252>,
            to: ContractAddress,
            soulbound: bool,
            start_time: Option<u64>,
            expiration: Option<u64>,
        ) -> felt252 {
            mint(
                self.denshokan_address.read(),
                self.game_address.read(),
                player_name,
                self.settings_id.read(),
                start_time,
                expiration,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                to,
                soulbound,
                false,
                0,
                0,
            )
        }

        fn assert_before_opening(ref self: ComponentState<TContractState>) {
            assert!(
                get_block_timestamp() < self.opening_time.read(),
                "Cannot update after opening time",
            );
        }

        // Internal functions with business logic - called by contract's ownership-checked functions
        fn update_opening_time_internal(
            ref self: ComponentState<TContractState>, new_opening_time: u64,
        ) {
            self.assert_before_opening();
            self.opening_time.write(new_opening_time);
        }

        fn update_payment_token_internal(
            ref self: ComponentState<TContractState>, new_payment_token: ContractAddress,
        ) {
            self.payment_token.write(new_payment_token);
        }

        fn update_ticket_receiver_address_internal(
            ref self: ComponentState<TContractState>, new_ticket_receiver_address: ContractAddress,
        ) {
            self.ticket_receiver_address.write(new_ticket_receiver_address);
        }

        fn update_cost_to_play_internal(
            ref self: ComponentState<TContractState>, new_cost_to_play: u128,
        ) {
            assert!(new_cost_to_play > 0_u128, "Cost to play must be greater than zero");
            self.cost_to_play.write(new_cost_to_play);
        }

        fn update_settings_id_internal(
            ref self: ComponentState<TContractState>, new_settings_id: Option<u32>,
        ) {
            self.assert_before_opening();
            self.settings_id.write(new_settings_id);
        }
    }
}
