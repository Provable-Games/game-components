use game_components_embeddable_game_standard::token_legacy::interface::{
    IMinigameTokenLegacyDispatcher, IMinigameTokenLegacyDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use crate::metagame::extensions::context::interface::{
    IMetagameContextDetailsDispatcher, IMetagameContextDetailsDispatcherTrait,
    IMetagameContextDispatcher, IMetagameContextDispatcherTrait,
};
use crate::metagame::extensions::context::structs::{GameContext, GameContextDetails};

// Integration test I-01: Tournament Flow
#[test]
fn test_tournament_flow() {
    // 1. Deploy token contract with multi-game support
    let token_contract = declare("MockTokenContract").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // 2. Deploy context provider contract
    let context_contract = declare("MockContextProvider").unwrap().contract_class();
    let (context_address, _) = context_contract.deploy(@array![1]).unwrap();

    // 3. Deploy metagame with context
    let metagame_contract = declare("MockMetagameWithContext").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(0); // Some(context_address)
    calldata.append(context_address.into());
    calldata.append(token_address.into());
    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();

    // 4. Deploy 3 different games
    let game1 = declare("MockMinigameForTournament").unwrap().contract_class();
    let (game1_address, _) = game1.deploy(@array![token_address.into(), 0, 0]).unwrap();

    let (game2_address, _) = game1.deploy(@array![token_address.into(), 0, 0]).unwrap();

    let (game3_address, _) = game1.deploy(@array![token_address.into(), 0, 0]).unwrap();

    // 5. Game registration is no longer needed with the new architecture
    // Games are associated with tokens at mint time via game_address parameter

    // 6. Create tournament context
    let tournament_context = GameContextDetails {
        name: "Winter Tournament 2024",
        description: "Annual championship",
        id: Option::Some(1),
        context: array![
            GameContext { name: 'Round', value: 'Qualifier Round' },
            GameContext { name: 'Round', value: 'Semi Finals' },
            GameContext { name: 'Round', value: 'Finals' },
        ]
            .span(),
    };

    // 7. Create players
    let player1 = 0x1001.try_into().unwrap();
    let player2 = 0x1002.try_into().unwrap();

    // 8. Mint tokens for players across games using the metagame dispatcher
    let metagame_dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Player 1 - Games 1 and 2
    start_cheat_caller_address(metagame_address, player1);
    let p1_g1_token = metagame_dispatcher
        .mint(
            game1_address,
            Option::Some('Player1'),
            Option::None,
            Option::Some(1000),
            Option::Some(10000),
            Option::None,
            Option::Some(tournament_context.clone()),
            Option::None,
            Option::None,
            Option::None,
            player1,
            false,
            false,
            0,
            0,
        );

    let p1_g2_token = metagame_dispatcher
        .mint(
            game2_address,
            Option::Some('Player1'),
            Option::None,
            Option::Some(1000),
            Option::Some(10000),
            Option::None,
            Option::Some(tournament_context.clone()),
            Option::None,
            Option::None,
            Option::None,
            player1,
            false,
            false,
            0,
            0,
        );
    stop_cheat_caller_address(metagame_address);

    // Player 2 - All games
    start_cheat_caller_address(metagame_address, player2);
    let p2_g1_token = metagame_dispatcher
        .mint(
            game1_address,
            Option::Some('Player2'),
            Option::None,
            Option::Some(1000),
            Option::Some(10000),
            Option::None,
            Option::Some(tournament_context.clone()),
            Option::None,
            Option::None,
            Option::None,
            player2,
            false,
            false,
            0,
            0,
        );

    let p2_g2_token = metagame_dispatcher
        .mint(
            game2_address,
            Option::Some('Player2'),
            Option::None,
            Option::Some(1000),
            Option::Some(10000),
            Option::None,
            Option::Some(tournament_context.clone()),
            Option::None,
            Option::None,
            Option::None,
            player2,
            false,
            false,
            0,
            0,
        );

    let p2_g3_token = metagame_dispatcher
        .mint(
            game3_address,
            Option::Some('Player2'),
            Option::None,
            Option::Some(1000),
            Option::Some(10000),
            Option::None,
            Option::Some(tournament_context.clone()),
            Option::None,
            Option::None,
            Option::None,
            player2,
            false,
            false,
            0,
            0,
        );
    stop_cheat_caller_address(metagame_address);

    // 9. Verify all tokens have context
    let context_dispatcher = IMetagameContextDispatcher { contract_address: context_address };
    let token_dispatcher = IMinigameTokenLegacyDispatcher { contract_address: token_address };

    // Store contexts in mock (in real scenario, this would be done during mint)
    let context_setter = IContextSetterDispatcher { contract_address: context_address };
    context_setter.store_context(p1_g1_token, tournament_context.clone());
    context_setter.store_context(p1_g2_token, tournament_context.clone());
    context_setter.store_context(p2_g1_token, tournament_context.clone());
    context_setter.store_context(p2_g2_token, tournament_context.clone());
    context_setter.store_context(p2_g3_token, tournament_context.clone());

    assert!(context_dispatcher.has_context(p1_g1_token), "P1 G1 should have context");
    assert!(context_dispatcher.has_context(p2_g3_token), "P2 G3 should have context");

    // 10. Simulate gameplay - update scores
    let game1_setter = IMockMinigameSetterDispatcher { contract_address: game1_address };
    let game2_setter = IMockMinigameSetterDispatcher { contract_address: game2_address };
    let game3_setter = IMockMinigameSetterDispatcher { contract_address: game3_address };

    // Set scores
    game1_setter.set_score(p1_g1_token, 1500);
    game1_setter.set_score(p2_g1_token, 1200);

    game2_setter.set_score(p1_g2_token, 800);
    game2_setter.set_score(p2_g2_token, 950);

    game3_setter.set_score(p2_g3_token, 2000);

    // 11. Update game states
    token_dispatcher.update_game(p1_g1_token);
    token_dispatcher.update_game(p1_g2_token);
    token_dispatcher.update_game(p2_g1_token);
    token_dispatcher.update_game(p2_g2_token);
    token_dispatcher.update_game(p2_g3_token);

    // 12. Verify token metadata exists (game_id is 0 for single-game tokens in new architecture)
    // Note: game_id is only non-zero for multi-game tokens registered with a registry
    let p1_g1_metadata = token_dispatcher.token_metadata(p1_g1_token);
    let p2_g3_metadata = token_dispatcher.token_metadata(p2_g3_token);

    // Verify tokens were created (game_id=0 for single-game architecture)
    assert!(p1_g1_metadata.game_id == 0, "Single-game tokens have game_id 0");
    assert!(p2_g3_metadata.game_id == 0, "Single-game tokens have game_id 0");

    // 13. Verify context consistency across all tokens
    let context_details_dispatcher = IMetagameContextDetailsDispatcher {
        contract_address: context_address,
    };
    let retrieved_context = context_details_dispatcher.context_details(p1_g1_token);
    assert!(retrieved_context.name == "Winter Tournament 2024", "Context name mismatch");
    assert!(retrieved_context.context.len() == 3, "Should have 3 tournament rounds");
}

// Mock contracts for integration testing
#[starknet::contract]
mod MockMetagameWithContext {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::metagame::extensions::context::structs::GameContextDetails;
    use crate::metagame::metagame_component::MetagameComponent;

    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl MetagameImpl = MetagameComponent::MetagameImpl<ContractState>;
    impl MetagameInternalImpl = MetagameComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        metagame: MetagameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MetagameEvent: MetagameComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        context_address: Option<ContractAddress>,
        minigame_token_address: ContractAddress,
    ) {
        self.metagame.initializer(context_address);
    }

    // Expose mint function for testing
    #[abi(embed_v0)]
    impl MockMetagameImpl of super::IMockMetagame<ContractState> {
        fn mint(
            ref self: ContractState,
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
            self
                .metagame
                .mint(
                    game_address,
                    player_name,
                    settings_id,
                    start,
                    end,
                    objective_id,
                    context,
                    client_url,
                    renderer_address,
                    Option::None,
                    to,
                    soulbound,
                    paymaster,
                    salt,
                    metadata,
                )
        }
    }
}

