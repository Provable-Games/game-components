///
/// Ticket Booth Component
/// 
/// A payment-enabled metagame component that charges tokens for game access
///
#[starknet::component]
pub mod TicketBoothComponent {
    use core::num::traits::Zero;
    use crate::libs;

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
        settings_id: u32,
        golden_passes: Map<ContractAddress, GoldenPass>,
        golden_pass_last_used: Map<(ContractAddress, u256), u64>,
        ticket_receiver_address: Option<ContractAddress>,
    }

    #[derive(Drop, Serde, Clone, starknet::Store)]
    pub struct GoldenPass {
        pub cooldown: u64,
        pub game_expiration: u64,
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
            golden_pass_address: ContractAddress,
            golden_pass_token_id: u256,
            player_name: ByteArray,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64;

        fn payment_token(self: @TContractState) -> ContractAddress;
        fn cost_to_play(self: @TContractState) -> u128;
        fn settings_id(self: @TContractState) -> u32;
        fn get_golden_pass(self: @TContractState, golden_pass_address: ContractAddress) -> Option<GoldenPass>;
        fn golden_pass_last_used(self: @TContractState, golden_pass_address: ContractAddress, token_id: u256) -> u64;
        fn ticket_receiver_address(self: @TContractState) -> Option<ContractAddress>;
    }

    #[embeddable_as(TicketBoothImpl)]
    impl TicketBooth<
        TContractState,
        +HasComponent<TContractState>,
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
            let ticket_receiver_address = self.ticket_receiver_address.read();
            
            // Handle payment (redeem the ticket)
            let payment_token = IERC20Dispatcher { contract_address: payment_token_address };
            match ticket_receiver_address {
                Option::Some(receiver) => {
                    payment_token.transfer_from(caller, receiver, cost.into());
                },
                Option::None => {
                    let zero_address: ContractAddress = 0.try_into().unwrap();
                    payment_token.transfer_from(caller, zero_address, cost.into());
                },
            };

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

        fn settings_id(self: @ComponentState<TContractState>) -> u32 {
            self.settings_id.read()
        }

        fn use_golden_pass(
            ref self: ComponentState<TContractState>,
            golden_pass_address: ContractAddress,
            golden_pass_token_id: u256,
            player_name: ByteArray,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            let caller = get_caller_address();
            
            // Get the golden pass configuration
            let golden_pass_config = self.golden_passes.read(golden_pass_address);
            assert!(golden_pass_config.cooldown > 0, "Golden pass not configured");
            
            // Check caller owns the golden pass
            let golden_pass = IERC721Dispatcher { contract_address: golden_pass_address };
            assert!(golden_pass.owner_of(golden_pass_token_id) == caller, "Not owner of golden pass");
            
            // Check cooldown
            let last_used = self.golden_pass_last_used.read((golden_pass_address, golden_pass_token_id));
            let current_time = get_block_timestamp();
            
            assert!(current_time >= last_used + golden_pass_config.cooldown, "Golden pass on cooldown");
            
            // Update last used timestamp
            self.golden_pass_last_used.write((golden_pass_address, golden_pass_token_id), current_time);
            
            // Mint the game token with configured settings and expiration from config
            let expiration = if golden_pass_config.game_expiration > 0 {
                current_time + golden_pass_config.game_expiration
            } else {
                0 // No expiration
            };
            
            let token_id = libs::mint(
                self.game_address.read(),
                Option::Some(get_contract_address()),
                Option::Some(player_name),
                Option::Some(self.settings_id.read()),
                Option::None, // start
                if expiration > 0 { Option::Some(expiration) } else { Option::None }, // end
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

        fn get_golden_pass(self: @ComponentState<TContractState>, golden_pass_address: ContractAddress) -> Option<GoldenPass> {
            let golden_pass = self.golden_passes.read(golden_pass_address);
            if golden_pass.cooldown > 0 {
                Option::Some(golden_pass)
            } else {
                Option::None
            }
        }

        fn golden_pass_last_used(self: @ComponentState<TContractState>, golden_pass_address: ContractAddress, token_id: u256) -> u64 {
            self.golden_pass_last_used.read((golden_pass_address, token_id))
        }

        fn ticket_receiver_address(self: @ComponentState<TContractState>) -> Option<ContractAddress> {
            self.ticket_receiver_address.read()
        }
    }


    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            payment_token: ContractAddress,
            cost_to_play: u128,
            settings_id: u32,
            golden_passes: Option<Span<(ContractAddress, GoldenPass)>>,
            ticket_receiver_address: Option<ContractAddress>, // address to receive tickets or burn them if none
        ) {
            // Validate required parameters
            assert!(!game_address.is_zero(), "Game address cannot be zero");
            assert!(!payment_token.is_zero(), "Payment token cannot be zero");
            assert!(cost_to_play > 0, "Cost to play must be greater than zero");
            
            self.game_address.write(game_address);
            self.payment_token.write(payment_token);
            self.cost_to_play.write(cost_to_play);
            self.settings_id.write(settings_id);
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
                        self.golden_passes.write(*address, config.clone());
                        i += 1;
                    };
                },
                Option::None => {},
            };
        }
    }
}