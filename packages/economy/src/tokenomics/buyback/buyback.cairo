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
    use game_components_interfaces::tokenomics::buyback::{
        BuybackParams, GlobalBuybackConfig, TokenBuybackConfig,
    };
    use openzeppelin_interfaces::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_contract_address};
    use crate::tokenomics::constants::Errors;

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
        /// Part of the OrderKey. Emitted because this event is now the ONLY
        /// record of the key — without it an order cannot be reconstructed once
        /// the config moves on.
        pub fee: u128,
        pub amount: u128,
        pub start_time: u64,
        pub end_time: u64,
        pub position_id: u64,
    }

    /// Emitted when a single order's proceeds are claimed
    #[derive(Drop, starknet::Event)]
    pub struct BuybackProceeds {
        #[key]
        pub sell_token: ContractAddress,
        #[key]
        pub buy_token: ContractAddress,
        pub treasury: ContractAddress,
        pub amount: u128,
        pub start_time: u64,
        pub end_time: u64,
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
    > of game_components_interfaces::tokenomics::buyback::IBuyback<ComponentState<TContractState>> {
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

            // If the order starts in the future, it must start within max_delay.
            // Enforced UNCONDITIONALLY: max_delay = 0 means "must start
            // immediately" (a future start is then rejected), matching Ekubo's
            // revenue_buybacks convention. An unbounded start_time is a
            // permissionless-DoS vector — a far-future order pins the claim
            // loop behind it — so 0 fails CLOSED here, it does not disable the
            // check.
            if start_time > current_time {
                assert(start_time - current_time <= config.max_delay, Errors::DELAY_TOO_LONG);
            }

            // === End Time Validation ===
            let actual_start = max(current_time, start_time);
            assert(params.end_time > actual_start, Errors::END_TIME_INVALID);

            let duration = params.end_time - actual_start;
            assert(duration >= config.min_duration, Errors::DURATION_TOO_SHORT);
            // Enforced UNCONDITIONALLY (Ekubo convention): an unbounded
            // duration is the second half of the same DoS — a very-long order
            // pins the claim loop just as a far-future start does. max_duration
            // = 0 is rejected at config time (below), so a valid config always
            // has a real ceiling here.
            assert(duration <= config.max_duration, Errors::DURATION_TOO_LONG);

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

            // The OrderKey is built from the CURRENT config every time. Nothing
            // is pinned per sell token: two orders may legitimately differ in
            // fee or buy_token, and Ekubo treats them as the distinct orders
            // they are. That is what keeps the config changeable at any time.
            //
            // NOTE: start_time is params.start_time, not the computed one.
            // Ekubo TWAMM requires timestamps be multiples of 16^n by distance
            // from now; 0 means "start immediately" and always validates.
            let order_key = OrderKey {
                sell_token: params.sell_token,
                buy_token: config.buy_token,
                fee: config.fee,
                start_time: params.start_time,
                end_time: params.end_time,
            };

            let mut position_id = self.Buyback_position_token_id.read(params.sell_token);
            if position_id == 0 {
                let (new_position_id, _sale_rate) = positions_dispatcher
                    .mint_and_increase_sell_amount(order_key, amount);
                position_id = new_position_id;
                self.Buyback_position_token_id.write(params.sell_token, position_id);
            } else {
                // One position NFT holds every order for this sell token,
                // whatever their keys. Ekubo's own revenue_buybacks does the
                // same with a single NFT for everything.
                positions_dispatcher.increase_sell_amount(position_id, order_key, amount);
            }

            // This event is the ONLY record of the order. Every field of the
            // OrderKey must be here or the order cannot be claimed later.
            self
                .emit(
                    BuybackStarted {
                        sell_token: params.sell_token,
                        buy_token: config.buy_token,
                        fee: config.fee,
                        amount,
                        start_time: params.start_time,
                        end_time: params.end_time,
                        position_id,
                    },
                );
        }

        /// Claim proceeds for ONE completed order, identified by its key.
        ///
        /// There is no queue and no bookmark: the caller names the order, so
        /// any matured order can be claimed at any time in any sequence. A long
        /// order can no longer delay a short one created after it.
        ///
        /// The key comes from the `BuybackStarted` event, which emits every
        /// field of it.
        ///
        /// Returns the proceeds withdrawn. 0 is a legitimate result — an order
        /// already claimed, or one that bought nothing — and is deliberately
        /// NOT an error, so a keeper sweeping several keys is not reverted by a
        /// stale one.
        fn claim_order(ref self: ComponentState<TContractState>, order_key: OrderKey) -> u128 {
            self._claim_one(order_key)
        }

        /// `claim_order` over several keys. Returns the total withdrawn.
        ///
        /// Each key is independent, so this is a gas convenience and not a
        /// queue: no key can block another, and the order of the span is
        /// irrelevant.
        fn claim_orders(
            ref self: ComponentState<TContractState>, order_keys: Span<OrderKey>,
        ) -> u128 {
            let mut total: u128 = 0;
            let mut i: u32 = 0;
            while i < order_keys.len() {
                total += self._claim_one(*order_keys.at(i));
                i += 1;
            }
            total
        }

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

            // Scheduling bounds fail CLOSED: max_delay = 0 is a valid value
            // ("must start immediately"), but max_duration = 0 would forbid
            // every order (duration >= min_duration >= 0 and duration <= 0),
            // so it is rejected here to fail loud at config time rather than
            // silently bricking buy_back. min may not exceed max.
            assert(
                global_config.default_min_delay <= global_config.default_max_delay,
                Errors::MIN_DELAY_GT_MAX_DELAY,
            );
            assert(global_config.default_max_duration != 0, Errors::MAX_DURATION_ZERO);
            assert(
                global_config.default_min_duration <= global_config.default_max_duration,
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
        /// Withdraw one order's proceeds to the treasury named by the CURRENT
        /// config for that sell token.
        ///
        /// Rejects an unmatured order, so this is a claim and not an early exit.
        /// Everything else is left to Ekubo: an unknown or already-drained order
        /// yields 0 rather than reverting, which is what makes `claim_orders`
        /// safe to call with a stale key in the batch.
        fn _claim_one(ref self: ComponentState<TContractState>, order_key: OrderKey) -> u128 {
            // Position first: if this token has never traded, that is the more
            // informative failure than "not matured".
            let position_id = self.Buyback_position_token_id.read(order_key.sell_token);
            assert(position_id != 0, Errors::POSITION_NOT_INITIALIZED);

            assert(order_key.end_time <= get_block_timestamp(), Errors::ORDER_NOT_MATURED);

            let config = self._get_effective_config(order_key.sell_token);
            let proceeds = self
                .Buyback_positions_dispatcher
                .read()
                .withdraw_proceeds_from_sale_to(position_id, order_key, config.treasury);

            self
                .emit(
                    BuybackProceeds {
                        sell_token: order_key.sell_token,
                        buy_token: order_key.buy_token,
                        treasury: config.treasury,
                        amount: proceeds,
                        start_time: order_key.start_time,
                        end_time: order_key.end_time,
                    },
                );

            proceeds
        }

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

            // Scheduling bounds fail CLOSED (same rules as the initializer):
            // max_delay = 0 is valid ("must start immediately"); max_duration
            // = 0 is rejected (it would forbid every order); min may not
            // exceed max.
            assert(
                config.default_min_delay <= config.default_max_delay,
                Errors::MIN_DELAY_GT_MAX_DELAY,
            );
            assert(config.default_max_duration != 0, Errors::MAX_DURATION_ZERO);
            assert(
                config.default_min_duration <= config.default_max_duration,
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
                assert(c.min_delay <= c.max_delay, Errors::MIN_DELAY_GT_MAX_DELAY);
                assert(c.max_duration != 0, Errors::MAX_DURATION_ZERO);
                assert(c.min_duration <= c.max_duration, Errors::MIN_DURATION_GT_MAX_DURATION);
            }

            let old_config = self.Buyback_token_config.read(sell_token);
            self.Buyback_token_config.write(sell_token, config);
            self.emit(TokenConfigUpdated { sell_token, old_config, new_config: config });
        }
    }
}
