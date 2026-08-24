// Merged one-address mock: ONE contract that is both the game and the lite
// token. This is the only supported shape for `CoreTokenLiteComponent` — the
// component is self-binding, so the game contract IS the token.
//
// The contract wires:
// * ERC721 + SRC5 + CoreTokenLiteComponent + MinterComponent, with the
//   soulbound transfer guard in `before_update` (pure `unpack_soulbound`
//   from the lite-native `token_lite::packing` layout).
// * `IMinigame` views that all return the contract's own address, plus
//   `mint_game`/`mint_game_batch` delegating to the embedded lite token.
// * `IMinigameTokenData` from local maps, with test setters `set_score` /
//   `end_game` mirroring minigame_mock's semantics.
// * `IMinigameSettings` + minigame_mock-style `create_settings_difficulty`
//   storing locally. The game-side `SettingsComponent::create_settings`
//   announcement runs against this contract itself; its SRC5 guard sees no
//   token-side settings surface and silently skips — good coverage of the
//   lite announcement path.

#[starknet::interface]
pub trait ILiteGameMock<TContractState> {
    fn set_score(ref self: TContractState, token_id: felt252, score: u64);
    fn end_game(ref self: TContractState, token_id: felt252, score: u64);
    fn create_settings_difficulty(
        ref self: TContractState, name: ByteArray, description: ByteArray, difficulty: u8,
    );
    /// Test-only exposure of the component's internal pre-action guard —
    /// the way a real game consumes it inside its own entrypoints.
    fn assert_owner_and_playable(
        self: @TContractState, token_id: felt252, expected_owner: starknet::ContractAddress,
    );
}

