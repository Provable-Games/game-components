use starknet::ContractAddress;

pub const IENTRY_REQUIREMENT_EXTENSION_ID: felt252 =
    0x03932b83d6f280c123c10e3eec69c9f5776a2a1de7b7d401120c49a9936954fa;

/// Legacy interface IDs for backward compatibility with deployed Budokan contracts.
pub const LEGACY_IENTRY_VALIDATOR_ID_V2: felt252 =
    0x73b204ef90f88bbdf6a178473d1445e76fd9a48a188c6659cb93f988b8458a;
pub const LEGACY_IENTRY_VALIDATOR_ID_V1: felt252 =
    0x01158754d5cc62137c4de2cbd0e65cbd163990af29f0182006f26fe0cac00bb6;

#[starknet::interface]
pub trait IEntryRequirementExtension<TState> {
    fn owner_address(self: @TState) -> ContractAddress;
    fn registration_only(self: @TState) -> bool;
    fn valid_entry(
        self: @TState,
        context_id: u64,
        player_address: ContractAddress,
        qualification: Span<felt252>,
    ) -> bool;
    fn should_ban(
        self: @TState,
        context_id: u64,
        game_token_id: felt252,
        current_owner: ContractAddress,
        qualification: Span<felt252>,
    ) -> bool;
    fn entries_left(
        self: @TState,
        context_id: u64,
        player_address: ContractAddress,
        qualification: Span<felt252>,
    ) -> Option<u8>;
    fn add_config(ref self: TState, context_id: u64, entry_limit: u8, config: Span<felt252>);
    fn add_entry(
        ref self: TState,
        context_id: u64,
        game_token_id: felt252,
        player_address: ContractAddress,
        qualification: Span<felt252>,
    );
    fn remove_entry(
        ref self: TState,
        context_id: u64,
        game_token_id: felt252,
        player_address: ContractAddress,
        qualification: Span<felt252>,
    );
}
