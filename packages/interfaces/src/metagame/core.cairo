// Core metagame interface
//
// DELIBERATELY EMPTY.
//
// `IMetagame` and `IMETAGAME_ID` were removed. A metagame is self-bound —
// the embedding contract IS the metagame — so the two views the trait carried
// no longer exist:
//
// * `default_token_address()` — every game brings its own token, resolved from
//   `game_address` on each mint.
// * `context_address()` — a metagame that provides context embeds
//   `ContextComponent` itself and registers `IMETAGAME_CONTEXT_ID` on its own
//   address. Nothing ever resolved a context provider through this view: the
//   legacy token takes context as a mint parameter.
//
// With no methods left, an SRC5 id could not be derived (the XOR of an empty
// selector set is degenerate), and nothing in the ecosystem probed the old
// `IMETAGAME_ID` (0x7997c74299c045696726f0f7f0165f85817acbb0964e23ff77e11e34eff6f2).
// Discover a metagame's capabilities through the surfaces that still carry
// meaning: `IMETAGAME_CONTEXT_ID` for a context provider and
// `IMETAGAME_CALLBACK_ID` for a legacy callback receiver.
