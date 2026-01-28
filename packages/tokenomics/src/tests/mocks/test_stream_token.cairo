/// Test-only Stream Token contract for unit testing
/// This is identical to the preset in game_components_presets but defined here
/// so tokenomics tests can use `declare("StreamToken")`.
#[starknet::contract]
pub mod StreamToken {
    use game_components_interfaces::tokenomics::stream::{
        DistributionOrder, LiquidityConfig, PremintAllocation,
    };
    use game_components_tokenomics::ERC20_UNIT;
    use game_components_tokenomics::stream::StreamComponent;
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: StreamComponent, storage: stream, event: StreamEvent);

    pub impl ERC20Config of ERC20Component::ImmutableConfig {
        const DECIMALS: u8 = 18;
    }

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl StreamImpl = StreamComponent::StreamImpl<ContractState>;

    #[abi(embed_v0)]
    impl StreamSetupImpl = StreamComponent::StreamSetupImpl<ContractState>;

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
        premint_allocations: Span<PremintAllocation>,
    ) {
        self.erc20.initializer(name, symbol);
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
                premint_allocations,
            );

        self.erc20.mint(registry_address, ERC20_UNIT.into());
        self.stream.register_token();

        // Mint premint allocations directly to recipients
        let mut premint_total: u128 = 0;
        for premint in premint_allocations {
            self.erc20.mint(*premint.recipient, (*premint.amount).into());
            self
                .stream
                .emit(
                    StreamComponent::Preminted {
                        recipient: *premint.recipient, amount: *premint.amount,
                    },
                );
            premint_total += *premint.amount;
        }

        let remaining_supply: u256 = (total_supply - ERC20_UNIT - premint_total).into();
        self.erc20.mint(factory, remaining_supply);
    }
}
