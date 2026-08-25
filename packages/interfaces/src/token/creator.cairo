// Token creator extension interface
//
// The registry used to carry a game's creator identity and monetization fee
// (the payee was the registry NFT's owner; the fee came from `GameFeeInfo`).
// With the self-bound standard token there is no registry, so the identity
// lives on the token standard itself: set at initialization, administered by
// the game contract's OZ Ownable OWNER (the stored creator is a payout sink
// only), and discoverable via SRC5 so monetization platforms (e.g. Budokan)
// can resolve the payee and minimum fee live at claim time.
use starknet::ContractAddress;
pub use crate::registry::{DEFAULT_GAME_FEE_BPS, FEE_DENOMINATOR};
pub use crate::structs::token::GameCreatorInfo;

/// Default license text for the STANDARD token's creator surface.
///
/// Deliberately fee-amount-free: the authoritative fee is the on-chain
/// `fee_numerator` (owner-rotatable via `set_game_fee`), so a number baked
/// into the text would go stale on the first fee change. The text points
/// consumers at the on-chain declaration instead and resolves both rate and
/// payee at time of payment. The legacy registry keeps its own v1.0 text
/// (`registry::default_license`) — that string is what deployed denshokan
/// carries and stays frozen.
pub fn default_license() -> ByteArray {
    "Embeddable Game Standard License v1.1. Monetization of this game requires payment of the game fee this contract declares on-chain, at the rate and to the game creator address in effect at the time of payment (game_creator_info). Non-monetized integration, indexing, and display of this game are unrestricted."
}

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - game_creator_info()->(ContractAddress,(Array<bytes31>,felt252,usize),u16)
///   0x1879f9741e7b592cc8da6ca5d9cf83ad687f91b87761744cd80f7a36deed4e
/// - game_creator_address()->ContractAddress
///   0x303788bd08cbf196171a0b6fcb0c815715fb3916ee1c10b3d67d6a842650b1e
/// - set_game_creator_address(ContractAddress)
///   0x23fb1fc00d3dc31c6c8b33b1a262d95b2fff025a12cef8aaf076874fdcf7255
/// - set_game_fee((Array<bytes31>,felt252,usize),u16)
///   0x3318144fd81873b0e256922d3972f42e61a473c6336dfcc2e9f2e8defdcf9e2
pub const IMINIGAME_TOKEN_CREATOR_ID: felt252 =
    0x21531ca59c09f4a8554a0c390d8054188d27b19148c9039f0279f2b66a86de7;

#[starknet::interface]
pub trait IMinigameTokenCreator<TState> {
    fn game_creator_info(self: @TState) -> GameCreatorInfo;
    fn game_creator_address(self: @TState) -> ContractAddress;
    /// Rotate the payee. Gated on the game contract's Ownable owner; the new
    /// address must be non-zero (rotation must never brick the payee).
    fn set_game_creator_address(ref self: TState, new_creator: ContractAddress);
    /// Update the license text and fee. Gated on the game contract's Ownable
    /// owner; `fee_numerator` is in basis points, capped at `FEE_DENOMINATOR`.
    fn set_game_fee(ref self: TState, license: ByteArray, fee_numerator: u16);
}