// Interface for testing mint function
#[starknet::interface]
trait IMockMetagame<TContractState> {
    fn mint(
        ref self: TContractState,
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
    ) -> felt252;
}

#[starknet::interface]
trait IContextSetter<TContractState> {
    fn store_context(ref self: TContractState, token_id: felt252, context: GameContextDetails);
}

#[starknet::interface]
trait IMockMinigameSetter<TContractState> {
    fn set_score(ref self: TContractState, token_id: felt252, score: u64);
    fn set_game_over(ref self: TContractState, token_id: felt252, game_over: bool);
}

// Mock Context Provider contract
#[starknet::contract]
mod MockContextProvider {
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::metagame::extensions::context::interface::{
        IMETAGAME_CONTEXT_ID, IMetagameContext, IMetagameContextDetails,
    };
    use crate::metagame::extensions::context::structs::{GameContext, GameContextDetails};
    use super::IContextSetter;

    #[storage]
    struct Storage {
        supports_context: bool,
        has_context_map: Map<felt252, bool>,
        context_name: ByteArray,
        context_description: ByteArray,
        context_id: Option<u32>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, supports_context: bool) {
        self.supports_context.write(supports_context);
        self.context_name.write("");
        self.context_description.write("");
        self.context_id.write(Option::None);
    }

