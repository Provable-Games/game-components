/// Stream Token Component
///
/// A reusable Cairo component that enables autonomous ERC20 token distribution
/// via Ekubo's TWAMM (Time-Weighted Average Market Maker).
///
/// # Features
/// - Multiple concurrent distribution orders
/// - Per-order proceeds recipients
/// - Permissionless proceeds claiming
/// - Factory-controlled initialization
#[starknet::component]
pub mod StreamComponent {
    use ERC20Component::InternalTrait as ERC20InternalTrait;
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::num::traits::Zero;
    use core::poseidon::PoseidonTrait;
    use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
    use ekubo::interfaces::erc20::IERC20Dispatcher as EkuboIERC20Dispatcher;
    use ekubo::interfaces::extensions::twamm::OrderKey;
    use ekubo::interfaces::positions::{IPositionsDispatcher, IPositionsDispatcherTrait};
    use ekubo::lens::token_registry::{ITokenRegistryDispatcher, ITokenRegistryDispatcherTrait};
    use ekubo::types::i129::i129;
    use ekubo::types::keys::PoolKey;
    use openzeppelin_token::erc20::ERC20Component;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::constants::{Errors, TWAMM_BOUNDS, TWAMM_TICK_SPACING};
    use crate::stream::interface::{DistributionOrder, LiquidityConfig, StoredDistributionOrder};

    /// Storage for the Stream component
    /// All storage keys are prefixed with `Stream_` to avoid collisions
    #[storage]
    pub struct Storage {
        /// Factory address that deployed this token
        Stream_factory: ContractAddress,
        /// Ekubo positions contract dispatcher
        Stream_positions_dispatcher: IPositionsDispatcher,
        /// Ekubo core contract dispatcher
        Stream_core_dispatcher: ICoreDispatcher,
        /// Ekubo token registry dispatcher
        Stream_registry_dispatcher: ITokenRegistryDispatcher,
        /// TWAMM extension address
        Stream_extension_address: ContractAddress,
        /// Primary pool configuration (for liquidity)
        Stream_primary_paired_token: ContractAddress,
        Stream_primary_fee: u128,
        Stream_primary_initial_tick: i129,
        Stream_primary_stream_token_amount: u128,
        Stream_primary_paired_token_amount: u128,
        Stream_primary_min_liquidity: u128,
        /// Liquidity position ID
        Stream_liquidity_position_id: u64,
        /// Primary pool ID
        Stream_pool_id: u256,
        /// Distribution orders
        Stream_order_count: u32,
        Stream_orders: Map<u32, StoredDistributionOrder>,
        /// Position tracking: (buy_token, fee) -> position_id
        Stream_position_ids: Map<(ContractAddress, u128), u64>,
        /// Deployment state: 0=constructed, 1=liquidity_provided, 2=distributions_started
        Stream_deployment_state: u8,
    }

