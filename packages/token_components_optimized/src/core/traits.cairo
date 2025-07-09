use starknet::ContractAddress;
use crate::features::multi_game::GameMetadata;
use crate::features::objectives::TokenObjective;
use crate::features::context::ContextMetadata;

// Optional trait implementations for features that may or may not be enabled
// These allow the core token to work with or without specific features

pub trait OptionalMinter<TContractState> {
    fn on_mint_with_minter(ref self: TContractState, minter: ContractAddress) -> u64;
}

pub trait OptionalMultiGame<TContractState> {
    fn get_game_metadata_for_address(self: @TContractState, game_address: ContractAddress) -> Option<GameMetadata>;
    fn is_game_registered(self: @TContractState, game_address: ContractAddress) -> bool;
}

pub trait OptionalContext<TContractState> {
    fn store_context(ref self: TContractState, token_id: u64, game_address: ContractAddress, context_data: felt252);
    fn retrieve_context(self: @TContractState, token_id: u64) -> Option<ContextMetadata>;
}

pub trait OptionalObjectives<TContractState> {
    fn set_token_objectives(ref self: TContractState, token_id: u64, objective_ids: Span<u32>);
    fn get_token_objectives_count(self: @TContractState, token_id: u64) -> u32;
    fn are_objectives_completed(self: @TContractState, token_id: u64) -> bool;
}

pub trait OptionalSoulbound<TContractState> {
    fn check_transfer_allowed(self: @TContractState, token_id: u64) -> bool;
    fn set_soulbound_status(ref self: TContractState, token_id: u64, is_soulbound: bool);
}

pub trait OptionalRenderer<TContractState> {
    fn get_token_renderer(self: @TContractState, token_id: u64) -> Option<ContractAddress>;
    fn set_token_renderer(ref self: TContractState, token_id: u64, renderer: ContractAddress);
}

// No-op implementations for disabled features
pub impl NoOpMinter<TContractState> of OptionalMinter<TContractState> {
    fn on_mint_with_minter(ref self: TContractState, minter: ContractAddress) -> u64 {
        0
    }
}

pub impl NoOpMultiGame<TContractState> of OptionalMultiGame<TContractState> {
    fn get_game_metadata_for_address(self: @TContractState, game_address: ContractAddress) -> Option<GameMetadata> {
        Option::None
    }
    
    fn is_game_registered(self: @TContractState, game_address: ContractAddress) -> bool {
        false
    }
}

pub impl NoOpContext<TContractState> of OptionalContext<TContractState> {
    fn store_context(ref self: TContractState, token_id: u64, game_address: ContractAddress, context_data: felt252) {
        // No-op
    }
    
    fn retrieve_context(self: @TContractState, token_id: u64) -> Option<ContextMetadata> {
        Option::None
    }
}

pub impl NoOpObjectives<TContractState> of OptionalObjectives<TContractState> {
    fn set_token_objectives(ref self: TContractState, token_id: u64, objective_ids: Span<u32>) {
        // No-op
    }
    
    fn get_token_objectives_count(self: @TContractState, token_id: u64) -> u32 {
        0
    }
    
    fn are_objectives_completed(self: @TContractState, token_id: u64) -> bool {
        true
    }
}

pub impl NoOpSoulbound<TContractState> of OptionalSoulbound<TContractState> {
    fn check_transfer_allowed(self: @TContractState, token_id: u64) -> bool {
        true
    }
    
    fn set_soulbound_status(ref self: TContractState, token_id: u64, is_soulbound: bool) {
        // No-op
    }
}

pub impl NoOpRenderer<TContractState> of OptionalRenderer<TContractState> {
    fn get_token_renderer(self: @TContractState, token_id: u64) -> Option<ContractAddress> {
        Option::None
    }
    
    fn set_token_renderer(ref self: TContractState, token_id: u64, renderer: ContractAddress) {
        // No-op
    }
} 