# Host-owned leaderboard and entry-requirement storage

An application can use the shared metagame APIs and algorithms with its own
storage. It does not need to embed either component or maintain a separate copy
of their interface implementations. The standard components remain available
with their existing storage layout, embedded aliases and admin interfaces.

The separation is:

- `Store<T>` describes reads and writes, independently of a Starknet component.
- `leaderboard::api::Configuration<T>` supplies leaderboard configuration.
- `api` modules implement public views and internal mutations using those traits.
- `storage_adapter` modules optionally forward storage to existing components.

This can reduce creation writes when the host already stores the configuration
or can derive it. Using an adapter alone does not reduce storage gas. Packing,
eliding redundant writes and preserving invariants remain host responsibilities.

## Use only application storage

Implement `leaderboard::store::Store<ContractState>` and
`leaderboard::api::Configuration<ContractState>`, then embed the shared views:

```cairo
#[abi(embed_v0)]
impl LeaderboardViews =
    game_components_metagame::leaderboard::api::LeaderboardImpl<ContractState>;
```

For score submission also implement `leaderboard::hooks::LeaderboardHooksTrait`
and import `LeaderboardInternalImpl` and `LeaderboardInternalTrait` from `api`.
After the host checks authorization, game ownership, eligibility and phase:

```cairo
let result = LeaderboardInternalTrait::submit_score(
    ref self, context_id, token_id, score, position,
);
```

The existing sorting, neighbor checks, duplicate detection and mint-block tie
ordering are reused. Positions passed to submission and public views are
1-indexed; positions used by `Store` are 0-indexed. `on_score_submitted` fires
only on `Success`. Other hooks belong to the host's configuration/admin paths.
Game address zero selects stored scores; a nonzero address selects live game
scores for public entry views, as in the standard component.

For entry requirements implement `entry_requirement::store::Store<ContractState>`:

```cairo
#[abi(embed_v0)]
impl RequirementViews =
    game_components_metagame::entry_requirement::api::EntryRequirementImpl<ContractState>;
```

Import `EntryRequirementInternalImpl` and `EntryRequirementInternalTrait` from
`entry_requirement::api` for the validated internal setter:

```cairo
EntryRequirementInternalTrait::set_entry_requirement(
    ref self, context_id, requirement,
);
```

The setter checks SRC5 support and rejects a zero extension address before
writing. It does not grant callers permission to configure a context or call
an extension's `add_config`; those remain the host's responsibility. Qualification
validation and counters use the existing `EntryRequirementStoreTrait`. Token
gates verify ownership; extension gates delegate eligibility and any limit to
the extension. When a claimed qualifier is supplied, the extension must verify
that claim. Do not expose these internal methods without the application's checks.

Extension configuration spans are not stored here: extension contracts own that
data. Requirement views return the stored extension address and an empty span,
matching the standard component. Clearing a requirement does not erase its
qualification history.

Complete compiling examples using custom maps, with no components, are
[`HostLeaderboard`](src/leaderboard/tests/test_host_storage.cairo) and
[`HostRequirement`](src/entry_requirement/tests/test_host_storage.cairo). Their
configuration and mutation entrypoints are test scaffolding, not production
access-control examples.

## Retain component maps, customize configuration

For existing deployments keep the original `component!`, substorage fields and
event declarations. A leaderboard adapter retains all entry, score and position
maps while the host implements the configuration provider:

```cairo
impl LeaderboardStorage =
    game_components_metagame::leaderboard::storage_adapter::ComponentStore<ContractState>;
#[abi(embed_v0)]
impl LeaderboardViews =
    game_components_metagame::leaderboard::api::LeaderboardImpl<ContractState>;
```

For entry requirements implement `storage_adapter::Metadata<ContractState>`
with the host's metadata reads/writes and select that implementation explicitly:

```cairo
impl RequirementStorage =
    game_components_metagame::entry_requirement::storage_adapter::ComponentStore<
        ContractState, _, MyMetadataImpl,
    >;
#[abi(embed_v0)]
impl RequirementViews =
    game_components_metagame::entry_requirement::api::EntryRequirementImpl<ContractState>;
```

This retains token addresses, extension addresses and qualification counts in
the component maps. To retain its metadata map too, use
`storage_adapter::ComponentMetadata<ContractState>` as `MyMetadataImpl`.
Compiling adapter examples appear in the same two test files.

Embed either the original component views or the shared host views for each
interface, rather than both. Keep the existing component's initialization and
SRC5 registration when retaining its storage. A host without components must
provide any required SRC5 registration itself. Shared internal submission fires
the host hook, so it must not emit the same event a second time manually.

An upgrade may choose a version marker: old contexts read original component
configuration; new contexts read packed host configuration. Route both views
and mutations through the same adapters. Preserve old map names and substorage
paths, and ensure a rollback class understands any new encoding. The library
does not move existing storage or automatically migrate records.

## Verification

The standard component tests exercise the default path. `test_host_storage`
tests exercise custom packed configuration, independent contexts, both ranking
orders, hooks, qualification limits, ownership rejection and component map
adapters. Run them with:

```sh
snforge test -p game_components_metagame
snforge test -p game_components_metagame test_host_storage
```
