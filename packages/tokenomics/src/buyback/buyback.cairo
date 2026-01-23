/// Autonomous Buyback Component v2
///
/// A reusable Cairo component that enables permissionless buybacks of any ERC20 token
/// deposited into the contract via Ekubo's TWAMM DCA orders.
///
/// # Features
/// - Permissionless buyback execution: Anyone can trigger buybacks
/// - Per-token configuration: Different settings per sell token with global defaults
/// - Delayed start support: Orders can be scheduled for future execution
/// - Minimum amount threshold: Prevents spam/griefing attacks
/// - Multiple concurrent orders: Supports multiple DCA orders per sell token
/// - Automatic position creation: First buyback creates the Ekubo position per token
/// - Append-only design: No emergency functions, predictable behavior
///
/// # Usage
/// Embed this component in a contract with OwnableComponent for access control.
#[starknet::component]
pub mod BuybackComponent {
    use core::cmp::max;
    use core::num::traits::Zero;
    use ekubo::interfaces::extensions::twamm::OrderKey;
    use ekubo::interfaces::positions::{IPositionsDispatcher, IPositionsDispatcherTrait};
    use openzeppelin_interfaces::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_contract_address};
    use crate::buyback::interface::{
        BuybackParams, GlobalBuybackConfig, OrderInfo, PackedOrderInfo, TokenBuybackConfig,
    };
    use crate::constants::Errors;

    /// Storage for the Buyback component
    /// All storage keys are prefixed with `Buyback_` to avoid collisions
    #[storage]
    pub struct Storage {
        /// Global configuration defaults
        Buyback_global_config: GlobalBuybackConfig,
        /// Ekubo positions contract dispatcher
        Buyback_positions_dispatcher: IPositionsDispatcher,
        /// TWAMM extension address
        Buyback_extension_address: ContractAddress,
        /// Per-token configuration overrides (None = use global defaults)
        Buyback_token_config: Map<ContractAddress, Option<TokenBuybackConfig>>,
        /// Position token ID per sell token (0 if not created)
        Buyback_position_token_id: Map<ContractAddress, u64>,
        /// Number of orders created per sell token
        Buyback_order_counter: Map<ContractAddress, u128>,
        /// Bookmark for claiming (next order to claim) per sell token
        Buyback_order_bookmark: Map<ContractAddress, u128>,
        /// Packed order info: (sell_token, index) -> PackedOrderInfo (single storage slot)
        Buyback_orders: Map<(ContractAddress, u128), PackedOrderInfo>,
        /// Active buy token per sell token (set on first order, immutable while unclaimed orders
        /// exist)
        Buyback_active_buy_token: Map<ContractAddress, ContractAddress>,
        /// Active fee per sell token (set on first order, immutable while unclaimed orders exist)
        Buyback_active_fee: Map<ContractAddress, u128>,
    }

    /// Events emitted by the Buyback component
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BuybackStarted: BuybackStarted,
        BuybackProceeds: BuybackProceeds,
        BuyTokenSwept: BuyTokenSwept,
        GlobalConfigUpdated: GlobalConfigUpdated,
        TokenConfigUpdated: TokenConfigUpdated,
    }

    /// Emitted when a new buyback order is started
    #[derive(Drop, starknet::Event)]
    pub struct BuybackStarted {
        #[key]
        pub sell_token: ContractAddress,
        #[key]
        pub buy_token: ContractAddress,
        pub amount: u128,
        pub start_time: u64,
        pub end_time: u64,
        pub order_index: u128,
        pub position_id: u64,
    }

    /// Emitted when buyback proceeds are claimed
    #[derive(Drop, starknet::Event)]
    pub struct BuybackProceeds {
        #[key]
        pub sell_token: ContractAddress,
        #[key]
        pub buy_token: ContractAddress,
        pub amount: u128,
        pub orders_claimed: u128,
        pub new_bookmark: u128,
    }

    /// Emitted when accumulated buy tokens are swept to treasury
    #[derive(Drop, starknet::Event)]
    pub struct BuyTokenSwept {
        #[key]
        pub buy_token: ContractAddress,
        #[key]
        pub treasury: ContractAddress,
        pub amount: u256,
    }

    /// Emitted when the global configuration is updated
    #[derive(Drop, starknet::Event)]
    pub struct GlobalConfigUpdated {
        pub old_config: GlobalBuybackConfig,
        pub new_config: GlobalBuybackConfig,
    }

    /// Emitted when a per-token configuration is updated
    #[derive(Drop, starknet::Event)]
    pub struct TokenConfigUpdated {
        #[key]
        pub sell_token: ContractAddress,
        pub old_config: Option<TokenBuybackConfig>,
        pub new_config: Option<TokenBuybackConfig>,
    }

    /// External implementation of IBuyback
    /// Uses `#[embeddable_as]` to allow embedding in contracts
    #[embeddable_as(BuybackImpl)]
    impl Buyback<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of crate::buyback::interface::IBuyback<ComponentState<TContractState>> {
        /// Execute a buyback using all tokens of `sell_token` in the contract
        fn buy_back(ref self: ComponentState<TContractState>, params: BuybackParams) {
            let config = self._get_effective_config(params.sell_token);
            let current_time = get_block_timestamp();
            let zero_address: ContractAddress = Zero::zero();

            // === Sell Token Validation ===
            assert(params.sell_token != zero_address, Errors::INVALID_SELL_TOKEN);
            assert(params.sell_token != config.buy_token, Errors::SELL_TOKEN_IS_BUY_TOKEN);

            // === Start Time Validation ===
            let start_time = if params.start_time == 0 {
                current_time
            } else {
                params.start_time
            };

            // If min_delay is set, order must start in the future with sufficient delay
            if config.min_delay > 0 {
                assert(start_time > current_time, Errors::START_TIME_TOO_SOON);
                assert(start_time - current_time >= config.min_delay, Errors::DELAY_TOO_SHORT);
            }

            // If start is in the future and max_delay is set, enforce maximum delay
            if start_time > current_time && config.max_delay > 0 {
                assert(start_time - current_time <= config.max_delay, Errors::DELAY_TOO_LONG);
            }

            // === End Time Validation ===
            let actual_start = max(current_time, start_time);
            assert(params.end_time > actual_start, Errors::END_TIME_INVALID);

            let duration = params.end_time - actual_start;
            assert(duration >= config.min_duration, Errors::DURATION_TOO_SHORT);
            // max_duration == 0 means no maximum limit (consistent with max_delay behavior)
            if config.max_duration > 0 {
                assert(duration <= config.max_duration, Errors::DURATION_TOO_LONG);
            }

            // === Amount Handling (always full balance, with minimum threshold) ===
            let sell_token_dispatcher = IERC20Dispatcher { contract_address: params.sell_token };
            let this_address = get_contract_address();
            let balance: u256 = sell_token_dispatcher.balance_of(this_address);
            assert(balance > 0, Errors::NO_BALANCE_TO_BUYBACK);

            let amount: u128 = balance.try_into().expect(Errors::BALANCE_OVERFLOW);
            assert(amount >= config.minimum_amount, Errors::AMOUNT_BELOW_MINIMUM);

            // === Position Handling ===
            let positions_dispatcher = self.Buyback_positions_dispatcher.read();

            // Transfer tokens to positions contract
            sell_token_dispatcher.transfer(positions_dispatcher.contract_address, balance);

            // Get or set active buy_token and fee for this sell_token
            // These are immutable while unclaimed orders exist to ensure OrderKey consistency
            let stored_buy_token = self.Buyback_active_buy_token.read(params.sell_token);
            let (active_buy_token, active_fee) = if stored_buy_token.is_zero() {
                // First order for this sell_token - store the buy_token and fee
                self.Buyback_active_buy_token.write(params.sell_token, config.buy_token);
                self.Buyback_active_fee.write(params.sell_token, config.fee);
                (config.buy_token, config.fee)
            } else {
                // Subsequent order - must use same buy_token and fee for OrderKey consistency
                let stored_fee = self.Buyback_active_fee.read(params.sell_token);
                assert(stored_buy_token == config.buy_token, Errors::BUY_TOKEN_MISMATCH);
                assert(stored_fee == config.fee, Errors::FEE_MISMATCH);
                (stored_buy_token, stored_fee)
            };

            // Create order key
            // Note: Use params.start_time (not computed start_time) because Ekubo TWAMM
            // has strict time validation rules. start_time=0 means "start immediately"
            // which always works, whereas an arbitrary current_time may not satisfy
            // Ekubo's is_time_valid() requirements (timestamps must be multiples of
            // 16^n based on distance from now).
            let order_key = OrderKey {
                sell_token: params.sell_token,
                buy_token: active_buy_token,
                fee: active_fee,
                start_time: params.start_time,
                end_time: params.end_time,
            };

            let mut position_id = self.Buyback_position_token_id.read(params.sell_token);
            if position_id == 0 {
                // First buyback for this token - mint new position
                let (new_position_id, _sale_rate) = positions_dispatcher
                    .mint_and_increase_sell_amount(order_key, amount);
                position_id = new_position_id;
                self.Buyback_position_token_id.write(params.sell_token, position_id);
            } else {
                // Existing position - just increase sell amount
                positions_dispatcher.increase_sell_amount(position_id, order_key, amount);
            }

            // === Store Packed Order Info (single storage slot) ===
            let order_index = self.Buyback_order_counter.read(params.sell_token);
            let packed_order = PackedOrderInfo {
                start_time: params.start_time, // Store raw params.start_time for OrderKey
                // reconstruction
                end_time: params.end_time,
                amount: amount,
            };
            self.Buyback_orders.write((params.sell_token, order_index), packed_order);
            self.Buyback_order_counter.write(params.sell_token, order_index + 1);

            // Emit event
            self
                .emit(
                    BuybackStarted {
                        sell_token: params.sell_token,
                        buy_token: active_buy_token,
                        amount,
                        start_time: params.start_time,
                        end_time: params.end_time,
                        order_index,
                        position_id,
                    },
                );
        }

        /// Claim proceeds from completed buyback orders
        fn claim_buyback_proceeds(
            ref self: ComponentState<TContractState>, sell_token: ContractAddress, limit: u16,
        ) -> u128 {
            let position_id = self.Buyback_position_token_id.read(sell_token);
            assert(position_id != 0, Errors::POSITION_NOT_INITIALIZED);

            let order_count = self.Buyback_order_counter.read(sell_token);
            let starting_bookmark = self.Buyback_order_bookmark.read(sell_token);

            // Fail fast: no NOOP claims allowed
            assert(starting_bookmark < order_count, Errors::NO_ORDERS_TO_CLAIM);

            // Calculate max index to process
            let max_index = if limit == 0 {
                order_count
            } else {
                let candidate = starting_bookmark + limit.into();
                if candidate < order_count {
                    candidate
                } else {
                    order_count
                }
            };

            // Get config and active parameters once outside the loop (performance optimization)
            let config = self._get_effective_config(sell_token);
            let active_buy_token = self.Buyback_active_buy_token.read(sell_token);
            let active_fee = self.Buyback_active_fee.read(sell_token);
            let positions_dispatcher = self.Buyback_positions_dispatcher.read();
            let current_time = get_block_timestamp();

            let mut order_number = starting_bookmark;
            let mut total_proceeds: u128 = 0;

            // Iterate through orders and claim completed ones
            while order_number < max_index {
                let packed_order = self.Buyback_orders.read((sell_token, order_number));

                // Only claim if order has ended
                if packed_order.end_time > current_time {
                    // Orders are created sequentially, so we can break here
                    break;
                }

                // Build order key using stored active buy_token and fee
                let order_key = OrderKey {
                    sell_token: sell_token,
                    buy_token: active_buy_token,
                    fee: active_fee,
                    start_time: packed_order.start_time,
                    end_time: packed_order.end_time,
                };

                // Withdraw proceeds to treasury.
                // NOTE: This intentionally uses the *current* config.treasury rather than
                // storing a treasury address per order. If the treasury config is changed after
                // orders are created but before they are claimed, proceeds from those existing
                // orders will be sent to the new treasury address. This is a design choice to
                // avoid per-order treasury storage; integrators should be aware of this behavior.
                let proceeds = positions_dispatcher
                    .withdraw_proceeds_from_sale_to(position_id, order_key, config.treasury);

                total_proceeds += proceeds;
                order_number += 1;
            }

            // Fail if no orders were actually completed
            assert(order_number > starting_bookmark, Errors::NO_COMPLETED_ORDERS);

            // Update bookmark
            self.Buyback_order_bookmark.write(sell_token, order_number);

            // If all orders have been claimed, clear active buy_token, fee, and position_id
            // This allows config changes for future orders and ensures a new position is minted
            // for the potentially different buy_token/fee combination
            if order_number == order_count {
                let zero_address: ContractAddress = Zero::zero();
                self.Buyback_active_buy_token.write(sell_token, zero_address);
                self.Buyback_active_fee.write(sell_token, 0);
                self.Buyback_position_token_id.write(sell_token, 0);
            }

            // Emit event
            self
                .emit(
                    BuybackProceeds {
                        sell_token,
                        buy_token: active_buy_token,
                        amount: total_proceeds,
                        orders_claimed: order_number - starting_bookmark,
                        new_bookmark: order_number,
                    },
                );

            total_proceeds
        }

        /// Sweep any accumulated buy tokens directly to treasury
        ///
        /// NOTE: This only sweeps `default_buy_token` from the global config. If per-token
        /// configs specify different buy_tokens, those tokens will NOT be swept by this
        /// function. Integrators using different buy_tokens per sell_token should implement
        /// their own sweep mechanism or ensure all configs use the same buy_token.
        fn sweep_buy_token_to_treasury(ref self: ComponentState<TContractState>) -> u256 {
            let global_config = self.Buyback_global_config.read();
            let buy_token = global_config.default_buy_token;
            let treasury = global_config.default_treasury;

            let buy_token_dispatcher = IERC20Dispatcher { contract_address: buy_token };
            let balance = buy_token_dispatcher.balance_of(get_contract_address());

            assert(balance > 0, Errors::NO_BUY_TOKEN_TO_SWEEP);

            buy_token_dispatcher.transfer(treasury, balance);

            self.emit(BuyTokenSwept { buy_token, treasury, amount: balance });

            balance
        }

        /// Get the global configuration defaults
        fn get_global_config(self: @ComponentState<TContractState>) -> GlobalBuybackConfig {
            self.Buyback_global_config.read()
        }

        /// Get the per-token configuration (None if not set)
        fn get_token_config(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> Option<TokenBuybackConfig> {
            self.Buyback_token_config.read(sell_token)
        }

        /// Get the effective configuration for a sell token
        fn get_effective_config(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> TokenBuybackConfig {
            self._get_effective_config(sell_token)
        }

        /// Get the Ekubo positions contract address
        fn get_positions_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Buyback_positions_dispatcher.read().contract_address
        }

        /// Get the TWAMM extension address
        fn get_extension_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Buyback_extension_address.read()
        }

        /// Get the position token ID for a sell token
        fn get_position_token_id(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> u64 {
            self.Buyback_position_token_id.read(sell_token)
        }

        /// Get the number of orders created for a sell token
        fn get_order_count(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> u128 {
            self.Buyback_order_counter.read(sell_token)
        }

        /// Get the bookmark for a sell token
        fn get_order_bookmark(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> u128 {
            self.Buyback_order_bookmark.read(sell_token)
        }

        /// Get the number of unclaimed orders
        fn get_unclaimed_orders_count(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> u128 {
            let counter = self.Buyback_order_counter.read(sell_token);
            let bookmark = self.Buyback_order_bookmark.read(sell_token);
            counter - bookmark
        }

        /// Get information about a specific order
        ///
        /// NOTE: The `buy_token` and `fee` fields are read from `active_buy_token` and
        /// `active_fee` storage, which are cleared when all orders are claimed. After all
        /// orders for a sell_token are claimed, this function will return zero values for
        /// `buy_token` and `fee` even for historical orders. Retrieve order info before
        /// claiming the final order if historical data is needed.
        fn get_order_info(
            self: @ComponentState<TContractState>, sell_token: ContractAddress, index: u128,
        ) -> OrderInfo {
            let packed = self.Buyback_orders.read((sell_token, index));
            let buy_token = self.Buyback_active_buy_token.read(sell_token);
            let fee = self.Buyback_active_fee.read(sell_token);
            OrderInfo {
                start_time: packed.start_time,
                end_time: packed.end_time,
                amount: packed.amount,
                buy_token,
                fee,
            }
        }

        /// Construct an OrderKey for a specific order index
        ///
        /// NOTE: The `buy_token` and `fee` fields are read from `active_buy_token` and
        /// `active_fee` storage, which are cleared when all orders are claimed. After all
        /// orders for a sell_token are claimed, this function will return an invalid OrderKey
        /// with zero `buy_token` and `fee`. Retrieve order keys before claiming the final
        /// order if needed for external Ekubo interactions.
        fn get_order_key(
            self: @ComponentState<TContractState>, sell_token: ContractAddress, index: u128,
        ) -> OrderKey {
            let packed = self.Buyback_orders.read((sell_token, index));
            let buy_token = self.Buyback_active_buy_token.read(sell_token);
            let fee = self.Buyback_active_fee.read(sell_token);
            OrderKey {
                sell_token: sell_token,
                buy_token,
                fee,
                start_time: packed.start_time,
                end_time: packed.end_time,
            }
        }

        /// Get the active buy token for a sell token (set on first order)
        fn get_active_buy_token(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> ContractAddress {
            self.Buyback_active_buy_token.read(sell_token)
        }

        /// Get the active fee for a sell token (set on first order)
        fn get_active_fee(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> u128 {
            self.Buyback_active_fee.read(sell_token)
        }
    }

    /// Internal implementation with helper functions
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initialize the component with required parameters
        ///
        /// # Arguments
        /// * `global_config` - Global configuration defaults
        /// * `positions_address` - Ekubo positions contract address
        /// * `extension_address` - TWAMM extension address
        fn initializer(
            ref self: ComponentState<TContractState>,
            global_config: GlobalBuybackConfig,
            positions_address: ContractAddress,
            extension_address: ContractAddress,
        ) {
            // Validate addresses
            let zero_address: ContractAddress = Zero::zero();
            assert(global_config.default_buy_token != zero_address, Errors::INVALID_BUY_TOKEN);
            assert(global_config.default_treasury != zero_address, Errors::INVALID_TREASURY);
            assert(positions_address != zero_address, Errors::INVALID_POSITIONS_ADDRESS);
            assert(extension_address != zero_address, Errors::INVALID_EXTENSION_ADDRESS);

            // Validate delay/duration consistency (0 = no limit, so only validate when both are
            // set)
            assert(
                global_config.default_min_delay <= global_config.default_max_delay
                    || global_config.default_max_delay == 0,
                Errors::MIN_DELAY_GT_MAX_DELAY,
            );
            assert(
                global_config.default_min_duration <= global_config.default_max_duration
                    || global_config.default_max_duration == 0,
                Errors::MIN_DURATION_GT_MAX_DURATION,
            );

            // Store configuration
            self.Buyback_global_config.write(global_config);
            self
                .Buyback_positions_dispatcher
                .write(IPositionsDispatcher { contract_address: positions_address });
            self.Buyback_extension_address.write(extension_address);
        }

        /// Get the effective configuration for a sell token
        /// Returns the per-token config if set, otherwise builds from global defaults
        fn _get_effective_config(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> TokenBuybackConfig {
            match self.Buyback_token_config.read(sell_token) {
                Option::Some(config) => config,
                Option::None => {
                    // Build default config from global settings
                    let global = self.Buyback_global_config.read();
                    TokenBuybackConfig {
                        buy_token: global.default_buy_token,
                        treasury: global.default_treasury,
                        minimum_amount: global.default_minimum_amount,
                        min_delay: global.default_min_delay,
                        max_delay: global.default_max_delay,
                        min_duration: global.default_min_duration,
                        max_duration: global.default_max_duration,
                        fee: global.default_fee,
                    }
                },
            }
        }

        /// Set the global configuration (internal - should be protected by embedding contract)
        fn set_global_config(
            ref self: ComponentState<TContractState>, config: GlobalBuybackConfig,
        ) {
            let zero_address: ContractAddress = Zero::zero();
            assert(config.default_buy_token != zero_address, Errors::INVALID_BUY_TOKEN);
            assert(config.default_treasury != zero_address, Errors::INVALID_TREASURY);

            // Validate delay/duration consistency (0 = no limit, so only validate when both are
            // set)
            assert(
                config.default_min_delay <= config.default_max_delay
                    || config.default_max_delay == 0,
                Errors::MIN_DELAY_GT_MAX_DELAY,
            );
            assert(
                config.default_min_duration <= config.default_max_duration
                    || config.default_max_duration == 0,
                Errors::MIN_DURATION_GT_MAX_DURATION,
            );

            let old_config = self.Buyback_global_config.read();
            self.Buyback_global_config.write(config);
            self.emit(GlobalConfigUpdated { old_config, new_config: config });
        }

        /// Set or clear per-token configuration (internal - should be protected by embedding
        /// contract)
        fn set_token_config(
            ref self: ComponentState<TContractState>,
            sell_token: ContractAddress,
            config: Option<TokenBuybackConfig>,
        ) {
            // Validate config if provided
            if let Option::Some(c) = config {
                let zero_address: ContractAddress = Zero::zero();
                assert(c.buy_token != zero_address, Errors::INVALID_BUY_TOKEN);
                assert(c.treasury != zero_address, Errors::INVALID_TREASURY);
                assert(
                    c.min_delay <= c.max_delay || c.max_delay == 0, Errors::MIN_DELAY_GT_MAX_DELAY,
                );
                assert(
                    c.min_duration <= c.max_duration || c.max_duration == 0,
                    Errors::MIN_DURATION_GT_MAX_DURATION,
                );
            }

            let old_config = self.Buyback_token_config.read(sell_token);
            self.Buyback_token_config.write(sell_token, config);
            self.emit(TokenConfigUpdated { sell_token, old_config, new_config: config });
        }
    }
}
