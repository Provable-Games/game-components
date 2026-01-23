/// Stream Token Preset Contract
///
/// A deployable ERC20 token with built-in TWAMM distribution capabilities.
/// This contract is designed to be deployed by the StreamTokenFactory.
///
/// # Features
/// - Standard ERC20 functionality (OpenZeppelin)
/// - Autonomous token distribution via Ekubo TWAMM
/// - Multiple concurrent distribution orders
/// - Permissionless proceeds claiming
/// - No admin/owner after deployment (fully autonomous)
#[starknet::contract]
pub mod StreamToken {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use crate::stream::interface::{DistributionOrder, LiquidityConfig};
    use crate::stream::stream::StreamComponent;

    // Embed components
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: StreamComponent, storage: stream, event: StreamEvent);

    // Provide ImmutableConfig for ERC20Component
    pub impl ERC20Config of ERC20Component::ImmutableConfig {
        const DECIMALS: u8 = 18;
    }

    // Expose ERC20 external functions
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Expose Stream permissionless external functions
    #[abi(embed_v0)]
    impl StreamImpl = StreamComponent::StreamImpl<ContractState>;

    // Expose Stream setup functions (factory-only)
    #[abi(embed_v0)]
    impl StreamSetupImpl = StreamComponent::StreamSetupImpl<ContractState>;

    // Internal implementations
    impl StreamInternalImpl = StreamComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        stream: StreamComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        StreamEvent: StreamComponent::Event,
    }

    /// Initialize the Stream Token
    ///
    /// # Arguments
    /// * `name` - Token name
    /// * `symbol` - Token symbol
    /// * `total_supply` - Total supply to mint (to factory initially)
    /// * `factory` - Factory address (caller)
    /// * `positions_address` - Ekubo positions contract
    /// * `core_address` - Ekubo core contract
    /// * `registry_address` - Ekubo token registry
    /// * `extension_address` - TWAMM extension address
    /// * `liquidity_config` - Primary pool liquidity configuration
    /// * `distribution_orders` - Distribution orders to create
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        total_supply: u128,
        factory: ContractAddress,
        positions_address: ContractAddress,
        core_address: ContractAddress,
        registry_address: ContractAddress,
        extension_address: ContractAddress,
        liquidity_config: LiquidityConfig,
        distribution_orders: Span<DistributionOrder>,
    ) {
        // Initialize ERC20
        self.erc20.initializer(name, symbol);

        // Initialize Stream component
        self
            .stream
            .initializer(
                factory,
                positions_address,
                core_address,
                registry_address,
                extension_address,
                liquidity_config,
                distribution_orders,
            );

        // Mint tokens to registry for registration (1 token = 10^18 units)
        use crate::constants::ERC20_UNIT;
        self.erc20.mint(registry_address, ERC20_UNIT.into());

        // Register token with Ekubo
        self.stream.register_token();

        // Mint remaining tokens to factory for distribution
        // Factory will transfer to positions contract for liquidity and distribution
        let remaining_supply: u256 = (total_supply - ERC20_UNIT).into();
        self.erc20.mint(factory, remaining_supply);
    }
}
