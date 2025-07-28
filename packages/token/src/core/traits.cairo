use starknet::ContractAddress;
use game_components_metagame::extensions::context::structs::GameContextDetails;

use crate::interface::ITokenEventRelayerDispatcher;

// Optional trait implementations for features that may or may not be enabled
// These allow the core token to work with or without specific features

pub trait OptionalMinter<TContractState> {
    fn add_minter(
        ref self: TContractState,
        minter: ContractAddress,
        event_relayer: Option<ITokenEventRelayerDispatcher>,
    ) -> u64;
    fn get_minter_address(self: @TContractState, minter_id: u64) -> starknet::ContractAddress;
}

pub trait OptionalContext<TContractState> {
    fn emit_context(
        ref self: TContractState,
        caller: ContractAddress,
        token_id: u64,
        context: GameContextDetails,
        event_relayer: Option<ITokenEventRelayerDispatcher>,
    );
}

pub trait OptionalObjectives<TContractState> {
    fn validate_objectives(
        self: @TContractState, game_address: ContractAddress, objective_ids: Span<u32>,
    ) -> (u32, Span<u32>);
    fn set_token_objectives(
        ref self: TContractState,
        token_id: u64,
        objective_ids: Span<u32>,
        event_relayer: Option<ITokenEventRelayerDispatcher>,
    );
    fn update_objectives(
        ref self: TContractState,
        token_id: u64,
        game_address: ContractAddress,
        objectives_count: u32,
        event_relayer: Option<ITokenEventRelayerDispatcher>,
    ) -> bool;
    // fn get_token_objectives_count(self: @TContractState, token_id: u64) -> u32;
    fn are_objectives_completed(self: @TContractState, token_id: u64) -> bool;
}

pub trait OptionalSettings<TContractState> {
    fn validate_settings(self: @TContractState, game_address: ContractAddress, settings_id: u32);
}

pub trait OptionalSoulbound<TContractState> {
    fn check_transfer_allowed(self: @TContractState, token_id: u64) -> bool;
    fn set_soulbound_status(ref self: TContractState, token_id: u64, is_soulbound: bool);
}

pub trait OptionalRenderer<TContractState> {
    fn get_token_renderer(self: @TContractState, token_id: u64) -> Option<ContractAddress>;
    fn set_token_renderer(
        ref self: TContractState,
        token_id: u64,
        renderer: ContractAddress,
        event_relayer: Option<ITokenEventRelayerDispatcher>,
    );
}
