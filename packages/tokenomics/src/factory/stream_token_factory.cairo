/// Stream Token Factory
///
/// Deploys autonomous ERC20 tokens with built-in TWAMM distribution via Ekubo.
/// Each token is fully autonomous after deployment - no admin keys or upgrade paths.
///
/// # Deployment Flow
/// 1. User approves factory for paired token amount
/// 2. User calls create_token with parameters
/// 3. Factory deploys StreamToken contract
/// 4. Factory transfers paired tokens to Ekubo positions
/// 5. Factory calls provide_initial_liquidity on token
/// 6. Factory transfers stream tokens to Ekubo positions
/// 7. Factory calls start_distributions on token
/// 8. Token is now fully autonomous and distributing
#[starknet::contract]
pub mod StreamTokenFactory {
    use core::num::traits::Zero;
    use ekubo::interfaces::positions::IPositionsDispatcher;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_interfaces::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use crate::constants::{ERC20_UNIT, Errors};
    use crate::stream::interface::{
        CreateTokenParams, IStreamTokenFactory, IStreamTokenFactoryAdmin,
        IStreamTokenSetupDispatcher, IStreamTokenSetupDispatcherTrait,
    };

    // Embed Ownable component for admin functions
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        /// Class hash for deploying StreamToken contracts
        stream_token_class_hash: ClassHash,
        /// Ekubo positions contract
        positions_dispatcher: IPositionsDispatcher,
        /// Ekubo core contract address
        core_address: ContractAddress,
        /// TWAMM extension address
        extension_address: ContractAddress,
        /// Token registry address
        registry_address: ContractAddress,
        /// Mapping of valid tokens created by this factory
        valid_tokens: Map<ContractAddress, bool>,
        /// Total number of tokens created
        token_count: u64,
        /// Nonce for deterministic deployment
        deploy_nonce: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        StreamTokenCreated: StreamTokenCreated,
    }

    /// Emitted when a new stream token is created
    #[derive(Drop, starknet::Event)]
    struct StreamTokenCreated {
        #[key]
        pub token_address: ContractAddress,
        #[key]
        pub creator: ContractAddress,
        pub name: ByteArray,
        pub symbol: ByteArray,
        pub total_supply: u128,
        pub order_count: u32,
    }

    /// Initialize the Stream Token Factory
    ///
    /// # Arguments
    /// * `owner` - Factory owner who can update class hash
    /// * `stream_token_class_hash` - Class hash for deploying StreamToken contracts
    /// * `positions_address` - Ekubo positions contract
    /// * `core_address` - Ekubo core contract
    /// * `extension_address` - TWAMM extension address
    /// * `registry_address` - Token registry address
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        stream_token_class_hash: ClassHash,
        positions_address: ContractAddress,
        core_address: ContractAddress,
        extension_address: ContractAddress,
        registry_address: ContractAddress,
    ) {
        // Validate addresses
        let zero_address: ContractAddress = Zero::zero();
        assert(positions_address != zero_address, Errors::INVALID_POSITIONS_ADDRESS);
        assert(core_address != zero_address, Errors::STREAM_INVALID_CORE);
        assert(extension_address != zero_address, Errors::INVALID_EXTENSION_ADDRESS);
        assert(registry_address != zero_address, Errors::STREAM_INVALID_REGISTRY);

        // Initialize ownable
        self.ownable.initializer(owner);

        // Store configuration
        self.stream_token_class_hash.write(stream_token_class_hash);
        self
            .positions_dispatcher
            .write(IPositionsDispatcher { contract_address: positions_address });
        self.core_address.write(core_address);
        self.extension_address.write(extension_address);
        self.registry_address.write(registry_address);
        self.deploy_nonce.write(0);
    }

    #[abi(embed_v0)]
    impl StreamTokenFactoryImpl of IStreamTokenFactory<ContractState> {
        fn create_token(ref self: ContractState, params: CreateTokenParams) -> ContractAddress {
            let caller = get_caller_address();
            let this = get_contract_address();
            let positions_dispatcher = self.positions_dispatcher.read();

            // Validate parameters
            assert(params.total_supply > 0, Errors::STREAM_INVALID_TOTAL_SUPPLY);
            assert(params.distribution_orders.len() > 0, Errors::STREAM_NO_ORDERS);
            assert(params.distribution_orders.len() <= 10, Errors::STREAM_TOO_MANY_ORDERS);

            // Calculate total tokens needed
            let mut distribution_total: u128 = 0;
            let mut i: u32 = 0;
            let order_count = params.distribution_orders.len();
            while i < order_count {
                let order = *params.distribution_orders.at(i);
                distribution_total += order.amount;
                i += 1;
            }

            let lp_amount = params.liquidity_config.stream_token_amount;
            let total_needed = ERC20_UNIT + lp_amount + distribution_total;
            assert(params.total_supply >= total_needed, Errors::STREAM_SUPPLY_TOO_LOW);

            // Transfer paired tokens from caller to positions contract
            let paired_token = params.liquidity_config.paired_token;
            let paired_amount: u256 = params.liquidity_config.paired_token_amount.into();
            let paired_dispatcher = IERC20Dispatcher { contract_address: paired_token };
            paired_dispatcher
                .transfer_from(caller, positions_dispatcher.contract_address, paired_amount);

            // Get deployment salt
            let nonce = self.deploy_nonce.read();
            self.deploy_nonce.write(nonce + 1);

            // Prepare constructor calldata
            let mut calldata: Array<felt252> = array![];

            // Serialize all constructor arguments
            params.name.serialize(ref calldata);
            params.symbol.serialize(ref calldata);
            params.total_supply.serialize(ref calldata);
            this.serialize(ref calldata); // factory
            positions_dispatcher.contract_address.serialize(ref calldata);
            self.core_address.read().serialize(ref calldata);
            self.registry_address.read().serialize(ref calldata);
            self.extension_address.read().serialize(ref calldata);
            params.liquidity_config.serialize(ref calldata);
            params.distribution_orders.serialize(ref calldata);

            // Deploy the token contract
            let class_hash = self.stream_token_class_hash.read();
            let (token_address, _) = deploy_syscall(class_hash, nonce, calldata.span(), false)
                .expect('Deploy failed');

            // Token minted remaining supply to factory, now distribute it:
            // 1. Transfer LP tokens to positions contract
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let lp_amount_u256: u256 = lp_amount.into();
            token_dispatcher.transfer(positions_dispatcher.contract_address, lp_amount_u256);

            // 2. Call provide_initial_liquidity on token
            let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: token_address };
            setup_dispatcher.provide_initial_liquidity();

            // 3. Transfer distribution tokens to positions contract
            let distribution_amount_u256: u256 = distribution_total.into();
            token_dispatcher
                .transfer(positions_dispatcher.contract_address, distribution_amount_u256);

            // 4. Start distributions
            setup_dispatcher.start_distributions();

            // Register token as valid
            self.valid_tokens.write(token_address, true);
            let current_count = self.token_count.read();
            self.token_count.write(current_count + 1);

            // Emit event
            self
                .emit(
                    StreamTokenCreated {
                        token_address,
                        creator: caller,
                        name: params.name,
                        symbol: params.symbol,
                        total_supply: params.total_supply,
                        order_count,
                    },
                );

            token_address
        }

        fn is_valid_token(self: @ContractState, token: ContractAddress) -> bool {
            self.valid_tokens.read(token)
        }

        fn get_token_count(self: @ContractState) -> u64 {
            self.token_count.read()
        }

        fn get_stream_token_class_hash(self: @ContractState) -> ClassHash {
            self.stream_token_class_hash.read()
        }

        fn get_positions_address(self: @ContractState) -> ContractAddress {
            self.positions_dispatcher.read().contract_address
        }

        fn get_core_address(self: @ContractState) -> ContractAddress {
            self.core_address.read()
        }

        fn get_extension_address(self: @ContractState) -> ContractAddress {
            self.extension_address.read()
        }

        fn get_registry_address(self: @ContractState) -> ContractAddress {
            self.registry_address.read()
        }
    }

    #[abi(embed_v0)]
    impl StreamTokenFactoryAdminImpl of IStreamTokenFactoryAdmin<ContractState> {
        fn set_stream_token_class_hash(ref self: ContractState, class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.stream_token_class_hash.write(class_hash);
        }
    }
}
