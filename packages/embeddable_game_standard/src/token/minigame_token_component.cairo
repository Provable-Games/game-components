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
/// `paymaster` and the (59-bit, u128) `metadata` are packed into the id as
/// inert data the game interprets; `context` sets the id's has_context bit
/// only (the data is NOT stored — legacy-token parity); `client_url` is
/// storage-backed with a `client_url` view.
///
/// The minter registry is standard, not optional: absorbed into this
/// component (storage names, `IMinigameTokenMinter` surface and
/// `MinterRegistryUpdate` event identical to the legacy MinterComponent's).
///
/// Token ids use the standard's schema v1 layout in `token::packing` — NOT
/// the retired registry generation's layout. Indexers must branch their
/// token-id decoder by contract generation (`schema_version`, id low bits
/// 0-4). Mint times are stored to the minute; ids are made unique by the tx
/// hash plus an internal collision counter (`tx_nonce`) that the component
/// bumps whenever a packed id already has an owner — no caller-supplied salt.
#[starknet::component]
pub mod MinigameTokenComponent {
    use core::num::traits::Zero;
    use game_components_interfaces::structs::metagame::GameContextDetails;
    use game_components_interfaces::structs::token::{Lifecycle, MintBatchRecipient, TokenMetadata};
    use game_components_interfaces::token::core::{
        IMINIGAME_TOKEN_ID, IMinigameToken, MinigameTokenABI,
    };
    use game_components_interfaces::token::game_fee::{
        DEFAULT_GAME_FEE_BPS, FEE_DENOMINATOR, GameFeeTerms, IMINIGAME_TOKEN_GAME_FEE_ID,
        IMinigameTokenGameFee, default_license,
    };
    use game_components_interfaces::token::minter::{
        IMINIGAME_TOKEN_MINTER_ID, IMinigameTokenMinter,
    };
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_access::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::InternalTrait as ERC721InternalTrait;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{
        ContractAddress, get_block_info, get_block_timestamp, get_caller_address, get_tx_info,
    };
    use crate::token::lifecycle::{LifecycleTrait, create_lifecycle_with_defaults};
    use crate::token::packing::{
        PackedTokenId, SCHEMA_VERSION, extract_tx_hash_bits, minutes_ceil_delay, minutes_floor,
        minutes_to_seconds, pack_token_id, to_token_metadata, unpack_end_delay, unpack_has_context,
        unpack_lifecycle, unpack_metadata, unpack_minted_at_block_number,
        unpack_minted_at_timestamp, unpack_minted_by, unpack_objective_id, unpack_paymaster,
        unpack_schema_version, unpack_settings_id, unpack_soulbound, unpack_start_delay,
        unpack_token_id, unpack_tx_hash, unpack_tx_nonce,
    };

    /// Hard cap on the internal collision counter (8-bit `tx_nonce` field):
    /// at most 256 identical ids can be resolved in one tx or block.
    const MAX_TX_NONCE: u32 = 255;
    /// A batch shares one counter, so it can mint at most 256 tokens.
    const MAX_BATCH_TOKENS: u32 = 256;

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
        // Game fee recipient + monetization terms. Replaces the retired
        // registry's game_fee_info lookup: with no registry, the payee and
        // fee live on the game contract itself, set at initialization and
        // administered (rotation, fee changes) by the contract's OZ owner.
        game_fee_recipient: ContractAddress,
        game_fee_license: ByteArray,
        game_fee_numerator: u16,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MetadataUpdate: MetadataUpdate,
        MinterRegistryUpdate: MinterRegistryUpdate,
        GameFeeRecipientUpdate: GameFeeRecipientUpdate,
        GameFeeUpdate: GameFeeUpdate,
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

    /// Emitted when the game fee recipient is set or rotated.
    #[derive(Drop, starknet::Event)]
    pub struct GameFeeRecipientUpdate {
        #[key]
        pub recipient: ContractAddress,
    }

    /// Emitted when the license / fee terms change.
    #[derive(Drop, starknet::Event)]
    pub struct GameFeeUpdate {
        pub license: ByteArray,
        pub fee_numerator: u16,
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
            to_token_metadata(unpack_token_id(token_id))
        }

        fn is_playable(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            unpack_lifecycle(token_id).is_playable(get_block_timestamp())
        }

        fn settings_id(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            unpack_settings_id(token_id)
        }

        fn player_name(self: @ComponentState<TContractState>, token_id: felt252) -> felt252 {
            self.token_player_names.entry(token_id).read()
        }

        fn minted_by(self: @ComponentState<TContractState>, token_id: felt252) -> felt252 {
            unpack_minted_by(token_id).into()
        }

