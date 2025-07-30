///
/// Ticket Booth Component
///
/// A payment-enabled metagame component that charges tokens for game access
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
    use core::num::traits::Zero;
    use core::byte_array::ByteArray;
    use crate::libs;
    use openzeppelin_token::erc20::interface::{IERC20SafeDispatcher, IERC20SafeDispatcherTrait};
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

    use starknet::contract_address::ContractAddress;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StorageMapReadAccess,
        StorageMapWriteAccess,
    };
    use starknet::{get_caller_address, get_block_timestamp};

    #[starknet::interface]
    trait IERC20Burnable<TContractState> {
        fn burn(ref self: TContractState, amount: u256);
        fn burn_from(ref self: TContractState, account: ContractAddress, amount: u256);
    }

    #[storage]
    pub struct Storage {
        opening_time: u64,
        game_token_address: ContractAddress,
        game_address: ContractAddress,
        payment_token: ContractAddress,
        cost_to_play: u128,
        ticket_receiver_address: ContractAddress,
        settings_id: Option<u32>,
        start_time: Option<u64>,
        expiration_time: Option<u64>, // 0 means no expiration
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        golden_passes: Map<ContractAddress, GoldenPass>,
        golden_pass_last_used: Map<(ContractAddress, u128), u64>,
    }

    #[derive(Drop, Serde, Clone, starknet::Store)]
    #[allow(starknet::store_no_default_variant)]
    pub enum GameExpiration {
        Fixed: u64,
        Dynamic: u64,
    }

    #[derive(Drop, Serde, Clone, starknet::Store)]
    pub struct GoldenPass {
        pub cooldown: u64, // Duration after which the pass can be used again, must be greater than 0
        pub game_expiration: GameExpiration, // Duration after which games minted with this pass expires
        pub pass_expiration: u64, // timestamp when the pass expires (becoming unusable), 0 means no expiration
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TicketRedeemed: TicketRedeemed,
        GoldenPassRedeemed: GoldenPassRedeemed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TicketRedeemed {
        #[key]
        pub player: ContractAddress,
        pub token_id: u64,
        pub cost: u128,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GoldenPassRedeemed {
        #[key]
        pub player: ContractAddress,
        pub token_id: u64,
        pub golden_pass_token_id: u128,
    }

    #[starknet::interface]
    pub trait ITicketBooth<TContractState> {
        fn buy_game(
            ref self: TContractState, player_name: ByteArray, to: ContractAddress, soulbound: bool,
        ) -> u64;
        fn use_golden_pass(
            ref self: TContractState,
            golden_pass_address: ContractAddress,
            golden_pass_token_id: u128,
            player_name: ByteArray,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64;

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
        fn ticket_receiver_address(self: @TContractState) -> ContractAddress;
        fn opening_time(self: @TContractState) -> u64;
    }

    #[embeddable_as(TicketBoothImpl)]
    impl TicketBooth<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of ITicketBooth<ComponentState<TContractState>> {
        fn buy_game(
            ref self: ComponentState<TContractState>,
            player_name: ByteArray,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            assert!(get_block_timestamp() >= self.opening_time.read(), "Game not open yet");

            let caller = get_caller_address();
            let cost = self.cost_to_play.read();
            let payment_token_address = self.payment_token.read();
            let ticket_receiver_address = self.ticket_receiver_address.read();

            // Handle payment (redeem the ticket)
            let payment_token = IERC20SafeDispatcher { contract_address: payment_token_address };
            if !ticket_receiver_address.is_zero() {
                let _ = payment_token.transfer_from(caller, ticket_receiver_address, cost.into());
            } else {
                // Try to burn tokens first using burn_from (most common)
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

            // Calculate expiration by adding expiration_time to current_time
            let current_time = get_block_timestamp();
            let expiration = match self.expiration_time.read() {
                Option::Some(duration) => Option::Some(current_time + duration),
                Option::None => Option::None,
            };

            // Mint the game token with configured settings
            let token_id = libs::mint(
                self.game_token_address.read(),
                Option::Some(self.game_address.read()),
                Option::Some(player_name),
                self.settings_id.read(),
                self.start_time.read(),
                expiration,
                Option::None,
                Option::None,
                self.client_url.read(),
                self.renderer_address.read(),
                to,
                soulbound,
            );

            // Emit event
            self.emit(TicketRedeemed { player: to, token_id, cost });

            token_id
        }

        fn use_golden_pass(
            ref self: ComponentState<TContractState>,
            golden_pass_address: ContractAddress,
            golden_pass_token_id: u128,
            player_name: ByteArray,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            assert!(get_block_timestamp() >= self.opening_time.read(), "Game not open yet");

            let caller = get_caller_address();

            // Get the golden pass configuration
            let golden_pass_config = self.golden_passes.read(golden_pass_address);
            assert!(golden_pass_config.cooldown > 0_u64, "Golden pass not configured");

            // Check if the pass is expired
            let current_time = get_block_timestamp();
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
            let current_time = get_block_timestamp();

            assert!(
                current_time >= last_used + golden_pass_config.cooldown, "Golden pass on cooldown",
            );

            // Update last used timestamp
            self
                .golden_pass_last_used
                .write((golden_pass_address, golden_pass_token_id), current_time);

            // Calculate expiration based on GameExpiration enum
            let expiration = match golden_pass_config.game_expiration {
                GameExpiration::Fixed(expiration_time) => {
                    // Fixed expiration: set to the exact timestamp
                    Option::Some(expiration_time)
                },
                GameExpiration::Dynamic(duration) => {
                    // Dynamic expiration: add duration to current_time
                    Option::Some(current_time + duration)
                },
            };

            let token_id = libs::mint(
                self.game_token_address.read(),
                Option::Some(self.game_address.read()),
                Option::Some(player_name),
                self.settings_id.read(),
                self.start_time.read(),
                expiration,
                Option::None,
                Option::None,
                self.client_url.read(),
                self.renderer_address.read(),
                to,
                soulbound,
            );

            // Emit event
            self.emit(GoldenPassRedeemed { player: to, token_id, golden_pass_token_id });

            token_id
        }


        fn get_golden_pass(
            self: @ComponentState<TContractState>, golden_pass_address: ContractAddress,
        ) -> Option<GoldenPass> {
            let golden_pass = self.golden_passes.read(golden_pass_address);
            if golden_pass.cooldown > 0_u64 {
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
            assert!(!game_token_address.is_zero(), "Game token address cannot be zero");
            assert!(!payment_token.is_zero(), "Payment token cannot be zero");
            assert!(cost_to_play > 0_u128, "Cost to play must be greater than zero");

            self.opening_time.write(opening_time);
            self.game_token_address.write(game_token_address);
            self.payment_token.write(payment_token);
            self.cost_to_play.write(cost_to_play);
            match game_address {
                Option::Some(addr) => self.game_address.write(addr),
                Option::None => self.game_address.write(0.try_into().unwrap()),
            };
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
                        assert!(*config.cooldown > 0_u64, "Golden pass cooldown must be greater than zero");
                        self.golden_passes.write(*address, config.clone());
                        i += 1;
                    };
                },
                Option::None => {},
            };
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
            self.assert_before_opening();
            assert!(!new_payment_token.is_zero(), "Payment token cannot be zero address");
            self.payment_token.write(new_payment_token);
        }

        fn update_ticket_receiver_address_internal(
            ref self: ComponentState<TContractState>, new_ticket_receiver_address: ContractAddress,
        ) {
            self.assert_before_opening();
            self.ticket_receiver_address.write(new_ticket_receiver_address);
        }

        fn update_settings_id_internal(
            ref self: ComponentState<TContractState>, new_settings_id: Option<u32>,
        ) {
            self.assert_before_opening();
            self.settings_id.write(new_settings_id);
        }

        fn update_cost_to_play_internal(
            ref self: ComponentState<TContractState>, new_cost_to_play: u128,
        ) {
            self.assert_before_opening();
            assert!(new_cost_to_play > 0_u128, "Cost to play must be greater than zero");
            self.cost_to_play.write(new_cost_to_play);
        }
    }
}
