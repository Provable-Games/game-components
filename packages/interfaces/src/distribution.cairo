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
}
