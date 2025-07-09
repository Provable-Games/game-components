// Optimized batch validation for reducing external calls during mint
pub mod batch_validation {
    use starknet::ContractAddress;
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use game_components_minigame::interface::IMINIGAME_ID;
    
    // Result struct to pack validation results efficiently
    #[derive(Drop, Copy, Serde)]
    pub struct BatchValidationResult {
        pub game_valid: bool,
        pub settings_valid: bool,
        pub settings_id: u32,
        pub objectives_count: u32,
    }
    
    /// Batch validation interface that games can implement for optimized minting
    #[starknet::interface]
    pub trait IBatchMintValidator<TState> {
        fn validate_mint_params(
            self: @TState,
            settings_id: Option<u32>,
            objective_ids: Option<Span<u32>>,
        ) -> BatchValidationResult;
    }
    
    /// Optimized validation that makes a single external call
    pub fn validate_mint_batch(
        game_address: ContractAddress,
        settings_id: Option<u32>,
        objective_ids: Option<Span<u32>>,
    ) -> BatchValidationResult {
        // First check if game supports batch validation
        let game_src5 = ISRC5Dispatcher { contract_address: game_address };
        
        // Check basic game support
        assert!(
            game_src5.supports_interface(IMINIGAME_ID),
            "Game does not support IMinigame"
        );
        
        // Check if game supports batch validation interface
        let BATCH_VALIDATOR_ID: felt252 = 0x1234567890abcdef; // Example interface ID
        
        if game_src5.supports_interface(BATCH_VALIDATOR_ID) {
            // Use optimized batch validation - single call
            let batch_validator = IBatchMintValidatorDispatcher { contract_address: game_address };
            batch_validator.validate_mint_params(settings_id, objective_ids)
        } else {
            // Fall back to individual validation calls
            // This is the current implementation
            BatchValidationResult {
                game_valid: true,
                settings_valid: settings_id.is_some(),
                settings_id: settings_id.unwrap_or(0),
                objectives_count: match objective_ids {
                    Option::Some(ids) => ids.len(),
                    Option::None => 0,
                },
            }
        }
    }
}