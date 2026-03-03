// Skills interfaces

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - skills(felt252)->(Array<bytes31>,felt252,usize)
pub const ISKILLS_ID: felt252 = 0x39fae678a19cd9b999da1d9ad54f00e686406974a4ced6f7eb51c8959aabd98;

/// External contract interface for skills providers
#[starknet::interface]
pub trait ISkills<TState> {
    fn skills(self: @TState, token_id: felt252) -> ByteArray;
}

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - get_skills_address(felt252)->ContractAddress
/// - has_custom_skills(felt252)->E((),())
/// - reset_token_skills(felt252)
/// - reset_token_skills_batch((@Array<felt252>))
/// - get_skills_address_batch((@Array<felt252>))->Array<ContractAddress>
pub const IMINIGAME_TOKEN_SKILLS_ID: felt252 =
    0x33846532a9b9e859675aaa1a6c3ae6a45ccf1920c83e2d34898fa2f116201b3;

/// Token extension interface for per-token skills address overrides
#[starknet::interface]
pub trait IMinigameTokenSkills<TState> {
    fn get_skills_address(self: @TState, token_id: felt252) -> starknet::ContractAddress;
    fn has_custom_skills(self: @TState, token_id: felt252) -> bool;
    fn reset_token_skills(ref self: TState, token_id: felt252);

    // Batch operations
    fn reset_token_skills_batch(ref self: TState, token_ids: Span<felt252>);
    fn get_skills_address_batch(
        self: @TState, token_ids: Span<felt252>,
    ) -> Array<starknet::ContractAddress>;
}
