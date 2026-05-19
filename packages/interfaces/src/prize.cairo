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

/// Tagged union for the two prize lifecycles. Carries only the
/// variant-specific payload — common host-assigned metadata
/// (`id`, `context_id`, `sponsor_address`) lives on `PrizeRecord`.
/// Used as:
///   - input to `add_prize` (sponsor submits a Prize value; host
///     wraps with the assigned id / context_id / sponsor address)
///   - payload inside `PrizeRecord` returned by `get_prize`
///   - payload field of host events like `PrizeAdded`.
///
/// - `Token` — built-in ERC20/ERC721 flow. The host stores the
///   `token_address` + `token_type`.
/// - `Extension` — external `IPrizeExtension`. The host stores only
///   the `address`; the `config` blob is fetched dynamically from
///   the extension via `IPrizeExtension.get_config` on each
///   `get_prize` read.
#[derive(Drop, Serde)]
pub enum Prize {
    Token: TokenPrizePayload,
    Extension: ExtensionPrizePayload,
}

#[derive(Drop, Serde)]
pub struct TokenPrizePayload {
    pub token_address: ContractAddress,
    pub token_type: TokenTypeData,
}

#[derive(Drop, Serde)]
pub struct ExtensionPrizePayload {
    pub address: ContractAddress,
    pub config: Span<felt252>,
}

/// Full prize view returned by `IPrize.get_prize`. Combines the
/// host-assigned identity / context / sponsor metadata with the
/// variant-specific `Prize` payload. Same shape for built-in and
/// extension prizes — consumers branch on `record.prize` only when
/// they need the variant-specific data.
#[derive(Drop, Serde)]
pub struct PrizeRecord {
    pub id: u64,
    pub context_id: u64,
    pub sponsor_address: ContractAddress,
    pub prize: Prize,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Copy, Drop, Serde, PartialEq)]
pub enum PrizeType {
    Single: u64,
    Distributed: (u64, u32),
}

#[starknet::interface]
pub trait IPrize<TState> {
    /// Get a prize by its ID. Returns the full `PrizeRecord`
    /// (id + context_id + sponsor_address + the variant-specific
    /// `Prize` payload). For `Extension` prizes the payload's
    /// `config` blob is fetched live from the extension contract via
    /// `IPrizeExtension.get_config` (one cross-contract call per read).
    fn get_prize(self: @TState, prize_id: u64) -> PrizeRecord;

    /// Get total prizes count
    fn get_total_prizes(self: @TState) -> u64;

    /// Check if a prize has been claimed
    fn is_prize_claimed(self: @TState, context_id: u64, prize_type: PrizeType) -> bool;
}
