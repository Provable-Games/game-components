// Token game-fee extension interface
//
// A game's monetization terms live on the token itself: the GAME FEE
// RECIPIENT (a payout sink), license text and fee rate — set at
// initialization, administered by the game contract's OZ Ownable OWNER, and
// discoverable via SRC5 so monetization platforms (e.g. Budokan) can resolve
// the payee and minimum fee live at claim time.
//
// These terms and the fee constants below used to belong to the registry,
// which resolved the payee through its own NFT's owner. The registry is gone;
// this surface is where a game declares what it charges and who is paid.
use starknet::ContractAddress;
pub use crate::structs::token::GameFeeTerms;

/// Default game fee in basis points (500 = 5%).
pub const DEFAULT_GAME_FEE_BPS: u16 = 500;

/// Fee denominator for basis points (10_000 = 100%).
pub const FEE_DENOMINATOR: u16 = 10_000;

/// Default license text for the game-fee surface.
///
/// Deliberately fee-amount-free: the authoritative fee is the on-chain
/// `fee_numerator` (owner-rotatable via `set_game_fee`), so a number baked
/// into the text would go stale on the first fee change. The text points
/// consumers at the on-chain declaration instead and resolves both rate and
/// payee at time of payment.
pub fn default_license() -> ByteArray {
    "Embeddable Game Standard License v1.1. Monetization of this game requires payment of the game fee this contract declares on-chain, at the rate and to the game fee recipient in effect at the time of payment (game_fee_terms). Non-monetized integration, indexing, and display of this game are unrestricted."
}

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - game_fee_terms()->(ContractAddress,(Array<bytes31>,felt252,usize),u16)
///   0x20c5807da22bc9761d1c7ec0dcb7ffc708e90d756697f5a1440f7b24d061163
/// - game_fee_recipient()->ContractAddress
///   0x250cb6126e904ba7bcdc6f75a708a0e65255b0b08fdb353e130e1a16af98a5c
/// - set_game_fee_recipient(ContractAddress)
///   0x21cadbae1c0d69501e65651c352fe97ad44f9b12c638b8863befbda7bb3196d
/// - set_game_fee((Array<bytes31>,felt252,usize),u16)
///   0x3318144fd81873b0e256922d3972f42e61a473c6336dfcc2e9f2e8defdcf9e2
///
/// (Renamed from the creator surface: function renames change extended
/// selectors, so this VALUE differs from the retired
/// IMINIGAME_TOKEN_CREATOR_ID 0x21531c… — which no deployment registers.)
pub const IMINIGAME_TOKEN_GAME_FEE_ID: felt252 =
    0x171bf98e08ae98315df3e68477e24275ef5755111c1984db851c344b3907bb0;

#[starknet::interface]
pub trait IMinigameTokenGameFee<TState> {
    fn game_fee_terms(self: @TState) -> GameFeeTerms;
    fn game_fee_recipient(self: @TState) -> ContractAddress;
    /// Rotate the payee. Gated on the game contract's Ownable owner; the new
    /// address must be non-zero (rotation must never brick the payee).
    fn set_game_fee_recipient(ref self: TState, new_recipient: ContractAddress);
    /// Update the license text and fee. Gated on the game contract's Ownable
    /// owner; `fee_numerator` is in basis points, capped at `FEE_DENOMINATOR`.
    fn set_game_fee(ref self: TState, license: ByteArray, fee_numerator: u16);
}
