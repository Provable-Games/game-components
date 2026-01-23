use core::num::traits::Zero;
use starknet::ContractAddress;

/// Test address constants
pub fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

pub fn USER1() -> ContractAddress {
    'USER1'.try_into().unwrap()
}

pub fn USER2() -> ContractAddress {
    'USER2'.try_into().unwrap()
}

pub fn TREASURY() -> ContractAddress {
    'TREASURY'.try_into().unwrap()
}

pub fn BUYBACK_TOKEN() -> ContractAddress {
    'BUYBACK_TOKEN'.try_into().unwrap()
}

pub fn ZERO_ADDRESS() -> ContractAddress {
    Zero::zero()
}

/// Mainnet addresses for fork testing
pub mod mainnet {
    use starknet::ContractAddress;

    /// Ekubo Positions contract on mainnet
    pub fn EKUBO_POSITIONS() -> ContractAddress {
        // Ekubo Positions contract address
        0x02e0af29598b407c8716b17f6d2795eca1b471413fa03fb145a5e33722184067.try_into().unwrap()
    }

    /// Ekubo TWAMM extension on mainnet
    pub fn EKUBO_TWAMM_EXTENSION() -> ContractAddress {
        // TWAMM extension address
        0x043e4f09c32d13d43a880e85f69f7de93ceda62d6cf2581a582c6db635548fdc.try_into().unwrap()
    }

    /// USDC token on mainnet
    pub fn USDC() -> ContractAddress {
        0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8.try_into().unwrap()
    }

    /// ETH token on mainnet
    pub fn ETH() -> ContractAddress {
        0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7.try_into().unwrap()
    }

    /// STRK token on mainnet
    pub fn STRK() -> ContractAddress {
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d.try_into().unwrap()
    }
}

/// Default test configuration values
pub mod defaults {
    use game_components_tokenomics::{GlobalBuybackConfig, TokenBuybackConfig};
    use starknet::ContractAddress;
    use super::{BUYBACK_TOKEN, TREASURY};

    /// Default minimum duration (1 hour)
    pub const MIN_DURATION: u64 = 3600;

    /// Default maximum duration (30 days)
    pub const MAX_DURATION: u64 = 2592000;

    /// Default fee (0.3% = 3000 basis points)
    pub const DEFAULT_FEE: u128 = 170141183460469235273462165868118016;

    /// Default minimum amount for buybacks
    pub const MIN_AMOUNT: u128 = 0;

    /// Get default global configuration
    pub fn default_global_config() -> GlobalBuybackConfig {
        GlobalBuybackConfig {
            default_buy_token: BUYBACK_TOKEN(),
            default_treasury: TREASURY(),
            default_minimum_amount: MIN_AMOUNT,
            default_min_delay: 0,
            default_max_delay: 0,
            default_min_duration: MIN_DURATION,
            default_max_duration: MAX_DURATION,
            default_fee: DEFAULT_FEE,
        }
    }

    /// Get default global configuration with custom addresses
    pub fn global_config_with(
        buy_token: ContractAddress, treasury: ContractAddress,
    ) -> GlobalBuybackConfig {
        GlobalBuybackConfig {
            default_buy_token: buy_token,
            default_treasury: treasury,
            default_minimum_amount: MIN_AMOUNT,
            default_min_delay: 0,
            default_max_delay: 0,
            default_min_duration: MIN_DURATION,
            default_max_duration: MAX_DURATION,
            default_fee: DEFAULT_FEE,
        }
    }

    /// Get default token configuration
    pub fn default_token_config() -> TokenBuybackConfig {
        TokenBuybackConfig {
            buy_token: BUYBACK_TOKEN(),
            treasury: TREASURY(),
            minimum_amount: MIN_AMOUNT,
            min_delay: 0,
            max_delay: 0,
            min_duration: MIN_DURATION,
            max_duration: MAX_DURATION,
            fee: DEFAULT_FEE,
        }
    }

    /// Get token configuration with custom buy token and treasury
    pub fn token_config_with(
        buy_token: ContractAddress, treasury: ContractAddress,
    ) -> TokenBuybackConfig {
        TokenBuybackConfig {
            buy_token,
            treasury,
            minimum_amount: MIN_AMOUNT,
            min_delay: 0,
            max_delay: 0,
            min_duration: MIN_DURATION,
            max_duration: MAX_DURATION,
            fee: DEFAULT_FEE,
        }
    }

    /// Get token configuration with custom minimum amount
    pub fn token_config_with_minimum(minimum_amount: u128) -> TokenBuybackConfig {
        TokenBuybackConfig {
            buy_token: BUYBACK_TOKEN(),
            treasury: TREASURY(),
            minimum_amount,
            min_delay: 0,
            max_delay: 0,
            min_duration: MIN_DURATION,
            max_duration: MAX_DURATION,
            fee: DEFAULT_FEE,
        }
    }

    /// Get token configuration with delayed start
    pub fn token_config_with_delay(min_delay: u64, max_delay: u64) -> TokenBuybackConfig {
        TokenBuybackConfig {
            buy_token: BUYBACK_TOKEN(),
            treasury: TREASURY(),
            minimum_amount: MIN_AMOUNT,
            min_delay,
            max_delay,
            min_duration: MIN_DURATION,
            max_duration: MAX_DURATION,
            fee: DEFAULT_FEE,
        }
    }

    /// Get token configuration with no max duration (unlimited)
    pub fn token_config_with_no_max_duration() -> TokenBuybackConfig {
        TokenBuybackConfig {
            buy_token: BUYBACK_TOKEN(),
            treasury: TREASURY(),
            minimum_amount: MIN_AMOUNT,
            min_delay: 0,
            max_delay: 0,
            min_duration: MIN_DURATION,
            max_duration: 0, // 0 = no maximum limit
            fee: DEFAULT_FEE,
        }
    }
}

/// Token amounts for testing
pub mod amounts {
    /// 1 token with 18 decimals
    pub const ONE_TOKEN: u256 = 1000000000000000000;
    /// 100 tokens with 18 decimals
    pub const HUNDRED_TOKENS: u256 = 100000000000000000000;
    /// 1000 tokens with 18 decimals
    pub const THOUSAND_TOKENS: u256 = 1000000000000000000000;
}
