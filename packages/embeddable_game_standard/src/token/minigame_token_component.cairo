/// # MinigameTokenComponent
///
/// THE minigame token standard: single-game, storage-minimal ERC721 embedded
/// in the game contract, built for deployments (e.g. death-mountain-style
/// dungeons) that never used the multi-game registry, objective-completion
/// machinery, skills or per-token renderers, and that keep game-over /
/// objective completion authority in the game contract itself. The original
/// multi-game token (`token_legacy::CoreTokenComponent`) is kept as-is for
/// deployed denshokan.
///
/// **Self-binding only (one-address architecture):** this component is
/// embedded IN the game contract — the game contract IS the token. A
/// separate-token deployment shape existed briefly and was removed after
/// measurements showed it strictly worse on gas; with self-binding the
/// game/token mutual-pairing story is trivial (self == self), advertised to
/// ecosystem consumers via SRC5 (`IMINIGAME_TOKEN_ID`) rather than
/// through address-resolution views.
///
/// The external ABI is `IMinigameToken`: dead MACHINERY and compat shims
/// are deleted, CAPABILITY (writes) and cheap client-facing read views stay.
/// What is gone, and why:
/// * **Registry / game-address views** — one game: this contract. Consumers
///   SRC5-probe `IMINIGAME_TOKEN_ID`; there is nothing to resolve.
/// * **Guards (`assert_is_playable`, `assert_owner_and_playable`)** — the
///   embedding game's own pre-action checks, now `InternalTrait` calls with
///   zero syscalls. Clients read `is_playable`.
/// * **`refresh_metadata_batch`** — a multicall of singles.
/// * **Mutable token state** — no `game_over`/`completed_objective` latch,
///   no `update_game`, no metagame callbacks. `refresh_metadata` (ERC-4906)
///   is the only post-action hook; `player_name` (owner-renameable via
///   `update_player_name`) and the mint-time `client_url` are the only
///   per-token storage.
///
/// Mint parameters carry their original legacy-token behaviors: `objective_id`,
/// `paymaster` and the (65-bit, u128) `metadata` are packed into the id as
/// inert data the game interprets; `context` sets the id's has_context bit
/// only (the data is NOT stored — legacy-token parity); `client_url` is
/// storage-backed with a `client_url` view.
///
/// The minter registry is standard, not optional: absorbed into this
/// component (storage names, `IMinigameTokenMinter` surface and
/// `MinterRegistryUpdate` event identical to the legacy MinterComponent's).
///
/// Token ids use the standard's 251-bit layout in `token::packing` — NOT the
/// legacy token's `token_legacy::structs::pack_token_id` layout (which stays
/// untouched, serving legacy denshokan). Indexers must branch their token-id
/// decoder by contract generation.
#[starknet::component]
pub mod MinigameTokenComponent {
    use core::num::traits::Zero;
    use game_components_interfaces::structs::metagame::GameContextDetails;
    use game_components_interfaces::token::core::{IMINIGAME_TOKEN_ID, IMinigameToken};
    use game_components_interfaces::token::minter::{
        IMINIGAME_TOKEN_MINTER_ID, IMinigameTokenMinter,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::InternalTrait as ERC721InternalTrait;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_tx_info};
    use crate::token::packing::{
        extract_tx_hash_bits, pack_token_id, to_token_metadata, unpack_metadata, unpack_minted_by,
        unpack_objective_id, unpack_settings_id, unpack_soulbound, unpack_token_id,
    };
    use crate::token_legacy::structs::{MintBatchRecipient, TokenMetadata};
    use crate::token_legacy::token::{LifecycleTrait, token_state};

    #[storage]
    pub struct Storage {
        token_player_names: Map<felt252, felt252>,
        token_client_url: Map<felt252, ByteArray>,
        // Absorbed minter registry. The variable names are EXACTLY those of the
        // legacy MinterComponent — Starknet storage addresses derive from these
        // names, so contracts that embedded MinterComponent keep their minter
        // storage compatible under the absorbed impl.
        minter_counter: u64,
        minter_addresses: Map<u64, ContractAddress>,
        minter_id_by_address: Map<ContractAddress, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MetadataUpdate: MetadataUpdate,
        MinterRegistryUpdate: MinterRegistryUpdate,
    }

    /// ERC-4906 standard metadata update event
    #[derive(Drop, starknet::Event)]
    pub struct MetadataUpdate {
        #[key]
        pub token_id: u256,
    }

    /// Emitted when a new minter is registered (absorbed from the legacy
    /// MinterComponent — same shape).
    #[derive(Drop, starknet::Event)]
    pub struct MinterRegistryUpdate {
        #[key]
        pub minter_id: u64,
        pub minter_address: ContractAddress,
    }

