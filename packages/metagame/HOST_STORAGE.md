# Host-owned metagame storage

An application can use the shared metagame APIs and algorithms with its own
storage. It does not need to embed a component or maintain a separate copy
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
Configuration providers may override `leaderboard_game_address` and
`leaderboard_max_entries` to avoid reading unused configuration fields in entry
views and capacity checks. Their defaults derive values from `leaderboard_config`;
the standard component overrides both to retain its original single-slot reads.

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

## Registration, entry fees and prizes

The same separation is available for all five metagame modules:

| Module | Shared views | Shared internal operations | Optional original-map adapter |
| --- | --- | --- | --- |
| `leaderboard` | `api::LeaderboardImpl` | `api::LeaderboardInternalImpl` | `storage_adapter::ComponentStore` |
| `entry_requirement` | `api::EntryRequirementImpl` | `api::EntryRequirementInternalImpl` | `storage_adapter::ComponentStore` |
| `registration` | `api::RegistrationImpl` | `api::RegistrationInternalImpl` | `storage_adapter::ComponentStore` |
| `entry_fee` | `api::EntryFeeImpl` | `api::EntryFeeInternalImpl` | `storage_adapter::ComponentStore` |
| `prize` | `api::PrizeImpl` | `api::PrizeInternalImpl` | `storage_adapter::ComponentStore` |

For each module, implement `store::Store<ContractState>` and embed its shared
views. Import the module's generated internal trait and implementation, or call
its internal implementation explicitly when multiple modules have overlapping
helper names. Existing standard components delegate to these same APIs; their
storage declarations, public signatures, embedded aliases, initializers and
SRC5 registration remain unchanged.

For example, an application that keeps the original registration maps can use:

```cairo
component!(path: RegistrationComponent, storage: registration, event: RegistrationEvent);
impl RegistrationStorage =
    game_components_metagame::registration::storage_adapter::ComponentStore<ContractState>;
#[abi(embed_v0)]
impl RegistrationViews =
    game_components_metagame::registration::api::RegistrationImpl<ContractState>;
```

Alternatively, implement `registration::store::Store<ContractState>` against
application maps and omit `RegistrationComponent` entirely. This applies equally
to entry fees and prizes. The independent contracts in
`src/registration/tests/host_fixtures.cairo` and
`src/prize/tests/host_fixtures.cairo` are compiling examples of this approach;
they also include matching component-backed adapters.

### Combining storage across modules

`Store<T>` describes logical fields, not a required physical layout. A host can
implement multiple store traits against one packed map. It may also forward
individual fields through `storage_adapter::ComponentStore` using explicit
implementation calls, while storing the remaining fields itself. When defining
a custom `Store` implementation, do not also bind the full component adapter as
a second `Store` implementation in the same scope.

The registration/fee example stores these fields together, keyed by the same
`(context_id, token_id)` pair:

- bits 0–63: registration context;
- bit 64: score submitted;
- bit 65: banned;
- bit 66: fee refund claimed.

Registration reads mask out the refund bit before passing state to the shared
registration decoders. Registration writes preserve the refund bit; fee writes
preserve all registration fields. In particular, replacing a registration entry
clears the displaced token's registration state but **retains its fee claim
history**. Retaining this history prevents a storage update from enabling a
second refund. Contexts remain isolated even when they contain the same token ID.

The prize example combines extension context (64 bits), custom-share count
(32 bits) and payout position (32 bits) into one application metadata slot.
Each setter preserves the other fields, including at maximum integer values.
This demonstrates flexibility; it does not imply that every prize needs all
three fields or that packing them always saves a write.

Do not concatenate packed formats without checking their full supported ranges.
Entry-fee data uses 165 bits; the current distribution format can use 88 bits
with Tiered parameters. Their combined 253 bits cannot fit in one felt. Addresses
also require their own capacity. Apps may derive or specialize fields only when
their supported configurations and invariants make that valid.

### Internal operations and host responsibilities

The new internal APIs preserve existing validation, revert messages, token
transfers, extension dispatch and claim bookkeeping. They are not externally
embedded. The application must enforce authorization, tournament phase,
registration eligibility, correct deposit/configuration selection, entitlement,
claim-before-transfer ordering and reentrancy protection. A payout/refund helper
alone does not verify entitlement or mark the corresponding claim.

For deployed applications, keep old maps readable. A new host packing layout
needs an explicit version discriminator or a migration; adding a generic API
does not migrate any data. All original component maps retain their names and
types in this change. Public token-owner payout behavior is unchanged.

### Measured packing example

The matched `entry_fee_host_storage_gas_combined` and
`entry_fee_host_storage_gas_separate` tests deploy the fixture, register one game,
mark its score submitted and mark its fee refund claimed. They use the same
shared APIs with either combined application state or separate component maps.
This isolates a packing opportunity rather than measuring a complete tournament,
account validation or a charged network fee. See the benchmark results below.

| Fixture | L2 gas | L1 data gas | Distinct changed data slots |
| --- | ---: | ---: | ---: |
| Separate component maps | 2,373,361 | 384 | 3 |
| Combined application map | 2,166,402 | 288 | 2 |

This sequence saves **8.72% L2 gas** and **25% L1 data gas**.
Both paths make four storage-write syscalls; packing reduces the number of
distinct slots changed, rather than the number of setter calls. The combined
store performs extra reads and bit manipulation, already included in these
measurements. Other workloads can have different tradeoffs.

Measured with Scarb 2.20.1 and snforge 0.63.0 in the dev profile, without account
validation. Reproduce with:

```bash
snforge test -p game_components_metagame entry_fee_host_storage_gas --max-threads 1
```