    /// Events emitted by the Stream component
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PoolInitialized: PoolInitialized,
        LiquidityProvided: LiquidityProvided,
        DistributionStarted: DistributionStarted,
        ProceedsClaimed: ProceedsClaimed,
    }

    /// Emitted when a pool is initialized
    #[derive(Drop, starknet::Event)]
    pub struct PoolInitialized {
        #[key]
        pub pool_key_hash: felt252,
        pub pool_id: u256,
    }

    /// Emitted when liquidity is provided
    #[derive(Drop, starknet::Event)]
    pub struct LiquidityProvided {
        pub position_id: u64,
        pub liquidity: u128,
        pub token0_amount: u256,
        pub token1_amount: u256,
    }

    /// Emitted when a distribution order starts
    #[derive(Drop, starknet::Event)]
    pub struct DistributionStarted {
        #[key]
        pub order_index: u32,
        pub buy_token: ContractAddress,
        pub amount: u128,
        pub end_time: u64,
        pub proceeds_recipient: ContractAddress,
        pub position_id: u64,
        pub sale_rate: u128,
    }

    /// Emitted when proceeds are claimed
    #[derive(Drop, starknet::Event)]
    pub struct ProceedsClaimed {
        #[key]
        pub order_index: u32,
        pub amount: u128,
        pub recipient: ContractAddress,
    }

    /// External implementation of IStreamToken
    #[embeddable_as(StreamImpl)]
    impl Stream<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
    > of crate::stream::interface::IStreamToken<ComponentState<TContractState>> {
        fn burn(ref self: ComponentState<TContractState>, amount: u256) {
            let mut contract = self.get_contract_mut();
            let mut erc20_component = ERC20::get_component_mut(ref contract);
            let caller = get_caller_address();
            erc20_component.burn(caller, amount);
        }

        fn burn_from(
            ref self: ComponentState<TContractState>, account: ContractAddress, amount: u256,
        ) {
            let mut contract = self.get_contract_mut();
            let mut erc20_component = ERC20::get_component_mut(ref contract);
            let caller = get_caller_address();
            erc20_component._spend_allowance(account, caller, amount);
            erc20_component.burn(account, amount);
        }

        fn claim_distribution_proceeds(
            ref self: ComponentState<TContractState>, order_index: u32,
        ) -> u128 {
            assert(
                self.Stream_deployment_state.read() == 2, Errors::STREAM_DISTRIBUTIONS_NOT_STARTED,
            );
            assert(
                order_index < self.Stream_order_count.read(), Errors::STREAM_INVALID_ORDER_INDEX,
            );

            let order = self.Stream_orders.read(order_index);
            let position_id = self.Stream_position_ids.read((order.buy_token, order.fee));
            assert(position_id != 0, Errors::STREAM_POSITION_NOT_FOUND);

            // Build order key
            let order_key = self._build_order_key(@order);

            // Claim proceeds to recipient
            let positions_dispatcher = self.Stream_positions_dispatcher.read();
            let proceeds = positions_dispatcher
                .withdraw_proceeds_from_sale_to(position_id, order_key, order.proceeds_recipient);

            self
                .emit(
                    ProceedsClaimed {
                        order_index, amount: proceeds, recipient: order.proceeds_recipient,
                    },
                );

            proceeds
        }

        fn get_order_count(self: @ComponentState<TContractState>) -> u32 {
            self.Stream_order_count.read()
        }

        fn get_order(
            self: @ComponentState<TContractState>, order_index: u32,
        ) -> StoredDistributionOrder {
            assert(
                order_index < self.Stream_order_count.read(), Errors::STREAM_INVALID_ORDER_INDEX,
            );
            self.Stream_orders.read(order_index)
        }

        fn get_position_id(
            self: @ComponentState<TContractState>, buy_token: ContractAddress, fee: u128,
        ) -> u64 {
            self.Stream_position_ids.read((buy_token, fee))
        }

        fn get_order_key(self: @ComponentState<TContractState>, order_index: u32) -> OrderKey {
            assert(
                order_index < self.Stream_order_count.read(), Errors::STREAM_INVALID_ORDER_INDEX,
            );
            let order = self.Stream_orders.read(order_index);
            self._build_order_key(@order)
        }

        fn is_initialized(self: @ComponentState<TContractState>) -> bool {
            self.Stream_deployment_state.read() == 2
        }

        fn get_positions_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Stream_positions_dispatcher.read().contract_address
        }

        fn get_core_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Stream_core_dispatcher.read().contract_address
        }

        fn get_extension_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Stream_extension_address.read()
        }

        fn get_liquidity_position_id(self: @ComponentState<TContractState>) -> u64 {
            self.Stream_liquidity_position_id.read()
        }

        fn get_pool_id(self: @ComponentState<TContractState>) -> u256 {
            self.Stream_pool_id.read()
        }

        fn get_deployment_state(self: @ComponentState<TContractState>) -> u8 {
            self.Stream_deployment_state.read()
        }
    }

    /// Factory-only setup implementation
    #[embeddable_as(StreamSetupImpl)]
    impl StreamSetup<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
    > of crate::stream::interface::IStreamTokenSetup<ComponentState<TContractState>> {
        fn provide_initial_liquidity(
            ref self: ComponentState<TContractState>,
        ) -> (u64, u128, u256, u256) {
            // Only factory can call this
            self._assert_only_factory();
            assert(self.Stream_deployment_state.read() == 0, Errors::STREAM_ALREADY_INITIALIZED);

            let positions_dispatcher = self.Stream_positions_dispatcher.read();
            let min_liquidity = self.Stream_primary_min_liquidity.read();

            // Initialize pool first
            let pool_key = self._get_primary_pool_key();
            let core_dispatcher = self.Stream_core_dispatcher.read();
            let initial_tick = self.Stream_primary_initial_tick.read();
            let pool_id = core_dispatcher.initialize_pool(pool_key, initial_tick);
            self.Stream_pool_id.write(pool_id);

            // Emit pool initialized event
            let pool_key_hash = self._compute_pool_key_hash(pool_key);
            self.emit(PoolInitialized { pool_key_hash, pool_id });

            // Provide liquidity using tokens already transferred to positions contract
            let (position_id, liquidity, token0_cleared, token1_cleared) = positions_dispatcher
                .mint_and_deposit_and_clear_both(pool_key, TWAMM_BOUNDS, min_liquidity);

            self.Stream_liquidity_position_id.write(position_id);
            self.Stream_deployment_state.write(1);

            self
                .emit(
                    LiquidityProvided {
                        position_id,
                        liquidity,
                        token0_amount: token0_cleared,
                        token1_amount: token1_cleared,
                    },
                );

            (position_id, liquidity, token0_cleared, token1_cleared)
        }

        fn start_distributions(ref self: ComponentState<TContractState>) {
            // Only factory can call this
            self._assert_only_factory();
            assert(self.Stream_deployment_state.read() == 1, Errors::STREAM_LIQUIDITY_NOT_PROVIDED);

            let positions_dispatcher = self.Stream_positions_dispatcher.read();
            let order_count = self.Stream_order_count.read();
            let mut i: u32 = 0;

            while i < order_count {
                let order = self.Stream_orders.read(i);
                let order_key = self._build_order_key(@order);

                // Get or create position for this (buy_token, fee) combination
                let mut position_id = self.Stream_position_ids.read((order.buy_token, order.fee));

                let sale_rate = if position_id == 0 {
                    // First order for this combination - mint new position
                    let (new_position_id, rate) = positions_dispatcher
                        .mint_and_increase_sell_amount(order_key, order.amount);
                    position_id = new_position_id;
                    self.Stream_position_ids.write((order.buy_token, order.fee), position_id);
                    rate
                } else {
                    // Existing position - just increase sell amount
                    positions_dispatcher.increase_sell_amount(position_id, order_key, order.amount)
                };

                self
                    .emit(
                        DistributionStarted {
                            order_index: i,
                            buy_token: order.buy_token,
                            amount: order.amount,
                            end_time: order.end_time,
                            proceeds_recipient: order.proceeds_recipient,
                            position_id,
                            sale_rate,
                        },
                    );

                i += 1;
            }

            self.Stream_deployment_state.write(2);
        }
    }

    /// Internal implementation with helper functions
    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initialize the component with required parameters
        ///
        /// # Arguments
        /// * `factory` - Factory address that deployed this token
        /// * `positions_address` - Ekubo positions contract
        /// * `core_address` - Ekubo core contract
        /// * `registry_address` - Ekubo token registry
        /// * `extension_address` - TWAMM extension address
        /// * `liquidity_config` - Primary pool liquidity configuration
        /// * `distribution_orders` - Distribution orders to create
        fn initializer(
            ref self: ComponentState<TContractState>,
            factory: ContractAddress,
            positions_address: ContractAddress,
            core_address: ContractAddress,
            registry_address: ContractAddress,
            extension_address: ContractAddress,
            liquidity_config: LiquidityConfig,
            distribution_orders: Span<DistributionOrder>,
        ) {
            // Validate addresses
            let zero_address: ContractAddress = Zero::zero();
            assert(factory != zero_address, Errors::STREAM_INVALID_FACTORY);
            assert(positions_address != zero_address, Errors::INVALID_POSITIONS_ADDRESS);
            assert(core_address != zero_address, Errors::STREAM_INVALID_CORE);
            assert(registry_address != zero_address, Errors::STREAM_INVALID_REGISTRY);
            assert(extension_address != zero_address, Errors::INVALID_EXTENSION_ADDRESS);

            // Validate liquidity config
            assert(
                liquidity_config.paired_token != zero_address, Errors::STREAM_INVALID_PAIRED_TOKEN,
            );
            assert(liquidity_config.stream_token_amount > 0, Errors::STREAM_INVALID_STREAM_AMOUNT);
            assert(liquidity_config.paired_token_amount > 0, Errors::STREAM_INVALID_PAIRED_AMOUNT);

            // Store configuration
            self.Stream_factory.write(factory);
            self
                .Stream_positions_dispatcher
                .write(IPositionsDispatcher { contract_address: positions_address });
            self.Stream_core_dispatcher.write(ICoreDispatcher { contract_address: core_address });
            self
                .Stream_registry_dispatcher
                .write(ITokenRegistryDispatcher { contract_address: registry_address });
            self.Stream_extension_address.write(extension_address);

            // Store liquidity config
            self.Stream_primary_paired_token.write(liquidity_config.paired_token);
            self.Stream_primary_fee.write(liquidity_config.fee);
            self.Stream_primary_initial_tick.write(liquidity_config.initial_tick);
            self.Stream_primary_stream_token_amount.write(liquidity_config.stream_token_amount);
            self.Stream_primary_paired_token_amount.write(liquidity_config.paired_token_amount);
            self.Stream_primary_min_liquidity.write(liquidity_config.min_liquidity);

            // Store distribution orders
            let order_count: u32 = distribution_orders.len();
            assert(order_count > 0, Errors::STREAM_NO_ORDERS);
            assert(order_count <= 10, Errors::STREAM_TOO_MANY_ORDERS);

            let mut i: u32 = 0;
            while i < order_count {
                let order = *distribution_orders.at(i);

                // Validate order
                assert(order.buy_token != zero_address, Errors::STREAM_INVALID_BUY_TOKEN);
                assert(order.amount > 0, Errors::STREAM_INVALID_ORDER_AMOUNT);
                assert(order.proceeds_recipient != zero_address, Errors::STREAM_INVALID_RECIPIENT);

                // Store order
                self
                    .Stream_orders
                    .write(
                        i,
                        StoredDistributionOrder {
                            buy_token: order.buy_token,
                            fee: order.fee,
                            start_time: order.start_time,
                            end_time: order.end_time,
                            amount: order.amount,
                            proceeds_recipient: order.proceeds_recipient,
                        },
                    );

                i += 1;
            }

            self.Stream_order_count.write(order_count);
            self.Stream_deployment_state.write(0);
        }

        /// Register the token with Ekubo token registry
        fn register_token(ref self: ComponentState<TContractState>) {
            let registry_dispatcher = self.Stream_registry_dispatcher.read();
            let erc20_dispatcher = EkuboIERC20Dispatcher {
                contract_address: get_contract_address(),
            };
            registry_dispatcher.register_token(erc20_dispatcher);
        }

        /// Assert that caller is the factory
        fn _assert_only_factory(self: @ComponentState<TContractState>) {
            let caller = starknet::get_caller_address();
            let factory = self.Stream_factory.read();
            assert(caller == factory, Errors::STREAM_ONLY_FACTORY);
        }

        /// Check if this token address is token0 in a pool with another token
        fn _is_token0(self: @ComponentState<TContractState>, other_token: ContractAddress) -> bool {
            get_contract_address() < other_token
        }

        /// Get the primary pool key (for liquidity pool)
        fn _get_primary_pool_key(self: @ComponentState<TContractState>) -> PoolKey {
            let this_token = get_contract_address();
            let paired_token = self.Stream_primary_paired_token.read();
            let fee = self.Stream_primary_fee.read();
            let extension = self.Stream_extension_address.read();

            if this_token < paired_token {
                PoolKey {
                    token0: this_token,
                    token1: paired_token,
                    fee,
                    tick_spacing: TWAMM_TICK_SPACING,
                    extension,
                }
            } else {
                PoolKey {
                    token0: paired_token,
                    token1: this_token,
                    fee,
                    tick_spacing: TWAMM_TICK_SPACING,
                    extension,
                }
            }
        }

        /// Build an OrderKey from a stored distribution order
        fn _build_order_key(
            self: @ComponentState<TContractState>, order: @StoredDistributionOrder,
        ) -> OrderKey {
            OrderKey {
                sell_token: get_contract_address(),
                buy_token: *order.buy_token,
                fee: *order.fee,
                start_time: *order.start_time,
                end_time: *order.end_time,
            }
        }

        /// Compute hash of a pool key
        fn _compute_pool_key_hash(
            self: @ComponentState<TContractState>, pool_key: PoolKey,
        ) -> felt252 {
            let mut state = PoseidonTrait::new();
            state = state.update_with(pool_key.token0);
            state = state.update_with(pool_key.token1);
            state = state.update_with(pool_key.fee);
            state = state.update_with(pool_key.tick_spacing);
            state = state.update_with(pool_key.extension);
            state.finalize()
        }

        /// Get the total amount of tokens needed for distribution orders
        fn get_total_distribution_amount(self: @ComponentState<TContractState>) -> u128 {
            let order_count = self.Stream_order_count.read();
            let mut total: u128 = 0;
            let mut i: u32 = 0;

            while i < order_count {
                let order = self.Stream_orders.read(i);
                total += order.amount;
                i += 1;
            }

            total
        }

        /// Get liquidity token amounts
        fn get_liquidity_amounts(self: @ComponentState<TContractState>) -> (u128, u128) {
            (
                self.Stream_primary_stream_token_amount.read(),
                self.Stream_primary_paired_token_amount.read(),
            )
        }

        /// Get paired token address
        fn get_paired_token(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Stream_primary_paired_token.read()
        }
    }
}
