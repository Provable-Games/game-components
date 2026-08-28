// Metagame context extension interface
use starknet::ContractAddress;
use crate::structs::metagame::GameContextDetails;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - has_context(ContractAddress,felt252)->E((),())
pub const IMETAGAME_CONTEXT_ID: felt252 =
    0x1619dc3272af5ae7e632e00012211abb89ee97571405c6714125b4c4eb77bb4;

/// A token is identified by the PAIR (game_address, token_id), never by
/// token_id alone: ids are unique only within the contract that minted them.
/// These methods therefore take both.
///
/// Taking only `token_id` was safe while a registry meant every entry came
/// from one shared token contract. The self-bound generation removed that,
/// and a metagame serving two games can hold two registrations under the same
/// packed id — so a bare-id lookup has to either guess or refuse. That is
/// exactly why the display-only reverse index keyed on bare `token_id` was
/// deleted from `RegistrationComponent` rather than repaired.
///
/// The id moved with this signature. That is deliberate: a metagame built
/// against the old shape registers the OLD id, so `supports_interface`
/// answers false and a caller skips it, instead of dispatching and reverting
/// on an argument-count mismatch.
#[starknet::interface]
pub trait IMetagameContext<TState> {
    fn has_context(self: @TState, game_address: ContractAddress, token_id: felt252) -> bool;
}

#[starknet::interface]
pub trait IMetagameContextDetails<TState> {
    fn context_details(
        self: @TState, game_address: ContractAddress, token_id: felt252,
    ) -> GameContextDetails;
}

#[starknet::interface]
pub trait IMetagameContextSVG<TState> {
    fn context_svg(self: @TState, game_address: ContractAddress, token_id: felt252) -> ByteArray;
}
