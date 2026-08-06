/// # CoreTokenLiteComponent
///
/// Single-game, storage-minimal variant of `CoreTokenComponent`, built for
/// deployments (e.g. death-mountain-style dungeons) that never used the
/// multi-game registry, objectives, context, skills, per-token renderers or
/// client urls, and that keep game-over / objective completion authority in
/// the game contract itself.
///
/// What is deliberately gone, and why it is safe to remove:
/// * **Registry** — one game, stored once in `game_address`. No
///   `game_id_from_address` on mint, no `game_address_from_id` anywhere.
/// * **Mutable token state** — no `game_over`/`completed_objective` latch.
///   The game contract is the sole authority; playability here is the
///   lifecycle window only, which lives packed inside the token id, so
///   `is_playable` costs zero storage reads.
/// * **`update_game` + metagame callbacks** — nothing to sync and nobody to
///   notify. `refresh_metadata` (ERC-4906) is the only post-action hook.
/// * **SRC5 round-trips** — the game address is trusted at initialization;
///   mint performs no `supports_interface` calls.
/// * **Settings/objective validation on mint** — minters pass an
///   admin-configured `settings_id`; the game validates it at play time.
///
/// What is kept bit-identical: the 251-bit `pack_token_id` layout. Existing
/// integrations unpack `settings_id`/`minted_by`/lifecycle from the id and
/// indexers decode it; the lite token writes zeros into `game_id`,
/// `objective_id`, `has_context`, `paymaster` and `metadata` rather than
/// reshuffling bits.
#[starknet::component]
pub mod CoreTokenLiteComponent {
    use core::num::traits::Zero;
    use game_components_interfaces::token::lite::{IMINIGAME_TOKEN_LITE_ID, IMinigameTokenLite};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::InternalTrait as ERC721InternalTrait;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_tx_info};
    use crate::token::interface::IMINIGAME_TOKEN_ID;
    use crate::token::structs::{
        GameContextDetails, MintBatchRecipient, TokenMetadata, TokenMutableState,
        extract_tx_hash_bits, pack_token_id, to_token_metadata, unpack_minted_by,
        unpack_settings_id, unpack_soulbound, unpack_token_id,
    };
    use crate::token::token::{LifecycleTrait, token_state};
    use crate::token::traits::OptionalMinter;

    #[storage]
    pub struct Storage {
        game_address: ContractAddress,
        token_player_names: Map<felt252, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MetadataUpdate: MetadataUpdate,
    }

    /// ERC-4906 standard metadata update event
    #[derive(Drop, starknet::Event)]
    pub struct MetadataUpdate {
        #[key]
        pub token_id: u256,
    }

    #[embeddable_as(CoreTokenLiteImpl)]
    pub impl CoreTokenLite<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl MinterOpt: OptionalMinter<TContractState>,
        +Drop<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
    > of IMinigameTokenLite<ComponentState<TContractState>> {
        fn token_metadata(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> TokenMetadata {
            let packed = unpack_token_id(token_id);
            // No mutable state exists; the game contract is authoritative for
            // game_over / objective completion.
            let empty_state = TokenMutableState {
                game_over: false, completed_objective: false, completed_at: 0,
            };
            to_token_metadata(packed, empty_state)
        }

        fn is_playable(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            let metadata = self.token_metadata(token_id);
            metadata.lifecycle.is_playable(get_block_timestamp())
        }

        fn assert_is_playable(self: @ComponentState<TContractState>, token_id: felt252) {
            self.assert_lifecycle_open(token_id);
        }

        fn assert_owner_and_playable(
            self: @ComponentState<TContractState>,
            token_id: felt252,
            expected_owner: ContractAddress,
        ) {
            assert!(!expected_owner.is_zero(), "MinigameTokenLite: Expected owner cannot be zero");
            let contract = self.get_contract();
            let erc721_component = ERC721::get_component(contract);
            // _owner_of returns zero for a nonexistent token, which can never
            // equal the asserted-non-zero expected_owner — so this also
            // guarantees existence.
            let token_owner = erc721_component._owner_of(token_id.into());
            assert!(
                token_owner == expected_owner,
                "MinigameTokenLite: Address is not owner of token {}",
                token_id,
            );
            self.assert_lifecycle_open(token_id);
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
            let contract_ref = self.get_contract();
            MinterOpt::get_minter_address(contract_ref, minted_by_id)
        }

        fn is_soulbound(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            unpack_soulbound(token_id)
        }

        fn game_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.game_address.read()
        }

        fn game_registry_address(self: @ComponentState<TContractState>) -> ContractAddress {
            // Compat shim: MinigameComponent::initializer queries this before
            // deciding whether to register with a registry. Zero = no registry.
            Zero::zero()
        }

        fn mint(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> felt252 {
            // The signature matches IMinigameToken::mint so existing call
            // sites work unchanged, but unsupported features must not be
            // silently dropped — reject them loudly.
            assert!(objective_id.is_none(), "MinigameTokenLite: objectives not supported");
            assert!(context.is_none(), "MinigameTokenLite: context not supported");
            assert!(client_url.is_none(), "MinigameTokenLite: client_url not supported");
            assert!(
                renderer_address.is_none(), "MinigameTokenLite: per-token renderer not supported",
            );
            assert!(skills_address.is_none(), "MinigameTokenLite: skills not supported");
            assert!(!paymaster, "MinigameTokenLite: paymaster flag not supported");
            assert!(metadata == 0, "MinigameTokenLite: metadata field not supported");

            // Single game — no SRC5 probe, no registry resolution. The
            // parameter is kept (and checked) purely for call-site parity.
            assert!(
                game_address == self.game_address.read(),
                "MinigameTokenLite: Game address does not match configured game",
            );

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
                "MinigameTokenLite: Lifecycle end must be in the future and after start",
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

            let mut contract_self = self.get_contract_mut();
            let minted_by = MinterOpt::add_minter(ref contract_self, caller);

            let final_token_id = pack_token_id(
                0, // game_id: always 0 — single game
                minted_by,
                settings_id.unwrap_or(0),
                current_time,
                start_delay,
                end_delay,
                0, // objective_id
                soulbound,
                false, // has_context
                false, // paymaster
                tx_hash_bits,
                salt,
                0 // metadata
            );

            if let Option::Some(name) = player_name {
                self.token_player_names.entry(final_token_id).write(name);
            }

            let mut contract = self.get_contract_mut();
            let mut erc721_component = ERC721::get_component_mut(ref contract);
            erc721_component.mint(to, final_token_id.into());

            final_token_id
        }

        /// Batch mint identical tokens to one or more recipients with per-recipient
        /// counts. ABI-compatible with `IMinigameToken::mint_batch_recipients` so
        /// batch-minting metagames (tournaments, brackets) work unchanged against a
        /// lite deployment; the same unsupported-parameter rules as `mint` apply.
        ///
        /// Salt is a single global counter across the batch (`salt + i` for
        /// `i in 0..sum(counts)`), identical to the full token: token ids do not
        /// encode the recipient, so salts must be globally unique within the tx —
        /// `salt + sum(counts) - 1 <= 0x3FF` (10-bit field).
        ///
        /// Versus calling `mint` per token, the lifecycle math, tx-info read, game
        /// check and minter registration are hoisted and paid once for the batch.
        fn mint_batch_recipients(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            recipients: Array<MintBatchRecipient>,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u16,
        ) -> Array<felt252> {
            assert!(objective_id.is_none(), "MinigameTokenLite: objectives not supported");
            assert!(context.is_none(), "MinigameTokenLite: context not supported");
            assert!(client_url.is_none(), "MinigameTokenLite: client_url not supported");
            assert!(
                renderer_address.is_none(), "MinigameTokenLite: per-token renderer not supported",
            );
            assert!(skills_address.is_none(), "MinigameTokenLite: skills not supported");
            assert!(!paymaster, "MinigameTokenLite: paymaster flag not supported");
            assert!(metadata == 0, "MinigameTokenLite: metadata field not supported");
            assert!(
                game_address == self.game_address.read(),
                "MinigameTokenLite: Game address does not match configured game",
            );

            let recipient_count = recipients.len();
            assert!(recipient_count > 0, "MinigameTokenLite: recipients array cannot be empty");

            // Sum per-recipient counts and bound the global salt counter.
            let mut total_tokens: u32 = 0;
            let mut sum_idx: u32 = 0;
            while sum_idx < recipient_count {
                let r: @MintBatchRecipient = recipients.at(sum_idx);
                let c: u16 = *r.count;
                assert!(c > 0, "MinigameTokenLite: per-recipient count must be > 0");
                total_tokens += c.into();
                sum_idx += 1;
            }
            let max_salt: u32 = salt.into() + total_tokens - 1;
            assert!(
                max_salt <= 0x3FF,
                "MinigameTokenLite: salt overflow (salt + total tokens - 1 must be <= 1023)",
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
                "MinigameTokenLite: Lifecycle end must be in the future and after start",
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

            let mut contract_self = self.get_contract_mut();
            let minted_by = MinterOpt::add_minter(ref contract_self, caller);
            let validated_settings_id = settings_id.unwrap_or(0);

            // Per-token work: pack, optional name write, ERC721 mint.
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
                        0, // game_id: always 0 — single game
                        minted_by,
                        validated_settings_id,
                        current_time,
                        start_delay,
                        end_delay,
                        0, // objective_id
                        soulbound,
                        false, // has_context
                        false, // paymaster
                        tx_hash_bits,
                        salt + salt_offset,
                        0 // metadata
                    );

                    if let Option::Some(name) = player_name {
                        self.token_player_names.entry(final_token_id).write(name);
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

        fn refresh_metadata_batch(
            ref self: ComponentState<TContractState>, token_ids: Span<felt252>,
        ) {
            assert!(token_ids.len() > 0, "MinigameTokenLite: token_ids array cannot be empty");
            let mut i: u32 = 0;
            while i < token_ids.len() {
                self.emit(MetadataUpdate { token_id: (*token_ids.at(i)).into() });
                i += 1;
            }
        }

        fn update_player_name(
            ref self: ComponentState<TContractState>, token_id: felt252, name: felt252,
        ) {
            assert!(!name.is_zero(), "MinigameTokenLite: Player name is empty");
            let contract = self.get_contract();
            let erc721_component = ERC721::get_component(contract);
            let token_owner = erc721_component._owner_of(token_id.into());
            assert!(
                token_owner == get_caller_address(),
                "MinigameTokenLite: Caller is not owner of token",
            );
            self.token_player_names.entry(token_id).write(name);
            self.emit(MetadataUpdate { token_id: token_id.into() });
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl MinterOpt: OptionalMinter<TContractState>,
        +Drop<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, game_address: ContractAddress) {
            self.register_interfaces();
            self.bind_game(game_address);
        }

        /// Registers the SRC5 interface ids without binding a game — the first
        /// half of a two-phase initialization for deployments where the game
        /// contract needs the token address in ITS constructor (mutual
        /// constructor dependency): deploy the token with interfaces only,
        /// deploy the game pointing at the token (its SRC5 check passes), then
        /// `bind_game`. An unbound token cannot mint: `mint` requires the
        /// caller-supplied game address to equal the stored one, which is zero.
        fn register_interfaces(ref self: ComponentState<TContractState>) {
            let mut contract = self.get_contract_mut();
            let mut src5_component = SRC5::get_component_mut(ref contract);
            src5_component.register_interface(IMINIGAME_TOKEN_LITE_ID);
            // Also advertise the full-token id: MinigameComponent::initializer
            // hard-asserts it before wiring a game to its token. The lite
            // token implements the subset of IMinigameToken that game-side
            // components actually call (mint, assert_is_playable, player_name,
            // refresh_metadata, game_registry_address); anything else reverts
            // with ENTRYPOINT_NOT_FOUND rather than misbehaving silently.
            src5_component.register_interface(IMINIGAME_TOKEN_ID);
        }

        /// Binds the single game, exactly once. The binding is immutable
        /// thereafter — the game address is the token's trust anchor, and
        /// every mint and playability check is defined against it.
        fn bind_game(ref self: ComponentState<TContractState>, game_address: ContractAddress) {
            assert!(!game_address.is_zero(), "MinigameTokenLite: Game address is zero");
            assert!(self.game_address.read().is_zero(), "MinigameTokenLite: Game is already bound");
            self.game_address.write(game_address);
        }

        /// Lifecycle-window check only — there is deliberately no token-side
        /// game_over / completed_objective state to consult. Games gate dead
        /// runs themselves; they are the source of truth.
        fn assert_lifecycle_open(self: @ComponentState<TContractState>, token_id: felt252) {
            let packed = unpack_token_id(token_id);
            let empty_state = TokenMutableState {
                game_over: false, completed_objective: false, completed_at: 0,
            };
            let metadata = to_token_metadata(packed, empty_state);
            let current_time = get_block_timestamp();
            let lifecycle = metadata.lifecycle;
            assert!(
                lifecycle.can_start(current_time),
                "MinigameTokenLite: Token is not playable - game has not started (now={}, start={})",
                current_time,
                lifecycle.start,
            );
            assert!(
                !lifecycle.has_expired(current_time),
                "MinigameTokenLite: Token is not playable - game has expired (now={}, end={})",
                current_time,
                lifecycle.end,
            );
        }
    }
}
