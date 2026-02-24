/// Test-only Autonomous Buyback contract for unit testing
/// This is identical to the preset in game_components_presets but defined here
/// so tokenomics tests can use `declare("AutonomousBuyback")`.
#[starknet::contract]
pub mod AutonomousBuyback {
    use game_components_economy::tokenomics::buyback::BuybackComponent;
    use game_components_interfaces::tokenomics::buyback::{
        GlobalBuybackConfig, IBuybackAdmin, TokenBuybackConfig,
    };
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    component!(path: BuybackComponent, storage: buyback, event: BuybackEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl BuybackImpl = BuybackComponent::BuybackImpl<ContractState>;
    impl BuybackInternalImpl = BuybackComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        buyback: BuybackComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BuybackEvent: BuybackComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        global_config: GlobalBuybackConfig,
        positions_address: ContractAddress,
        extension_address: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.buyback.initializer(global_config, positions_address, extension_address);
    }

    #[abi(embed_v0)]
    impl BuybackAdminImpl of IBuybackAdmin<ContractState> {
        fn set_global_config(ref self: ContractState, config: GlobalBuybackConfig) {
            self.ownable.assert_only_owner();
            self.buyback.set_global_config(config);
        }

        fn set_token_config(
            ref self: ContractState,
            sell_token: ContractAddress,
            config: Option<TokenBuybackConfig>,
        ) {
            self.ownable.assert_only_owner();
            self.buyback.set_token_config(sell_token, config);
        }
    }
}
