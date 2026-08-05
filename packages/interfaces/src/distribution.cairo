/// How a pool is split across paid places.
///
/// ## This enum is closed — do not add variants
///
/// The shape space is covered: flat (`Uniform`), linear, polynomial
/// (`Exponential`), scale-free decay (`Geometric`), headline-plus-tail
/// (`Tiered`), and arbitrary (`Custom`). Before reaching for variant #7:
///
/// - **A shape these can't express, with a fixed field?** Use `Custom` — it
///   encodes any curve exactly, up to its packed-storage ceiling. That is the
///   escape hatch; it removes the need for the enum to grow.
/// - **Anything involving external state** — dynamic payouts, oracle-driven
///   amounts, streaming, vesting? That is an integration, not a curve: use a
///   prize/entry-fee *extension*, which exists precisely for logic the host
///   cannot know about.
///
/// Every variant added here ripples through Serde (events, calldata,
/// indexers, SDKs, clients) and two packed-storage layouts, and costs
/// consumer-contract bytecode against Starknet's 81,920-felt class limit —
/// adding `Geometric` + `Tiered` cost Budokan ~3,000 felts, leaving it ~95%
/// full. Curves are core; integrations are extensions.
///
/// ## Choosing a variant
///
/// | you want | use | notes |
/// | --- | --- | --- |
/// | everyone equal | `Uniform` | cheapest |
/// | gentle gradient | `Linear(w)` | any weight |
/// | steeper gradient, small field | `Exponential(10*k)` | k in 1..=5; 1st ≈ (k+1)/n |
/// | "each place gets X% of the one above" | `Geometric(a, b)` | 1st ≈ 1 - b/a at any field size;
/// reach bounded by ratio |
/// | headline 1st prize AND thousands of paid places | `Tiered` | the only variant that serves a
/// very large field |
/// | exact hand-authored percentages | `Custom(shares)` | fixed field only |
#[derive(Drop, Copy, Serde, PartialEq)]
pub enum Distribution {
    Linear: u16,
    Exponential: u16,
    Uniform,
    Custom: Span<u16>,
    /// Geometric decay as a rational ratio `(a, b)`: each position receives
    /// `b / a` of the one above it, so `W(p) = a^(n-p) * b^(p-1)`. Requires
    /// `a > b > 0` — e.g. `(10, 7)` is "each place gets 70% of the previous".
    ///
    /// Unlike `Exponential` — which is a power law, and whose winner share
    /// falls off as roughly `(k+1)/n` — a geometric curve's shape does not
    /// depend on the size of the field: first place takes about `1 - b/a` of
    /// the pool whether there are 10 paid places or 100. That is the shape a
    /// headline first prize actually needs, and no `Exponential` weight
    /// produces it over a large field.
    ///
    /// The trade is reach: the weights span `(a/b)^n`, so the representable
    /// field size shrinks as the ratio gets finer. See
    /// `max_geometric_payouts`.
    ///
    /// NOTE: appended deliberately. Serde indices are positional, so inserting
    /// this anywhere earlier would silently reinterpret every stored and
    /// indexed distribution.
    Geometric: (u16, u16),
    /// Two tiers: a geometric head over the first `head_count` places taking
    /// `head_share_bps` of the pool, and the remaining places splitting the
    /// rest evenly.
    ///
    /// This is the only family here that works for a very large field. A
    /// single curve cannot: anything steep enough to give first place a real
    /// share rounds its tail to nothing, and anything flat enough to pay the
    /// tail gives first place nothing. Over 10,000 places the best a single
    /// curve can do for first place is ~0.06% (`Exponential` k=5); a
    /// `Geometric` head of 39 on (10, 7) taking 80% pays first place 24%,
    /// while every one of the other 9,961 places still receives its slice of
    /// the remaining 20%.
    ///
    /// The geometric reach bound applies to `head_count`, not the field, so
    /// the head is always well inside it. Requires a fixed paid-places count
    /// strictly greater than `head_count`.
    Tiered: TieredConfig,
}

/// Configuration for `Distribution::Tiered`.
#[derive(Drop, Copy, Serde, PartialEq)]
pub struct TieredConfig {
    /// Geometric decay `(a, b)` for the head: each place gets `b / a` of the
    /// one above. Same semantics and validity rules as `Geometric`.
    pub head_ratio: (u16, u16),
    /// How many places the head covers. Must be under the paid-places count
    /// and within `max_geometric_payouts(a)`.
    pub head_count: u16,
    /// The head's slice of the pool, in basis points. Strictly between 0 and
    /// 10000 — at either extreme one of the tiers would round to an
    /// unclaimable zero, and the single-curve variants cover those shapes.
    pub head_share_bps: u16,
}