    #[abi(embed_v0)]
    impl MetagameContextImpl of IMetagameContext<ContractState> {
        fn has_context(self: @ContractState, token_id: felt252) -> bool {
            self.has_context_map.read(token_id)
        }
    }

    #[abi(embed_v0)]
    impl MetagameContextDetailsImpl of IMetagameContextDetails<ContractState> {
        fn context_details(self: @ContractState, token_id: felt252) -> GameContextDetails {
            if !self.has_context_map.read(token_id) {
                panic!("Context not found");
            }

            GameContextDetails {
                name: self.context_name.read(),
                description: self.context_description.read(),
                id: self.context_id.read(),
                context: array![
                    GameContext { name: 'Round', value: 'Qualifier Round' },
                    GameContext { name: 'Round', value: 'Semi Finals' },
                    GameContext { name: 'Round', value: 'Finals' },
                ]
                    .span(),
            }
        }
    }

    #[abi(embed_v0)]
    impl ContextSetterImpl of IContextSetter<ContractState> {
        fn store_context(ref self: ContractState, token_id: felt252, context: GameContextDetails) {
            self.has_context_map.write(token_id, true);
            self.context_name.write(context.name);
            self.context_description.write(context.description);
            self.context_id.write(context.id);
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            if self.supports_context.read() {
                interface_id == IMETAGAME_CONTEXT_ID
                    || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
            } else {
                interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
            }
        }
    }
}

// Mock Token Contract
#[starknet::contract]
mod MockTokenContract {
    use core::num::traits::Zero;
    use game_components_embeddable_game_standard::token_legacy::interface::{
        IMINIGAME_TOKEN_LEGACY_ID, IMinigameTokenLegacy,
    };
    use game_components_embeddable_game_standard::token_legacy::structs::{
        Lifecycle, MintBatchRecipient, PlayerNameUpdate, TokenFullState, TokenMetadata,
        TokenMutableState,
    };
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::metagame::extensions::context::structs::GameContextDetails;

    #[storage]
    struct Storage {
        next_token_id: u64,
        token_game_address: Map<felt252, ContractAddress>,
        token_player_names: Map<felt252, felt252>,
        token_lifecycle_start: Map<felt252, u64>,
        token_lifecycle_end: Map<felt252, u64>,
        game_address: ContractAddress,
        game_registry_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_token_id.write(1);
    }

    #[abi(embed_v0)]
    impl MinigameTokenImpl of IMinigameTokenLegacy<ContractState> {
        fn token_metadata(self: @ContractState, token_id: felt252) -> TokenMetadata {
            TokenMetadata {
                game_id: 0,
                minted_at: 0,
                settings_id: 0,
                lifecycle: Lifecycle {
                    start: self.token_lifecycle_start.read(token_id),
                    end: self.token_lifecycle_end.read(token_id),
                },
                minted_by: 0,
                soulbound: false,
                game_over: false,
                completed_objective: false,
                completed_at: 0,
                has_context: false,
                objective_id: 0,
                paymaster: false,
                metadata: 0,
            }
        }

        fn is_playable(self: @ContractState, token_id: felt252) -> bool {
            token_id != 0
        }

        fn assert_is_playable(self: @ContractState, token_id: felt252) {}

        fn settings_id(self: @ContractState, token_id: felt252) -> u32 {
            0
        }

        fn player_name(self: @ContractState, token_id: felt252) -> felt252 {
            self.token_player_names.read(token_id)
        }

        fn objective_id(self: @ContractState, token_id: felt252) -> u32 {
            0
        }

        fn minted_by(self: @ContractState, token_id: felt252) -> felt252 {
            0
        }

        fn minted_by_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            0.try_into().unwrap()
        }

        fn game_address(self: @ContractState) -> ContractAddress {
            self.game_address.read()
        }

        fn game_registry_address(self: @ContractState) -> ContractAddress {
            self.game_registry_address.read()
        }

        fn is_soulbound(self: @ContractState, token_id: felt252) -> bool {
            false
        }

