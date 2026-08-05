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
