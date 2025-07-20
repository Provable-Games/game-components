///
/// Ticket Booth Component
/// 
/// A payment-enabled metagame component that charges tokens for game access
///
#[starknet::component]
pub mod TicketBoothComponent {
    use core::num::traits::Zero;
    use crate::libs;

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

    use starknet::contract_address::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{get_caller_address, get_contract_address, get_block_timestamp};

    #[storage]
    pub struct Storage {
        game_address: ContractAddress,
        payment_token: ContractAddress,
        cost_to_play: u128,
        burn_payment: bool,
        settings_id: u32,
        golden_pass_address: ContractAddress,
        golden_pass_cooldown: u64,
        golden_pass_last_used: Map<u256, u64>, // maps token_id to last used timestamp
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
        pub golden_pass_token_id: u256,
    }


    #[starknet::interface]
    pub trait ITicketBooth<TContractState> {
        fn buy_game(
            ref self: TContractState,
            player_name: ByteArray,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64;
        fn use_golden_pass(
            ref self: TContractState,
            golden_pass_token_id: u256,
            player_name: ByteArray,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64;

        fn payment_token(self: @TContractState) -> ContractAddress;
        fn cost_to_play(self: @TContractState) -> u128;
        fn burn_payment(self: @TContractState) -> bool;
        fn settings_id(self: @TContractState) -> u32;
        fn golden_pass_address(self: @TContractState) -> ContractAddress;
        fn golden_pass_cooldown(self: @TContractState) -> u64;
        fn golden_pass_last_used(self: @TContractState, token_id: u256) -> u64;
    }

    #[embeddable_as(TicketBoothImpl)]
    impl TicketBooth<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ITicketBooth<ComponentState<TContractState>> {
        fn buy_game(
            ref self: ComponentState<TContractState>,
            player_name: ByteArray,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            let caller = get_caller_address();           
            let cost = self.cost_to_play.read();
            let payment_token_address = self.payment_token.read();
            
            // Handle payment (redeem the ticket)
            if cost > 0 && !payment_token_address.is_zero() {
                let payment_token = IERC20Dispatcher { contract_address: payment_token_address };
                
                if self.burn_payment.read() {
                    // TODO: Implement burn functionality
                    payment_token.transfer_from(caller, get_contract_address(), cost.into());
                } else {
                    payment_token.transfer_from(caller, get_contract_address(), cost.into());
                }
            }

            // Mint the game token with configured settings
            let token_id = libs::mint(
                self.game_address.read(),
                Option::Some(get_contract_address()),
                Option::Some(player_name),
                Option::Some(self.settings_id.read()),
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                to,
                soulbound,
            );

            // Emit event
            self.emit(TicketRedeemed {
                player: to,
                token_id,
                cost,
            });

            token_id
        }

        fn payment_token(self: @ComponentState<TContractState>) -> ContractAddress {
            self.payment_token.read()
        }

        fn cost_to_play(self: @ComponentState<TContractState>) -> u128 {
            self.cost_to_play.read()
        }

        fn burn_payment(self: @ComponentState<TContractState>) -> bool {
            self.burn_payment.read()
        }

        fn settings_id(self: @ComponentState<TContractState>) -> u32 {
            self.settings_id.read()
        }

        fn use_golden_pass(
            ref self: ComponentState<TContractState>,
            golden_pass_token_id: u256,
            player_name: ByteArray,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            let caller = get_caller_address();
            let golden_pass_address = self.golden_pass_address.read();
            
            // Check golden pass is configured
            assert!(!golden_pass_address.is_zero(), "Golden pass not configured");
            
            // Check caller owns the golden pass
            let golden_pass = IERC721Dispatcher { contract_address: golden_pass_address };
            assert!(golden_pass.owner_of(golden_pass_token_id) == caller, "Not owner of golden pass");
            
            // Check cooldown
            let last_used = self.golden_pass_last_used.read(golden_pass_token_id);
            let current_time = get_block_timestamp();
            let cooldown = self.golden_pass_cooldown.read();
            
            assert!(current_time >= last_used + cooldown, "Golden pass on cooldown");
            
            // Update last used timestamp
            self.golden_pass_last_used.write(golden_pass_token_id, current_time);
            
            // Mint the game token with configured settings and 10-day expiration
            let expiration = current_time + (10 * 24 * 60 * 60); // 10 days in seconds
            let token_id = libs::mint(
                self.game_address.read(),
                Option::Some(get_contract_address()),
                Option::Some(player_name),
                Option::Some(self.settings_id.read()),
                Option::None, // start
                Option::Some(expiration), // end - 10 days from now
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                to,
                soulbound,
            );

            // Emit event
            self.emit(GoldenPassRedeemed {
                player: to,
                token_id,
                golden_pass_token_id,
            });

            token_id
        }

        fn golden_pass_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.golden_pass_address.read()
        }

        fn golden_pass_cooldown(self: @ComponentState<TContractState>) -> u64 {
            self.golden_pass_cooldown.read()
        }

        fn golden_pass_last_used(self: @ComponentState<TContractState>, token_id: u256) -> u64 {
            self.golden_pass_last_used.read(token_id)
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
            game_address: ContractAddress,
            payment_token: ContractAddress,
            cost_to_play: u128,
            burn_payment: bool,
            settings_id: u32,
            golden_pass: Option<(ContractAddress, u64)>, // (address, cooldown)
            grant_approval_to: Option<ContractAddress>,
        ) {
            // Validate required parameters
            assert!(!game_address.is_zero(), "Game address cannot be zero");
            assert!(!payment_token.is_zero(), "Payment token cannot be zero");
            assert!(cost_to_play > 0, "Cost to play must be greater than zero");
            
            self.game_address.write(game_address);
            self.payment_token.write(payment_token);
            self.cost_to_play.write(cost_to_play);
            self.burn_payment.write(burn_payment);
            self.settings_id.write(settings_id);
            
            // Configure golden pass if provided
            match golden_pass {
                Option::Some((address, cooldown)) => {
                    self.golden_pass_address.write(address);
                    self.golden_pass_cooldown.write(cooldown);
                },
                Option::None => {
                    self.golden_pass_address.write(Zero::zero());
                    self.golden_pass_cooldown.write(0);
                },
            };

            // Grant approval if requested (for payment tokens this contract will hold)
            match grant_approval_to {
                Option::Some(operator) => {
                    let payment_token_dispatcher = IERC20Dispatcher { 
                        contract_address: payment_token 
                    };
                    // Approve operator to spend all payment tokens this contract holds
                    payment_token_dispatcher.approve(operator, core::num::traits::Bounded::MAX);
                },
                Option::None => {},
            };
        }
    }
}