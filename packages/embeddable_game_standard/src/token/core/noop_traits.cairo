use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
use starknet::ContractAddress;
use crate::token::core::traits::{
    OptionalContext, OptionalMinter, OptionalObjectives, OptionalRenderer, OptionalSettings,
    OptionalSoulbound,
};

// No-op implementations for disabled features
pub impl NoOpMinter<TContractState> of OptionalMinter<TContractState> {
    fn add_minter(ref self: TContractState, minter: ContractAddress) -> u64 {
        0
    }

    fn get_minter_address(self: @TContractState, minter_id: u64) -> starknet::ContractAddress {
        0.try_into().unwrap()
    }
}

pub impl NoOpContext<TContractState> of OptionalContext<TContractState> {
    fn emit_context(
        ref self: TContractState,
        caller: ContractAddress,
        token_id: felt252,
        context: GameContextDetails,
    ) { // No-op
    }
}

pub impl NoOpObjectives<TContractState> of OptionalObjectives<TContractState> {
    fn validate_objective(
        self: @TContractState, game_address: ContractAddress, objective_id: u32,
    ) { // No-op
    }

    fn is_objective_completed(
        self: @TContractState, game_address: ContractAddress, token_id: felt252, objective_id: u32,
    ) -> bool {
        false
    }
}

pub impl NoOpSettings<TContractState> of OptionalSettings<TContractState> {
    fn validate_settings(
        self: @TContractState, game_address: ContractAddress, settings_id: u32,
    ) { // No-op
    }
}

pub impl NoOpSoulbound<TContractState> of OptionalSoulbound<TContractState> {
    fn check_transfer_allowed(self: @TContractState, token_id: felt252) -> bool {
        true
    }

    fn set_soulbound_status(
        ref self: TContractState, token_id: felt252, is_soulbound: bool,
    ) { // No-op
    }
}

pub impl NoOpRenderer<TContractState> of OptionalRenderer<TContractState> {
    fn get_token_renderer(self: @TContractState, token_id: felt252) -> Option<ContractAddress> {
        Option::None
    }

    fn set_token_renderer(
        ref self: TContractState, token_id: felt252, renderer: ContractAddress,
    ) { // No-op
    }
}
