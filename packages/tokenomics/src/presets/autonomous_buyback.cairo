/// Autonomous Buyback Preset Contract v2
///
/// A deployable contract that combines BuybackComponent with OwnableComponent
/// to provide a complete autonomous buyback system.
///
/// # Features
/// - Permissionless buyback execution via `buy_back()`
/// - Permissionless proceeds claiming via `claim_buyback_proceeds()`
/// - Owner-only configuration updates (global and per-token)
/// - Append-only design: No emergency functions
///
/// # Deployment
/// Constructor requires:
/// - owner: Contract owner address
/// - global_config: GlobalBuybackConfig with default buy_token and treasury
/// - positions_address: Ekubo positions contract
/// - extension_address: TWAMM extension address
///
/// After deployment, owner should call `set_token_config` to configure
/// each sell token with appropriate timing constraints and fees.
#[starknet::contract]
pub mod AutonomousBuyback {
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::ContractAddress;
    use crate::buyback::buyback::BuybackComponent;
    use crate::buyback::interface::{GlobalBuybackConfig, IBuybackAdmin, TokenBuybackConfig};

    // Embed components
    component!(path: BuybackComponent, storage: buyback, event: BuybackEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Expose Buyback permissionless external functions only
    #[abi(embed_v0)]
    impl BuybackImpl = BuybackComponent::BuybackImpl<ContractState>;
    impl BuybackInternalImpl = BuybackComponent::InternalImpl<ContractState>;

    // Expose Ownable external functions
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

    /// Initialize the Autonomous Buyback contract
    ///
    /// # Arguments
    /// * `owner` - Contract owner who can update configuration
    /// * `global_config` - Global configuration with default buy_token and treasury
    /// * `positions_address` - Ekubo positions contract address
    /// * `extension_address` - TWAMM extension contract address
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        global_config: GlobalBuybackConfig,
        positions_address: ContractAddress,
        extension_address: ContractAddress,
    ) {
        // Initialize Ownable component
        self.ownable.initializer(owner);

        // Initialize Buyback component
        self.buyback.initializer(global_config, positions_address, extension_address);
    }

    /// Owner-only implementation of IBuybackAdmin
    /// Ensures only the owner can call admin functions
    ///
    /// NOTE: No emergency functions by design (append-only contract)
    /// The contract can only create orders and claim proceeds.
    /// If issues arise: governance stops funding, existing orders complete naturally,
    /// deploy new contract for future buybacks.
    #[abi(embed_v0)]
    impl BuybackAdminImpl of IBuybackAdmin<ContractState> {
        /// Set the global configuration defaults (owner only)
        fn set_global_config(ref self: ContractState, config: GlobalBuybackConfig) {
            self.ownable.assert_only_owner();
            self.buyback.set_global_config(config);
        }

        /// Set or clear per-token configuration (owner only)
        /// None = use global defaults, Some = override with specific config
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
