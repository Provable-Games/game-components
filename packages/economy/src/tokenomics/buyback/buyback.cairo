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
        BuybackParams, EpochConfig, GlobalBuybackConfig, MAX_CONFIG_EPOCH, MAX_ORDER_AMOUNT,
        OrderInfo, PackedOrderInfo, TokenBuybackConfig,
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
        /// Number of orders created per sell token
        Buyback_order_counter: Map<ContractAddress, u128>,
        /// Bookmark for claiming (next order to claim) per sell token
        Buyback_order_bookmark: Map<ContractAddress, u128>,
        /// Packed order info: (sell_token, index) -> PackedOrderInfo (single storage slot)
        Buyback_orders: Map<(ContractAddress, u128), PackedOrderInfo>,
        /// Current config epoch per sell token. Advances only when a buy_back
        /// sees a buy_token/fee pair different from the one the current epoch
        /// holds — not per order, and not per config write.
        Buyback_config_epoch: Map<ContractAddress, u8>,
        /// The buy_token/fee pair each (sell_token, epoch) was opened with.
        /// An order names its epoch, so it can always rebuild the exact Ekubo
        /// OrderKey it was created with, whatever the config does afterwards.
        /// A zero `buy_token` means the epoch has never been written: config
        /// validation rejects a zero buy_token, so it cannot occur otherwise.
        Buyback_epoch_config: Map<(ContractAddress, u8), EpochConfig>,
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

            // The order record packs the amount into 120 bits. Rejected here so
            // the error names its cause rather than surfacing from inside the
            // storage packing. ~1.3e18 tokens at 18 decimals, so unreachable for
            // any realistic supply — but a silent truncation would corrupt the
            // stored order and only show up as a failed claim later.
            assert(amount <= MAX_ORDER_AMOUNT, Errors::ORDER_AMOUNT_TOO_LARGE);

            // === Position Handling ===
            let positions_dispatcher = self.Buyback_positions_dispatcher.read();

            // Transfer tokens to positions contract
            sell_token_dispatcher.transfer(positions_dispatcher.contract_address, balance);

            // Resolve which config epoch this order belongs to.
            //
            // The order records WHICH pair it was created under rather than the
            // contract pinning one pair for as long as any order is open. A
            // changed buy_token or fee opens a new epoch; orders already created
            // keep naming the old one and stay claimable with the exact OrderKey
            // they were opened with. This is what unfreezes the config.
            let epoch = self._resolve_epoch(params.sell_token, config.buy_token, config.fee);
            let (active_buy_token, active_fee) = (config.buy_token, config.fee);

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
                epoch,
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

            // Get config once outside the loop (performance optimization)
            let config = self._get_effective_config(sell_token);
            let positions_dispatcher = self.Buyback_positions_dispatcher.read();
            let current_time = get_block_timestamp();

            // Orders resolve their buy_token/fee through their own epoch, so the
            // pair can no longer be hoisted out of the loop. Cache the last one
            // instead: consecutive orders almost always share an epoch, since a
            // new one opens only when the config actually changes.
            let mut cached_epoch: u8 = 0;
            let mut cached_config = EpochConfig { buy_token: Zero::zero(), fee: 0 };

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

                // Build the order key from the config THIS order was created
                // under, not from whatever the config says now.
                if cached_config.buy_token.is_zero() || cached_epoch != packed_order.epoch {
                    cached_epoch = packed_order.epoch;
                    cached_config = self.Buyback_epoch_config.read((sell_token, cached_epoch));
                }
                let order_key = OrderKey {
                    sell_token: sell_token,
                    buy_token: cached_config.buy_token,
                    fee: cached_config.fee,
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

            // Nothing is cleared on a full drain any more. The old code reset
            // the active pair and the position id so that a later order could
            // use a different buy_token/fee — the epoch now does that at any
            // time, with orders still open. Keeping the position id also keeps
            // one Ekubo NFT per sell token for the contract's life: Ekubo keys a
            // sale by (owner, salt, order_key) with salt = the position id, so
            // one NFT holds orders under many different keys at once.

            // Emit event
            self
                .emit(
                    BuybackProceeds {
                        sell_token,
                        buy_token: cached_config.buy_token,
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
        /// `buy_token` and `fee` come from the order's own config epoch, so this
        /// stays correct for historical orders after they are claimed. It used to
        /// read shared state that was zeroed on a full drain, and returned zeros
        /// for exactly the orders a caller was most likely asking about.
        fn get_order_info(
            self: @ComponentState<TContractState>, sell_token: ContractAddress, index: u128,
        ) -> OrderInfo {
            let packed = self.Buyback_orders.read((sell_token, index));
            let epoch_config = self.Buyback_epoch_config.read((sell_token, packed.epoch));
            OrderInfo {
                start_time: packed.start_time,
                end_time: packed.end_time,
                amount: packed.amount,
                buy_token: epoch_config.buy_token,
                fee: epoch_config.fee,
            }
        }

        /// Construct an OrderKey for a specific order index
        ///
        /// Rebuilt from the order's own config epoch, so the key is the one Ekubo
        /// actually holds the sale under and stays usable after the order is
        /// claimed. It previously returned a zero `buy_token` and `fee` once the
        /// queue fully drained, which made it unusable for external Ekubo calls.
        fn get_order_key(
            self: @ComponentState<TContractState>, sell_token: ContractAddress, index: u128,
        ) -> OrderKey {
            let packed = self.Buyback_orders.read((sell_token, index));
            let epoch_config = self.Buyback_epoch_config.read((sell_token, packed.epoch));
            OrderKey {
                sell_token: sell_token,
                buy_token: epoch_config.buy_token,
                fee: epoch_config.fee,
                start_time: packed.start_time,
                end_time: packed.end_time,
            }
        }

        /// Get the current config epoch for a sell token.
        ///
        /// Advances only when a `buy_back` sees a buy_token/fee pair different
        /// from the one the current epoch holds — so it counts CONFIG CHANGES
        /// that reached an order, not orders and not config writes.
        fn get_config_epoch(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> u8 {
            self.Buyback_config_epoch.read(sell_token)
        }

        /// Get the buy token of the CURRENT config epoch for a sell token.
        ///
        /// Latest-only: this is what the next order would use, not a value every
        /// open order is pinned to. Zero before the first order. For a specific
        /// order use `get_order_info` / `get_order_key`.
        fn get_active_buy_token(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> ContractAddress {
            let epoch = self.Buyback_config_epoch.read(sell_token);
            self.Buyback_epoch_config.read((sell_token, epoch)).buy_token
        }

        /// Get the fee of the CURRENT config epoch for a sell token.
        ///
        /// Latest-only, on the same terms as `get_active_buy_token`.
        fn get_active_fee(
            self: @ComponentState<TContractState>, sell_token: ContractAddress,
        ) -> u128 {
            let epoch = self.Buyback_config_epoch.read(sell_token);
            self.Buyback_epoch_config.read((sell_token, epoch)).fee
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

            // buy_back requires minimum_amount <= amount <= MAX_ORDER_AMOUNT, so a
            // minimum above the packing cap is a config no order can ever satisfy.
            // Rejected here rather than leaving that sell token silently unbuyable.
            assert(
                global_config.default_minimum_amount <= MAX_ORDER_AMOUNT,
                Errors::MINIMUM_AMOUNT_UNSATISFIABLE,
            );

            // Store configuration
            self.Buyback_global_config.write(global_config);
            self
                .Buyback_positions_dispatcher
                .write(IPositionsDispatcher { contract_address: positions_address });
            self.Buyback_extension_address.write(extension_address);
        }

        /// Resolve the config epoch a new order belongs to, opening a new one if
        /// the buy_token/fee pair has moved since the last order.
        ///
        /// Three cases, in the order they are checked:
        /// - the current epoch has no config yet (first order for this sell
        ///   token): claim epoch 0 by writing the pair into it;
        /// - the pair is unchanged: reuse the current epoch, writing nothing;
        /// - the pair moved: open the NEXT epoch. The old one is never
        ///   overwritten, because orders already created still resolve through
        ///   it and must keep rebuilding the OrderKey Ekubo holds their sale
        ///   under.
        ///
        /// A zero `buy_token` is the "unwritten" marker. It cannot collide with a
        /// real config: `initializer`, `set_global_config` and `set_token_config`
        /// all reject a zero buy_token.
        fn _resolve_epoch(
            ref self: ComponentState<TContractState>,
            sell_token: ContractAddress,
            buy_token: ContractAddress,
            fee: u128,
        ) -> u8 {
            let current = self.Buyback_config_epoch.read(sell_token);
            let stored = self.Buyback_epoch_config.read((sell_token, current));

            if stored.buy_token.is_zero() {
                self
                    .Buyback_epoch_config
                    .write((sell_token, current), EpochConfig { buy_token, fee });
                return current;
            }

            if stored.buy_token == buy_token && stored.fee == fee {
                return current;
            }

            // Refused rather than wrapped. The epoch is 8 bits in the packed
            // order record, so a 256th config would wrap to 0 and silently
            // reinterpret every epoch-0 order under the newest config — wrong
            // OrderKeys, and proceeds that can no longer be claimed. 255 changes
            // per sell token is far past any real operational need.
            assert(current < MAX_CONFIG_EPOCH, Errors::CONFIG_EPOCHS_EXHAUSTED);

            let next = current + 1;
            self.Buyback_config_epoch.write(sell_token, next);
            self.Buyback_epoch_config.write((sell_token, next), EpochConfig { buy_token, fee });
            next
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

            // Same unsatisfiable-minimum rule as the initializer.
            assert(
                config.default_minimum_amount <= MAX_ORDER_AMOUNT,
                Errors::MINIMUM_AMOUNT_UNSATISFIABLE,
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
                assert(c.minimum_amount <= MAX_ORDER_AMOUNT, Errors::MINIMUM_AMOUNT_UNSATISFIABLE);
            }

            let old_config = self.Buyback_token_config.read(sell_token);
            self.Buyback_token_config.write(sell_token, config);
            self.emit(TokenConfigUpdated { sell_token, old_config, new_config: config });
        }
    }
}