        fn minted_by_address(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> ContractAddress {
            let minted_by_id: u64 = unpack_minted_by(token_id).into();
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

        fn schema_version(self: @ComponentState<TContractState>, token_id: felt252) -> u8 {
            unpack_schema_version(token_id)
        }

        fn has_context(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            unpack_has_context(token_id)
        }

        fn is_paymaster(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            unpack_paymaster(token_id)
        }

        fn tx_hash(self: @ComponentState<TContractState>, token_id: felt252) -> u16 {
            unpack_tx_hash(token_id)
        }

        fn tx_nonce(self: @ComponentState<TContractState>, token_id: felt252) -> u8 {
            unpack_tx_nonce(token_id)
        }

        fn minted_at_block_number(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            unpack_minted_at_block_number(token_id)
        }

        fn minted_at(self: @ComponentState<TContractState>, token_id: felt252) -> u64 {
            minutes_to_seconds(unpack_minted_at_timestamp(token_id).into())
        }

        fn start_delay(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            unpack_start_delay(token_id)
        }

        fn end_delay(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            unpack_end_delay(token_id)
        }

        fn lifecycle(self: @ComponentState<TContractState>, token_id: felt252) -> Lifecycle {
            unpack_lifecycle(token_id)
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
            metadata: u128,
        ) -> felt252 {
            // settings_id keeps its Option<u32> call-site type; the pack
            // asserts the value fits the id layout's 20-bit field. Likewise
            // objective_id must fit 20 bits and metadata 59 bits. context
            // sets the has_context bit only — the data itself is NOT stored
            // (legacy-token parity: its context hook was a documented no-op).
            let mut fields = self
                .mint_fields(
                    start,
                    end,
                    settings_id.unwrap_or(0),
                    objective_id.unwrap_or(0),
                    context.is_some(),
                    soulbound,
                    paymaster,
                    metadata,
                );

            let (final_token_id, _) = self.next_free_token_id(ref fields, 0);

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
        /// Every token in the batch shares every packed field, so one
        /// `tx_nonce` counter runs across the whole batch: each token takes
        /// the next free nonce (skipping ids another transaction already
        /// minted this block), and the 8-bit field caps a batch at 256
        /// tokens — checked up front, before anything is minted.
        ///
        /// Versus calling `mint` per token, the lifecycle math, block/tx-info
        /// reads and minter registration are hoisted and paid once.
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
            metadata: u128,
        ) -> Array<felt252> {
            let recipient_count = recipients.len();
            assert!(recipient_count > 0, "MinigameToken: recipients array cannot be empty");

            // Sum per-recipient counts and bound the shared nonce counter.
            let mut total_tokens: u32 = 0;
            let mut sum_idx: u32 = 0;
            while sum_idx < recipient_count {
                let r: @MintBatchRecipient = recipients.at(sum_idx);
                let c: u16 = *r.count;
                assert!(c > 0, "MinigameToken: per-recipient count must be > 0");
                total_tokens += c.into();
                sum_idx += 1;
            }
            assert!(
                total_tokens <= MAX_BATCH_TOKENS,
                "MinigameToken: batch exceeds 256 tokens (8-bit tx_nonce)",
            );

            // Hoisted per-batch work: lifecycle math, block/tx reads, minter
            // registration — the shared packed fields.
            let mut fields = self
                .mint_fields(
                    start,
                    end,
                    settings_id.unwrap_or(0),
                    objective_id.unwrap_or(0),
                    context.is_some(),
                    soulbound,
                    paymaster,
                    metadata,
                );

            // Per-token work: next free id, optional name/url writes, ERC721
            // mint. One nonce counter runs across the batch.
            let mut token_ids: Array<felt252> = ArrayTrait::new();
            let mut next_nonce: u32 = 0;
            let mut r_idx: u32 = 0;
            while r_idx < recipient_count {
                let r: @MintBatchRecipient = recipients.at(r_idx);
                let to: ContractAddress = *r.to;
                let count: u16 = *r.count;

                let mut k: u16 = 0;
                while k < count {
                    let (final_token_id, used_nonce) = self
                        .next_free_token_id(ref fields, next_nonce);
                    next_nonce = used_nonce + 1;

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

    /// The game-fee surface is standard, not optional: with the registry retired,
    /// this surface is the only place a monetization platform can resolve a
    /// game's payee and minimum fee. The stored recipient is a payout sink; the
    /// game contract's OZ OWNER administers it — both setters are gated with
    /// `assert_only_owner`, and the `OwnableComponent::HasComponent` bound
    /// makes that a compile-time requirement: every contract embedding this
    /// impl MUST also embed `OwnableComponent`.
    #[embeddable_as(GameFeeImpl)]
    pub impl GameFee<
        TContractState,
        +HasComponent<TContractState>,
        impl Own: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameTokenGameFee<ComponentState<TContractState>> {
        fn game_fee_terms(self: @ComponentState<TContractState>) -> GameFeeTerms {
            GameFeeTerms {
                recipient: self.game_fee_recipient.read(),
                license: self.game_fee_license.read(),
                fee_numerator: self.game_fee_numerator.read(),
            }
        }

        fn game_fee_recipient(self: @ComponentState<TContractState>) -> ContractAddress {
            self.game_fee_recipient.read()
        }

        fn set_game_fee_recipient(
            ref self: ComponentState<TContractState>, new_recipient: ContractAddress,
        ) {
            Own::get_component(self.get_contract()).assert_only_owner();
            // Rotation must never brick the payee.
            assert!(!new_recipient.is_zero(), "MinigameToken: Fee recipient cannot be zero");
            self.game_fee_recipient.write(new_recipient);
            self.emit(GameFeeRecipientUpdate { recipient: new_recipient });
        }

        fn set_game_fee(
            ref self: ComponentState<TContractState>, license: ByteArray, fee_numerator: u16,
        ) {
            Own::get_component(self.get_contract()).assert_only_owner();
            assert!(
                fee_numerator <= FEE_DENOMINATOR,
                "MinigameToken: Fee numerator exceeds denominator",
            );
            self.game_fee_license.write(license.clone());
            self.game_fee_numerator.write(fee_numerator);
            self.emit(GameFeeUpdate { license, fee_numerator });
        }
    }

    /// One-embed mixin over the full standard surface (token + absorbed
    /// minter + game fee), mirroring OZ's ERC20MixinImpl pattern. The
    /// initializer registers all three SRC5 ids unconditionally, so embedding
    /// this single impl — rather than MinigameTokenImpl / MinterImpl /
    /// GameFeeImpl separately — makes it impossible for the advertised ids to
    /// diverge from the exposed entrypoints (honest SRC5 by construction).
    /// The separate impls remain exported for contracts that wire them
    /// individually.
    #[embeddable_as(MinigameTokenMixinImpl)]
    pub impl MinigameTokenMixin<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl Own: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
    > of MinigameTokenABI<ComponentState<TContractState>> {
        // IMinigameToken
        fn token_metadata(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> TokenMetadata {
            MinigameToken::token_metadata(self, token_id)
        }
        fn is_playable(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            MinigameToken::is_playable(self, token_id)
        }
        fn settings_id(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            MinigameToken::settings_id(self, token_id)
        }
        fn player_name(self: @ComponentState<TContractState>, token_id: felt252) -> felt252 {
            MinigameToken::player_name(self, token_id)
        }
        fn minted_by(self: @ComponentState<TContractState>, token_id: felt252) -> felt252 {
            MinigameToken::minted_by(self, token_id)
        }
        fn minted_by_address(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> ContractAddress {
            MinigameToken::minted_by_address(self, token_id)
        }
        fn is_soulbound(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            MinigameToken::is_soulbound(self, token_id)
        }
        fn objective_id(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            MinigameToken::objective_id(self, token_id)
        }
        fn client_url(self: @ComponentState<TContractState>, token_id: felt252) -> ByteArray {
            MinigameToken::client_url(self, token_id)
        }
        fn mint_metadata(self: @ComponentState<TContractState>, token_id: felt252) -> u128 {
            MinigameToken::mint_metadata(self, token_id)
        }
        fn schema_version(self: @ComponentState<TContractState>, token_id: felt252) -> u8 {
            MinigameToken::schema_version(self, token_id)
        }
        fn has_context(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            MinigameToken::has_context(self, token_id)
        }
        fn is_paymaster(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            MinigameToken::is_paymaster(self, token_id)
        }
        fn tx_hash(self: @ComponentState<TContractState>, token_id: felt252) -> u16 {
            MinigameToken::tx_hash(self, token_id)
        }
        fn tx_nonce(self: @ComponentState<TContractState>, token_id: felt252) -> u8 {
            MinigameToken::tx_nonce(self, token_id)
        }
        fn minted_at_block_number(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            MinigameToken::minted_at_block_number(self, token_id)
        }
        fn minted_at(self: @ComponentState<TContractState>, token_id: felt252) -> u64 {
            MinigameToken::minted_at(self, token_id)
        }
        fn start_delay(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            MinigameToken::start_delay(self, token_id)
        }
        fn end_delay(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            MinigameToken::end_delay(self, token_id)
        }
        fn lifecycle(self: @ComponentState<TContractState>, token_id: felt252) -> Lifecycle {
            MinigameToken::lifecycle(self, token_id)
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
            metadata: u128,
        ) -> felt252 {
            MinigameToken::mint(
                ref self,
                player_name,
                settings_id,
                start,
                end,
                objective_id,
                context,
                client_url,
                to,
                soulbound,
                paymaster,
                metadata,
            )
        }
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
            metadata: u128,
        ) -> Array<felt252> {
            MinigameToken::mint_batch_recipients(
                ref self,
                player_name,
                settings_id,
                start,
                end,
                objective_id,
                context,
                client_url,
                recipients,
                soulbound,
                paymaster,
                metadata,
            )
        }
        fn refresh_metadata(ref self: ComponentState<TContractState>, token_id: felt252) {
            MinigameToken::refresh_metadata(ref self, token_id)
        }
        fn update_player_name(
            ref self: ComponentState<TContractState>, token_id: felt252, name: felt252,
        ) {
            MinigameToken::update_player_name(ref self, token_id, name)
        }

        // IMinigameTokenMinter
        fn get_minter_address(
            self: @ComponentState<TContractState>, minter_id: u64,
        ) -> ContractAddress {
            Minter::get_minter_address(self, minter_id)
        }
        fn get_minter_id(
            self: @ComponentState<TContractState>, minter_address: ContractAddress,
        ) -> u64 {
            Minter::get_minter_id(self, minter_address)
        }
        fn minter_exists(
            self: @ComponentState<TContractState>, minter_address: ContractAddress,
        ) -> bool {
            Minter::minter_exists(self, minter_address)
        }
        fn total_minters(self: @ComponentState<TContractState>) -> u64 {
            Minter::total_minters(self)
        }

        // IMinigameTokenGameFee
        fn game_fee_terms(self: @ComponentState<TContractState>) -> GameFeeTerms {
            GameFee::game_fee_terms(self)
        }
        fn game_fee_recipient(self: @ComponentState<TContractState>) -> ContractAddress {
            GameFee::game_fee_recipient(self)
        }
        fn set_game_fee_recipient(
            ref self: ComponentState<TContractState>, new_recipient: ContractAddress,
        ) {
            GameFee::set_game_fee_recipient(ref self, new_recipient)
        }
        fn set_game_fee(
            ref self: ComponentState<TContractState>, license: ByteArray, fee_numerator: u16,
        ) {
            GameFee::set_game_fee(ref self, license, fee_numerator)
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

        /// Everything a mint packs except the collision counter: validates
        /// the requested lifecycle, converts it to the id's minute fields,
        /// reads block/tx info and registers the caller as minter. Shared by
        /// `mint` and `mint_batch_recipients` (hoisted once per batch).
        ///
        /// Lifecycle rules: a non-zero end must be in the future and after
        /// start (end_delay 0 means "no expiration", so a past window must
        /// not collapse into an immortal token); a start at or before now
        /// clamps to now. Times are stored to the minute — the mint time is
        /// floored, the delays are ceiled — so the reconstructed window is
        /// never earlier than requested and at most 59 seconds later, and a
        /// non-zero end always yields end_delay >= 1.
        fn mint_fields(
            ref self: ComponentState<TContractState>,
            start: Option<u64>,
            end: Option<u64>,
            settings_id: u32,
            objective_id: u32,
            has_context: bool,
            soulbound: bool,
            paymaster: bool,
            metadata: u128,
        ) -> PackedTokenId {
            let block_info = get_block_info().unbox();
            let current_time = block_info.block_timestamp;
            let minted_at_block_number: u32 = block_info
                .block_number
                .try_into()
                .expect('MinigameToken: block > 32 bits');

            let lifecycle = create_lifecycle_with_defaults(start, end);
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
            let minted_at_timestamp = minutes_floor(current_time);
            let minted_at_seconds = minutes_to_seconds(minted_at_timestamp.into());
            let start_delay = minutes_ceil_delay(minted_at_seconds, effective_start);
            let reconstructed_start = minted_at_seconds + minutes_to_seconds(start_delay.into());
            // A non-zero end always yields end_delay >= 1: the ceil handles
            // end > reconstructed_start, and an end that the start's own
            // round-up already overtook (a sub-minute window straddling a
            // minute boundary) clamps to one minute after the start.
            let end_delay = if lifecycle.end == 0 {
                0
            } else if lifecycle.end <= reconstructed_start {
                1
            } else {
                minutes_ceil_delay(reconstructed_start, lifecycle.end)
            };

            let tx_hash = extract_tx_hash_bits(get_tx_info().unbox().transaction_hash);

            let minted_by = self.add_minter(get_caller_address());
            assert!(minted_by <= 0xFFFFFF, "MinigameToken: minter id exceeds 24-bit field");

            PackedTokenId {
                schema_version: SCHEMA_VERSION,
                has_context,
                soulbound,
                paymaster,
                tx_hash,
                tx_nonce: 0,
                minted_at_block_number,
                minted_at_timestamp,
                start_delay,
                end_delay,
                settings_id,
                objective_id,
                minted_by: minted_by.try_into().unwrap(),
                metadata,
            }
        }

        /// Resolves the first unused id for `fields`, starting the collision
        /// counter at `from_nonce`: pack, read `_owner_of`, and bump
        /// `tx_nonce` while the id already has an owner. Transactions in a
        /// block run sequentially, so a same-block collision from another
        /// transaction is already visible in the owner mapping; the ERC721
        /// mint performs the same read, so the common path costs nothing
        /// extra. Returns the id and the nonce it was packed with.
        fn next_free_token_id(
            self: @ComponentState<TContractState>, ref fields: PackedTokenId, from_nonce: u32,
        ) -> (felt252, u32) {
            let erc721_component = ERC721::get_component(self.get_contract());
            let mut nonce = from_nonce;
            loop {
                assert!(
                    nonce <= MAX_TX_NONCE,
                    "MinigameToken: tx_nonce exhausted (256 identical ids in one tx or block)",
                );
                fields.tx_nonce = nonce.try_into().unwrap();
                let candidate = pack_token_id(fields);
                if erc721_component._owner_of(candidate.into()).is_zero() {
                    break (candidate, nonce);
                }
                nonce += 1;
            }
        }

        /// Stores the game fee recipient + terms and registers the SRC5 ids:
        /// `IMINIGAME_TOKEN_ID`, the absorbed minter's
        /// `IMINIGAME_TOKEN_MINTER_ID` and the game-fee surface's
        /// `IMINIGAME_TOKEN_GAME_FEE_ID`. There is no game argument — the
        /// component is self-bound: the embedding contract is the game. The
        /// legacy id is NOT registered; SRC5 is honest about the surface
        /// (this token does NOT implement `IMinigameTokenLegacy`).
        ///
        /// INVARIANT the embedder must uphold: all three ids are registered
        /// UNCONDITIONALLY, so the contract must expose all three surfaces —
        /// embed `MinigameTokenMixinImpl` (one line, guaranteed), or embed
        /// `MinigameTokenImpl` + `MinterImpl` + `GameFeeImpl` all together.
        /// A partial wiring that still calls this initializer advertises
        /// entrypoints it does not have, and probe-then-dispatch consumers
        /// (e.g. metagame's fee resolution) will revert against it. Note the
        /// trigger point: that revert fires at first FEE CLAIM, not at
        /// deploy — an integration test that exercises fee payment is what
        /// catches a partial wiring before production does.
        ///
        /// `game_fee_recipient` must be non-zero (it is the monetization payee);
        /// `license`/`fee_numerator` default to the ecosystem terms
        /// (`default_license()`, `DEFAULT_GAME_FEE_BPS` = 500 bps) when None —
        /// matching what the retired registry granted games that declared
        /// nothing.
        fn initializer(
            ref self: ComponentState<TContractState>,
            game_fee_recipient: ContractAddress,
            license: Option<ByteArray>,
            fee_numerator: Option<u16>,
        ) {
            assert!(!game_fee_recipient.is_zero(), "MinigameToken: Fee recipient cannot be zero");
            let fee = fee_numerator.unwrap_or(DEFAULT_GAME_FEE_BPS);
            assert!(fee <= FEE_DENOMINATOR, "MinigameToken: Fee numerator exceeds denominator");
            self.game_fee_recipient.write(game_fee_recipient);
            let license_value = match license {
                Option::Some(l) => l,
                Option::None => default_license(),
            };
            self.game_fee_license.write(license_value);
            self.game_fee_numerator.write(fee);
            self.emit(GameFeeRecipientUpdate { recipient: game_fee_recipient });

            let mut contract = self.get_contract_mut();
            let mut src5_component = SRC5::get_component_mut(ref contract);
            src5_component.register_interface(IMINIGAME_TOKEN_ID);
            // The absorbed minter registry keeps its own discovery id
            // (matching what the legacy MinterComponent::initializer did).
            src5_component.register_interface(IMINIGAME_TOKEN_MINTER_ID);
            src5_component.register_interface(IMINIGAME_TOKEN_GAME_FEE_ID);
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
            let lifecycle = unpack_lifecycle(token_id);
            let current_time = get_block_timestamp();
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