        fn renderer_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            Zero::zero()
        }

        fn token_game_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            self.token_game_address.read(token_id)
        }

        fn token_mutable_state(self: @ContractState, token_id: felt252) -> TokenMutableState {
            TokenMutableState { game_over: false, completed_objective: false, completed_at: 0 }
        }

        fn client_url(self: @ContractState, token_id: felt252) -> ByteArray {
            ""
        }

        fn skills_address(self: @ContractState, token_id: felt252) -> ContractAddress {
            0.try_into().unwrap()
        }

        fn token_metadata_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenMetadata> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.token_metadata(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn is_playable_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.is_playable(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn settings_id_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u32> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.settings_id(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn player_name_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<felt252> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.player_name(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn objective_id_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u32> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.objective_id(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn minted_by_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<felt252> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.minted_by(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn minted_by_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            array![]
        }

        fn is_soulbound_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.is_soulbound(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn renderer_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.renderer_address(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn token_game_address_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.token_game_address(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn token_mutable_state_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenMutableState> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                results.append(self.token_mutable_state(*token_ids.at(i)));
                i += 1;
            }
            results
        }

        fn token_full_state_batch(
            self: @ContractState, token_ids: Span<felt252>,
        ) -> Array<TokenFullState> {
            array![]
        }

        fn mint(
            ref self: ContractState,
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
            let token_id_u64 = self.next_token_id.read();
            self.next_token_id.write(token_id_u64 + 1);
            let token_id: felt252 = token_id_u64.into();

            self.token_game_address.write(token_id, game_address);

            if let Option::Some(name) = player_name {
                self.token_player_names.write(token_id, name);
            }

            if let Option::Some(start_time) = start {
                self.token_lifecycle_start.write(token_id, start_time);
            }

            if let Option::Some(end_time) = end {
                self.token_lifecycle_end.write(token_id, end_time);
            }

            token_id
        }

        fn mint_batch_recipients(
            ref self: ContractState,
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
            panic!("not implemented")
        }

        fn update_game(ref self: ContractState, token_id: felt252) {}

        fn refresh_metadata(ref self: ContractState, token_id: felt252) {}

        fn update_player_name(ref self: ContractState, token_id: felt252, name: felt252) {
            self.token_player_names.write(token_id, name);
        }

        fn update_game_batch(ref self: ContractState, token_ids: Span<felt252>) {}

        fn refresh_metadata_batch(ref self: ContractState, token_ids: Span<felt252>) {}

        fn update_player_name_batch(ref self: ContractState, updates: Span<PlayerNameUpdate>) {
            let mut i = 0;
            loop {
                if i >= updates.len() {
                    break;
                }
                let update = *updates.at(i);
                self.update_player_name(update.token_id, update.name);
                i += 1;
            };
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IMINIGAME_TOKEN_LEGACY_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }
}

// Mock Minigame Contract for Tournament
#[starknet::contract]
mod MockMinigameForTournament {
    use game_components_embeddable_game_standard::minigame::interface::{
        IMINIGAME_ID, IMinigame, IMinigameTokenData,
    };
    use game_components_embeddable_game_standard::minigame::structs::MintGameParams;
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::metagame::extensions::context::structs::GameContextDetails;
    use super::IMockMinigameSetter;

    #[storage]
    struct Storage {
        token_address: ContractAddress,
        settings_address: ContractAddress,
        objectives_address: ContractAddress,
        token_scores: Map<felt252, u64>,
        token_game_over: Map<felt252, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        settings_address: ContractAddress,
        objectives_address: ContractAddress,
    ) {
        self.token_address.write(token_address);
        self.settings_address.write(settings_address);
        self.objectives_address.write(objectives_address);
    }

    #[abi(embed_v0)]
    impl MinigameImpl of IMinigame<ContractState> {
        fn token_address(self: @ContractState) -> ContractAddress {
            self.token_address.read()
        }

        fn settings_address(self: @ContractState) -> ContractAddress {
            self.settings_address.read()
        }

        fn objectives_address(self: @ContractState) -> ContractAddress {
            self.objectives_address.read()
        }

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
            1
        }

        fn mint_game_batch(self: @ContractState, mints: Array<MintGameParams>) -> Array<felt252> {
            let mut results = array![];
            let mut i: u64 = 1;
            let mut index = 0;
            loop {
                if index >= mints.len() {
                    break;
                }
                results.append(i.into());
                i += 1;
                index += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl MinigameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: felt252) -> u64 {
            self.token_scores.read(token_id)
        }

        fn game_over(self: @ContractState, token_id: felt252) -> bool {
            self.token_game_over.read(token_id)
        }

        fn score_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<u64> {
            let mut results = array![];
            let mut index = 0;
            loop {
                if index >= token_ids.len() {
                    break;
                }
                results.append(self.score(*token_ids.at(index)));
                index += 1;
            }
            results
        }

        fn game_over_batch(self: @ContractState, token_ids: Span<felt252>) -> Array<bool> {
            let mut results = array![];
            let mut index = 0;
            loop {
                if index >= token_ids.len() {
                    break;
                }
                results.append(self.game_over(*token_ids.at(index)));
                index += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IMINIGAME_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }

    #[abi(embed_v0)]
    impl MockMinigameSetterImpl of IMockMinigameSetter<ContractState> {
        fn set_score(ref self: ContractState, token_id: felt252, score: u64) {
            self.token_scores.write(token_id, score);
        }

        fn set_game_over(ref self: ContractState, token_id: felt252, game_over: bool) {
            self.token_game_over.write(token_id, game_over);
        }
    }
}
