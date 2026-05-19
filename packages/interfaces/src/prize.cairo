use game_components_interfaces::distribution::Distribution;
use starknet::ContractAddress;

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - get_prize(u64)->Prize
/// - get_total_prizes()->u64
/// - is_prize_claimed(u64,PrizeType)->E((),())
///
/// NOTE: this ID needs regeneration after the Prize sum-type rename
/// (Config -> Token) and the PrizeData removal. Run `src5_rs` against
/// the current trait to regenerate; the value below is stale until then.
pub const IPRIZE_ID: felt252 = 0x2a7a3be3dafc2154ab2780a63f0457adc535ad295bc44ce46cc3fbb11019641;

#[derive(Drop, Serde)]
pub struct ERC20Data {
    pub amount: u128,
    pub distribution: Option<Distribution>,
    pub distribution_count: Option<u32>,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ERC721Data {
    pub id: u128,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde)]
pub enum TokenTypeData {
    erc20: ERC20Data,
    erc721: ERC721Data,
}

/// Tagged union for the two prize lifecycles. Used both as input to
/// `add_prize` (sponsor passes host-assigned fields as zero — the host
/// overwrites them with the real id / sponsor) AND as output from
/// `get_prize` (fully populated).
///
/// - `Token` — built-in ERC20/ERC721 flow. The host stores the
///   `token_address` + `token_type` and tracks `id`/`context_id`/
///   `sponsor_address`.
/// - `Extension` — external `IPrizeExtension`. The host stores only
///   the `address` and the `id`/`context_id` mapping; the `config`
///   blob is fetched dynamically from the extension via
///   `IPrizeExtension.get_config` on each `get_prize` read.
#[derive(Drop, Serde)]
pub enum Prize {
    Token: TokenPrize,
    Extension: ExtensionPrize,
}

/// Built-in token-prize variant payload. `id`, `context_id` and
/// `sponsor_address` are set by the host at `add_prize` time (input
/// values are ignored). Sponsors building calldata should pass these
/// as zero.
#[derive(Drop, Serde)]
pub struct TokenPrize {
    pub id: u64,
    pub context_id: u64,
    pub sponsor_address: ContractAddress,
    pub token_address: ContractAddress,
    pub token_type: TokenTypeData,
}

/// Extension-prize variant payload. `id` and `context_id` are set by
/// the host at `add_prize` time (input values are ignored). Sponsors
/// building calldata should pass these as zero. Note there is no
/// `sponsor_address` — extension prizes don't track a host-side
/// sponsor (the extension contract is the authoritative owner).
#[derive(Drop, Serde)]
pub struct ExtensionPrize {
    pub id: u64,
    pub context_id: u64,
    pub address: ContractAddress,
    pub config: Span<felt252>,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Copy, Drop, Serde, PartialEq)]
pub enum PrizeType {
    Single: u64,
    Distributed: (u64, u32),
}

#[starknet::interface]
pub trait IPrize<TState> {
    /// Get a prize by its ID. Returns the full `Prize` sum type with
    /// all host-assigned and payload fields populated. For `Extension`
    /// prizes the `config` blob is fetched live from the extension
    /// contract via `IPrizeExtension.get_config` (one cross-contract
    /// call per read).
    fn get_prize(self: @TState, prize_id: u64) -> Prize;

    /// Get total prizes count
    fn get_total_prizes(self: @TState) -> u64;

    /// Check if a prize has been claimed
    fn is_prize_claimed(self: @TState, context_id: u64, prize_type: PrizeType) -> bool;
}
