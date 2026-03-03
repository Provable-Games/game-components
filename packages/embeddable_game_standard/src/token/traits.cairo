use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
use starknet::ContractAddress;

// Optional trait implementations for features that may or may not be enabled
// These allow the core token to work with or without specific features

pub trait OptionalMinter<TContractState> {
    fn add_minter(ref self: TContractState, minter: ContractAddress) -> u64;
    fn get_minter_address(self: @TContractState, minter_id: u64) -> starknet::ContractAddress;
}

pub trait OptionalContext<TContractState> {
    fn emit_context(
        ref self: TContractState,
        caller: ContractAddress,
        token_id: felt252,
        context: GameContextDetails,
    );
}

pub trait OptionalObjectives<TContractState> {
    fn validate_objective(self: @TContractState, game_address: ContractAddress, objective_id: u32);
    fn is_objective_completed(
        self: @TContractState, game_address: ContractAddress, token_id: felt252, objective_id: u32,
    ) -> bool;
}

pub trait OptionalSettings<TContractState> {
    fn validate_settings(self: @TContractState, game_address: ContractAddress, settings_id: u32);
}

pub trait OptionalSoulbound<TContractState> {
    fn check_transfer_allowed(self: @TContractState, token_id: felt252) -> bool;
    fn set_soulbound_status(ref self: TContractState, token_id: felt252, is_soulbound: bool);
}

pub trait OptionalRenderer<TContractState> {
    fn get_token_renderer(self: @TContractState, token_id: felt252) -> Option<ContractAddress>;
    fn set_token_renderer(ref self: TContractState, token_id: felt252, renderer: ContractAddress);
}

pub trait OptionalSkills<TContractState> {
    fn get_token_skills(self: @TContractState, token_id: felt252) -> Option<ContractAddress>;
    fn set_token_skills(
        ref self: TContractState, token_id: felt252, skills_address: ContractAddress,
    );
}
