use starknet::{ContractAddress, contract_address_const};
use crate::core::traits::{
    OptionalMinter, OptionalContext, OptionalObjectives, OptionalSettings, OptionalSoulbound,
    OptionalRenderer,
};
use game_components_metagame::extensions::context::structs::GameContextDetails;
use crate::interface::ITokenEventRelayerDispatcher;

// No-op implementations for disabled features
pub impl NoOpMinter<TContractState> of OptionalMinter<TContractState> {
    fn add_minter(
        ref self: TContractState,
        minter: ContractAddress,
        event_relayer: Option<ITokenEventRelayerDispatcher>,
    ) -> u64 {
        0
    }

    fn get_minter_address(self: @TContractState, minter_id: u64) -> starknet::ContractAddress {
        contract_address_const::<0>()
    }
}

pub impl NoOpContext<TContractState> of OptionalContext<TContractState> {
    fn emit_context(
        ref self: TContractState,
        caller: ContractAddress,
        token_id: u64,
        context: GameContextDetails,
        event_relayer: Option<ITokenEventRelayerDispatcher>,
    ) { // No-op
    }
}

pub impl NoOpObjectives<TContractState> of OptionalObjectives<TContractState> {
    fn validate_objectives(
        self: @TContractState, game_address: ContractAddress, objective_ids: Span<u32>,
    ) -> (u32, Span<u32>) {
        (0, objective_ids)
    }

    fn set_token_objectives(
        ref self: TContractState,
        token_id: u64,
        objective_ids: Span<u32>,
        event_relayer: Option<ITokenEventRelayerDispatcher>,
    ) { // No-op
    }

    fn update_objectives(
        ref self: TContractState,
        token_id: u64,
        game_address: ContractAddress,
        objectives_count: u32,
        event_relayer: Option<ITokenEventRelayerDispatcher>,
    ) -> bool {
        false
    }

    fn are_objectives_completed(self: @TContractState, token_id: u64) -> bool {
        true
    }
}

pub impl NoOpSettings<TContractState> of OptionalSettings<TContractState> {
    fn validate_settings(
        self: @TContractState, game_address: ContractAddress, settings_id: u32,
    ) { // No-op
    }
}

pub impl NoOpSoulbound<TContractState> of OptionalSoulbound<TContractState> {
    fn check_transfer_allowed(self: @TContractState, token_id: u64) -> bool {
        true
    }

    fn set_soulbound_status(ref self: TContractState, token_id: u64, is_soulbound: bool) { // No-op
    }
}

pub impl NoOpRenderer<TContractState> of OptionalRenderer<TContractState> {
    fn get_token_renderer(self: @TContractState, token_id: u64) -> Option<ContractAddress> {
        Option::None
    }

    fn set_token_renderer(
        ref self: TContractState,
        token_id: u64,
        renderer: ContractAddress,
        event_relayer: Option<ITokenEventRelayerDispatcher>,
    ) { // No-op
    }
}