    #[embeddable_as(MinigameTokenImpl)]
    pub impl MinigameToken<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
    > of IMinigameToken<ComponentState<TContractState>> {
        fn token_metadata(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> TokenMetadata {
            // No mutable state exists; the game contract is authoritative for
            // game_over / objective completion — the returned metadata reports
            // game_over/completed_objective/completed_at as false/0 always.
            // Its u16 `metadata` field is 0 (never a truncation): the token id
            // packs 65 bits — read them via `mint_metadata`.
            to_token_metadata(unpack_token_id(token_id))
        }

        fn is_playable(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            let metadata = self.token_metadata(token_id);
            metadata.lifecycle.is_playable(get_block_timestamp())
        }

        fn settings_id(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            unpack_settings_id(token_id)
        }

        fn player_name(self: @ComponentState<TContractState>, token_id: felt252) -> felt252 {
            self.token_player_names.entry(token_id).read()
        }

        fn minted_by(self: @ComponentState<TContractState>, token_id: felt252) -> felt252 {
            let minted_by_val: u64 = unpack_minted_by(token_id);
            minted_by_val.into()
        }

        fn minted_by_address(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> ContractAddress {
            let minted_by_id: u64 = unpack_minted_by(token_id);
            self.minter_addresses.entry(minted_by_id).read()
        }

        fn is_soulbound(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            unpack_soulbound(token_id)
        }

        fn objective_id(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            unpack_objective_id(token_id)
        }

        fn client_url(self: @ComponentState<TContractState>, token_id: felt252) -> ByteArray {
            self.token_client_url.entry(token_id).read()
        }

        fn mint_metadata(self: @ComponentState<TContractState>, token_id: felt252) -> u128 {
            unpack_metadata(token_id)
        }

        fn mint(
            ref self: ComponentState<TContractState>,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            to: ContractAddress,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u128,
        ) -> felt252 {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Same lifecycle rules as CoreTokenComponent::mint_game: a
            // non-zero end must be in the future and after start (end_delay 0
            // means "no expiration", so a past window must not collapse into
            // an immortal token), and a start at or before now clamps to now
            // so the packed delays reconstruct the caller's intended end.
            let lifecycle = token_state::create_lifecycle_with_defaults(start, end);
            lifecycle.validate();
            assert!(
                lifecycle.end == 0
                    || (lifecycle.end > current_time && lifecycle.end > lifecycle.start),
                "MinigameToken: Lifecycle end must be in the future and after start",
            );
            let effective_start = if lifecycle.start > current_time {
                lifecycle.start
            } else {
                current_time
            };
            let start_delay: u32 = (effective_start - current_time).try_into().unwrap();
            let end_delay: u32 = if lifecycle.end > effective_start {
                (lifecycle.end - effective_start).try_into().unwrap()
            } else {
                0
            };

            let tx_hash_bits = extract_tx_hash_bits(get_tx_info().unbox().transaction_hash);

            let minted_by = self.add_minter(caller);

            // settings_id keeps its Option<u32> call-site type; the pack
            // asserts the value fits the id layout's 16-bit field. Likewise
            // minted_by (u64 from add_minter) must fit 26
            // bits, objective_id 30 bits and metadata 65 bits. context sets
            // the has_context bit only — the data itself is NOT stored
            // (legacy-token parity: its context hook was a documented no-op).
            let final_token_id = pack_token_id(
                current_time,
                start_delay,
                end_delay,
                settings_id.unwrap_or(0),
                minted_by,
                soulbound,
                tx_hash_bits,
                salt,
                paymaster,
                context.is_some(),
                objective_id.unwrap_or(0),
                metadata,
            );

            if let Option::Some(name) = player_name {
                self.token_player_names.entry(final_token_id).write(name);
            }
            if let Option::Some(url) = client_url {
                self.token_client_url.entry(final_token_id).write(url);
            }

            let mut contract = self.get_contract_mut();
            let mut erc721_component = ERC721::get_component_mut(ref contract);
            erc721_component.mint(to, final_token_id.into());

            final_token_id
        }

        /// Batch mint identical tokens to one or more recipients with
        /// per-recipient counts.
        ///
        /// Salt is a single global counter across the batch (`salt + i` for
        /// `i in 0..sum(counts)`): token ids do not encode the recipient, so
        /// salts must be globally unique within the tx —
        /// `salt + sum(counts) - 1 <= 0xFFFF` (the id layout's 16-bit field).
        ///
        /// Versus calling `mint` per token, the lifecycle math, tx-info read
        /// and minter registration are hoisted and paid once for the batch.
        fn mint_batch_recipients(
            ref self: ComponentState<TContractState>,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            recipients: Array<MintBatchRecipient>,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u128,
        ) -> Array<felt252> {
            let recipient_count = recipients.len();
            assert!(recipient_count > 0, "MinigameToken: recipients array cannot be empty");

            // Sum per-recipient counts and bound the global salt counter.
            let mut total_tokens: u32 = 0;
            let mut sum_idx: u32 = 0;
            while sum_idx < recipient_count {
                let r: @MintBatchRecipient = recipients.at(sum_idx);
                let c: u16 = *r.count;
                assert!(c > 0, "MinigameToken: per-recipient count must be > 0");
                total_tokens += c.into();
                sum_idx += 1;
            }
            let max_salt: u32 = salt.into() + total_tokens - 1;
            assert!(
                max_salt <= 0xFFFF,
                "MinigameToken: salt overflow (salt + total tokens - 1 must be <= 65535)",
            );

            // Hoisted per-batch work: lifecycle math (same rules and rationale as
            // `mint`), tx-hash bits, minter registration.
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            let lifecycle = token_state::create_lifecycle_with_defaults(start, end);
            lifecycle.validate();
            assert!(
                lifecycle.end == 0
                    || (lifecycle.end > current_time && lifecycle.end > lifecycle.start),
                "MinigameToken: Lifecycle end must be in the future and after start",
            );
            let effective_start = if lifecycle.start > current_time {
                lifecycle.start
            } else {
                current_time
            };
            let start_delay: u32 = (effective_start - current_time).try_into().unwrap();
            let end_delay: u32 = if lifecycle.end > effective_start {
                (lifecycle.end - effective_start).try_into().unwrap()
            } else {
                0
            };

            let tx_hash_bits = extract_tx_hash_bits(get_tx_info().unbox().transaction_hash);

            let minted_by = self.add_minter(caller);
            let validated_settings_id = settings_id.unwrap_or(0);
            let validated_objective_id = objective_id.unwrap_or(0);
            // Shared has_context bit for all minted tokens; the context data
            // itself is NOT stored (legacy-token parity).
            let has_context = context.is_some();

            // Per-token work: pack, optional name/url writes, ERC721 mint.
            let mut token_ids: Array<felt252> = ArrayTrait::new();
            let mut salt_offset: u16 = 0;
            let mut r_idx: u32 = 0;
            while r_idx < recipient_count {
                let r: @MintBatchRecipient = recipients.at(r_idx);
                let to: ContractAddress = *r.to;
                let count: u16 = *r.count;

                let mut k: u16 = 0;
                while k < count {
                    let final_token_id = pack_token_id(
                        current_time,
                        start_delay,
                        end_delay,
                        validated_settings_id,
                        minted_by,
                        soulbound,
                        tx_hash_bits,
                        salt + salt_offset,
                        paymaster,
                        has_context,
                        validated_objective_id,
                        metadata,
                    );

                    if let Option::Some(name) = player_name {
                        self.token_player_names.entry(final_token_id).write(name);
                    }
                    match @client_url {
                        Option::Some(url) => {
                            self.token_client_url.entry(final_token_id).write(url.clone());
                        },
                        Option::None => {},
                    }

                    let mut contract = self.get_contract_mut();
                    let mut erc721_component = ERC721::get_component_mut(ref contract);
                    erc721_component.mint(to, final_token_id.into());

                    token_ids.append(final_token_id);
                    salt_offset += 1;
                    k += 1;
                }
                r_idx += 1;
            }

            token_ids
        }

        /// Emits an ERC-4906 `MetadataUpdate` without touching state. Same
        /// deliberate no-existence-check trade-off as
        /// `CoreTokenComponent::refresh_metadata`: the event is advisory,
        /// consumers resolve token ids against their own mint records, and
        /// the check would cost ~52k gas on the cheap path without stopping
        /// spam anyway.
        fn refresh_metadata(ref self: ComponentState<TContractState>, token_id: felt252) {
            self.emit(MetadataUpdate { token_id: token_id.into() });
        }

        fn update_player_name(
            ref self: ComponentState<TContractState>, token_id: felt252, name: felt252,
        ) {
            assert!(!name.is_zero(), "MinigameToken: Player name is empty");
            let contract = self.get_contract();
            let erc721_component = ERC721::get_component(contract);
            let token_owner = erc721_component._owner_of(token_id.into());
            assert!(
                token_owner == get_caller_address(), "MinigameToken: Caller is not owner of token",
            );
            self.token_player_names.entry(token_id).write(name);
            self.emit(MetadataUpdate { token_id: token_id.into() });
        }
    }

    /// The minter registry is standard, not optional: absorbed from the legacy
    /// MinterComponent (same `IMinigameTokenMinter` interface and
    /// `IMINIGAME_TOKEN_MINTER_ID`, same storage variable names, same
    /// `MinterRegistryUpdate` event). Minter ids gate reward claims in
    /// consumers; `OptionalMinter` indirection remains only in `token_legacy`.
    #[embeddable_as(MinterImpl)]
    pub impl Minter<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IMinigameTokenMinter<ComponentState<TContractState>> {
        fn get_minter_address(
            self: @ComponentState<TContractState>, minter_id: u64,
        ) -> ContractAddress {
            self.minter_addresses.entry(minter_id).read()
        }

        fn get_minter_id(
            self: @ComponentState<TContractState>, minter_address: ContractAddress,
        ) -> u64 {
            self.minter_id_by_address.entry(minter_address).read()
        }

        fn minter_exists(
            self: @ComponentState<TContractState>, minter_address: ContractAddress,
        ) -> bool {
            self.minter_id_by_address.entry(minter_address).read() != 0
        }

        fn total_minters(self: @ComponentState<TContractState>) -> u64 {
            self.minter_counter.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
    > of InternalTrait<TContractState> {
        /// Returns the caller's minter id, registering the caller (and
        /// emitting `MinterRegistryUpdate`) on first sight — identical
        /// semantics to the legacy MinterComponent's `add_minter`.
        fn add_minter(ref self: ComponentState<TContractState>, minter: ContractAddress) -> u64 {
            // Existing minter short-circuits with its id
            let existing_id = self.minter_id_by_address.entry(minter).read();
            if existing_id != 0 {
                return existing_id;
            }

            // Register new minter
            let minter_id = self.minter_counter.read() + 1;
            self.minter_addresses.entry(minter_id).write(minter);
            self.minter_id_by_address.entry(minter).write(minter_id);
            self.minter_counter.write(minter_id);

            self.emit(MinterRegistryUpdate { minter_id, minter_address: minter });

            minter_id
        }

        /// Registers the SRC5 interface ids: `IMINIGAME_TOKEN_ID` and the
        /// absorbed minter's `IMINIGAME_TOKEN_MINTER_ID`. There is no game
        /// argument — the component is self-bound: the embedding contract is
        /// the game. The legacy id is NOT registered; SRC5 is honest about
        /// the surface (this token does NOT implement `IMinigameTokenLegacy`).
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut contract = self.get_contract_mut();
            let mut src5_component = SRC5::get_component_mut(ref contract);
            src5_component.register_interface(IMINIGAME_TOKEN_ID);
            // The absorbed minter registry keeps its own discovery id
            // (matching what the legacy MinterComponent::initializer did).
            src5_component.register_interface(IMINIGAME_TOKEN_MINTER_ID);
        }

        /// Combined ownership + playability guard for the embedding game's
        /// own entrypoints: internal call, zero syscalls. `expected_owner` is
        /// the game contract's caller (must be non-zero); panics unless it
        /// owns the token and the lifecycle window is open.
        fn assert_owner_and_playable(
            self: @ComponentState<TContractState>,
            token_id: felt252,
            expected_owner: ContractAddress,
        ) {
            assert!(!expected_owner.is_zero(), "MinigameToken: Expected owner cannot be zero");
            let contract = self.get_contract();
            let erc721_component = ERC721::get_component(contract);
            // _owner_of returns zero for a nonexistent token, which can never
            // equal the asserted-non-zero expected_owner — so this also
            // guarantees existence.
            let token_owner = erc721_component._owner_of(token_id.into());
            assert!(
                token_owner == expected_owner,
                "MinigameToken: Address is not owner of token {}",
                token_id,
            );
            self.assert_lifecycle_open(token_id);
        }

        /// Lifecycle-window check only — there is deliberately no token-side
        /// game_over / completed_objective state to consult. Games gate dead
        /// runs themselves; they are the source of truth.
        fn assert_lifecycle_open(self: @ComponentState<TContractState>, token_id: felt252) {
            let metadata = to_token_metadata(unpack_token_id(token_id));
            let current_time = get_block_timestamp();
            let lifecycle = metadata.lifecycle;
            assert!(
                lifecycle.can_start(current_time),
                "MinigameToken: Token is not playable - game has not started (now={}, start={})",
                current_time,
                lifecycle.start,
            );
            assert!(
                !lifecycle.has_expired(current_time),
                "MinigameToken: Token is not playable - game has expired (now={}, end={})",
                current_time,
                lifecycle.end,
            );
        }
    }
}