#[starknet::contract]
pub mod LiteGameMock {
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
    use game_components_embeddable_game_standard::minigame::extensions::settings::interface::IMinigameSettings;
    use game_components_embeddable_game_standard::minigame::extensions::settings::settings::SettingsComponent;
    use game_components_embeddable_game_standard::minigame::extensions::settings::structs::{
        GameSetting, GameSettingDetails,
    };
    use game_components_embeddable_game_standard::minigame::interface::{
        IMINIGAME_ID, IMinigame, IMinigameTokenData,
    };
    use game_components_embeddable_game_standard::minigame::structs::MintGameParams;
    use game_components_embeddable_game_standard::token::extensions::minter::minter::MinterComponent;
    use game_components_embeddable_game_standard::token_lite::interface::{
        IMinigameTokenLiteDispatcher, IMinigameTokenLiteDispatcherTrait,
    };
    use game_components_embeddable_game_standard::token_lite::packing::unpack_soulbound;
    use game_components_embeddable_game_standard::token_lite::token_lite_component::CoreTokenLiteComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc721::ERC721Component;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_contract_address};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: CoreTokenLiteComponent, storage: core_token_lite, event: CoreTokenLiteEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: SettingsComponent, storage: settings, event: SettingsEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        core_token_lite: CoreTokenLiteComponent::Storage,
        #[substorage(v0)]
        minter: MinterComponent::Storage,
        #[substorage(v0)]
        settings: SettingsComponent::Storage,
        // Game state — the game contract is the sole authority on score and
        // game-over; the lite token holds no mutable state.
        scores: Map<felt252, u64>,
        game_over: Map<felt252, bool>,
        // Settings storage (minigame_mock-style)
        settings_count: u32,
        settings_difficulty: Map<u32, u8>, // settings_id -> difficulty
        settings_details: Map<
            u32, (ByteArray, ByteArray, bool),
        > // settings_id -> (name, description, exists)
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        CoreTokenLiteEvent: CoreTokenLiteComponent::Event,
        #[flat]
        MinterEvent: MinterComponent::Event,
        #[flat]
        SettingsEvent: SettingsComponent::Event,
    }

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl CoreTokenLiteImpl =
        CoreTokenLiteComponent::CoreTokenLiteImpl<ContractState>;
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    impl CoreTokenLiteInternalImpl = CoreTokenLiteComponent::InternalImpl<ContractState>;
    impl MinterInternalImpl = MinterComponent::InternalImpl<ContractState>;
    impl SettingsInternalImpl = SettingsComponent::InternalImpl<ContractState>;

    // Minter is the only optional feature the lite core consumes.
    impl MinterOptionalImpl = MinterComponent::MinterOptionalImpl<ContractState>;

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // Soulbound is a bit in the token id — pure unpack, no storage.
            // Only transfers are blocked; mints (owner == 0) and burns
            // (to == 0) pass through.
            let current_owner = self._owner_of(token_id);
            if !current_owner.is_zero() && !to.is_zero() {
                if unpack_soulbound(token_id.try_into().unwrap()) {
                    panic!("Token is soulbound and cannot be transferred");
                }
            }
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {}
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        // Self-binding: no game argument — this contract IS the game.
        self.core_token_lite.initializer();
        self.minter.initializer();
        // Registers IMINIGAME_SETTINGS_ID (mirrors minigame_mock).
        self.settings.initializer();
        self.src5.register_interface(IMINIGAME_ID);
    }

    /// The one-address shape made concrete: every address the game advertises
    /// is this contract.
    #[abi(embed_v0)]
    impl MinigameImpl of IMinigame<ContractState> {
        fn token_address(self: @ContractState) -> ContractAddress {
            get_contract_address()
        }

        fn settings_address(self: @ContractState) -> ContractAddress {
            get_contract_address()
        }

        fn objectives_address(self: @ContractState) -> ContractAddress {
            get_contract_address()
        }

        /// `IMinigame::mint_game` keeps the full 15-arg trait shape. The lite
        /// mint now carries objective/context/client_url/paymaster/metadata
        /// with their original full-token behaviors, so those forward
        /// naturally (the standard trait's u16 metadata widens into the lite
        /// u128 field via `.into()`); only renderer/skills — which the lite
        /// token has no surface for — must be neutral, rejected here rather
        /// than silently discarded.
        fn mint_game(
            self: @ContractState,
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
            assert!(renderer_address.is_none(), "LiteGameMock: renderer not supported");
            assert!(skills_address.is_none(), "LiteGameMock: skills not supported");
            let token = IMinigameTokenLiteDispatcher { contract_address: get_contract_address() };
            token
                .mint(
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
                    salt,
                    metadata.into(),
                )
        }

        fn mint_game_batch(self: @ContractState, mints: Array<MintGameParams>) -> Array<felt252> {
            let token = IMinigameTokenLiteDispatcher { contract_address: get_contract_address() };
            let mut token_ids: Array<felt252> = array![];
            let mut index: u32 = 0;
            while index < mints.len() {
                let m = mints.at(index);
                assert!(m.renderer_address.is_none(), "LiteGameMock: renderer not supported");
                assert!(m.skills_address.is_none(), "LiteGameMock: skills not supported");
                let context = match m.context {
                    Option::Some(c) => Option::Some(c.clone()),
                    Option::None => Option::None,
                };
                let client_url = match m.client_url {
                    Option::Some(u) => Option::Some(u.clone()),
                    Option::None => Option::None,
                };
                token_ids
                    .append(
                        token
                            .mint(
                                *m.player_name,
                                *m.settings_id,
                                *m.start,
                                *m.end,
                                *m.objective_id,
                                context,
                                client_url,
                                *m.to,
                                *m.soulbound,
                                *m.paymaster,
                                *m.salt,
                                (*m.metadata).into(),
                            ),
                    );
                index += 1;
            }
            token_ids
        }
    }

    #[abi(embed_v0)]
    impl GameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: felt252) -> u64 {
            self.scores.entry(token_id).read()
        }

        fn game_over(self: @ContractState, token_id: felt252) -> bool {
            self.game_over.entry(token_id).read()
        }

        fn score_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u64> {
            let mut results = array![];
            let mut index = 0;
            while index < token_ids.len() {
                results.append(self.score(*token_ids.at(index)));
                index += 1;
            }
            results
        }

        fn game_over_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut results = array![];
            let mut index = 0;
            while index < token_ids.len() {
                results.append(self.game_over(*token_ids.at(index)));
                index += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl SettingsImpl of IMinigameSettings<ContractState> {
        fn settings_exist(self: @ContractState, settings_id: u32) -> bool {
            let (_, _, exists) = self.settings_details.entry(settings_id).read();
            exists
        }

        fn settings_exist_batch(self: @ContractState, settings_ids: Span<u32>) -> Array<bool> {
            let mut results = array![];
            let mut index = 0;
            while index < settings_ids.len() {
                results.append(self.settings_exist(*settings_ids.at(index)));
                index += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl LiteGameMockImpl of super::ILiteGameMock<ContractState> {
        fn set_score(ref self: ContractState, token_id: felt252, score: u64) {
            self.scores.entry(token_id).write(score);
        }

        fn end_game(ref self: ContractState, token_id: felt252, score: u64) {
            self.scores.entry(token_id).write(score);
            self.game_over.entry(token_id).write(true);
        }

        /// Exposes the component's internal pre-action guard for tests —
        /// mirrors how a real game calls it inside its own entrypoints.
        fn assert_owner_and_playable(
            self: @ContractState, token_id: felt252, expected_owner: ContractAddress,
        ) {
            self.core_token_lite.assert_owner_and_playable(token_id, expected_owner);
        }

        fn create_settings_difficulty(
            ref self: ContractState, name: ByteArray, description: ByteArray, difficulty: u8,
        ) {
            let settings_count = self.settings_count.read();
            let new_settings_id = settings_count + 1;

            self.settings_difficulty.entry(new_settings_id).write(difficulty);
            self
                .settings_details
                .entry(new_settings_id)
                .write((name.clone(), description.clone(), true));
            self.settings_count.write(new_settings_id);

            let settings = array![GameSetting { name: 'Difficulty', value: difficulty.into() }];

            // Announce to the token — i.e. this contract. The SRC5 guard in
            // the settings lib finds no IMINIGAME_TOKEN_SETTINGS_ID surface on
            // the lite token and silently skips, mirroring minigame_mock's
            // flow against a lite deployment.
            self
                .settings
                .create_settings(
                    get_contract_address(),
                    new_settings_id,
                    GameSettingDetails { name, description, settings: settings.span() },
                    get_contract_address(),
                );
        }
    }
}
