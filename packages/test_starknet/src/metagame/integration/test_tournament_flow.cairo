use game_components_metagame::interface::{IMetagameDispatcher, IMetagameDispatcherTrait};
use game_components_metagame::extensions::context::interface::{
    IMetagameContextDispatcher, IMetagameContextDispatcherTrait,
};
use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
use starknet::{contract_address_const, get_caller_address, get_block_timestamp, ContractAddress};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_caller_address,
};

// Integration test I-01: Tournament Flow
#[test]
fn test_tournament_flow() {
    // 1. Deploy token contract with multi-game support
    let token_contract = declare("MockTokenContract").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // 2. Deploy context provider contract
    let context_contract = declare("MockContext").unwrap().contract_class();
    let (context_address, _) = context_contract.deploy(@array![1]).unwrap();

    // 3. Deploy metagame with context
    let metagame_contract = declare("MockMetagameWithContext").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(0); // Some(context_address)
    calldata.append(context_address.into());
    calldata.append(token_address.into());
    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();

    // 4. Deploy 3 different games
    let game1 = declare("MockMinigame").unwrap().contract_class();
    let (game1_address, _) = game1
        .deploy(
            @array![
                token_address.into(),
                contract_address_const::<0x0>().into(),
                contract_address_const::<0x0>().into(),
            ],
        )
        .unwrap();

    let (game2_address, _) = game1
        .deploy(
            @array![
                token_address.into(),
                contract_address_const::<0x0>().into(),
                contract_address_const::<0x0>().into(),
            ],
        )
        .unwrap();

    let (game3_address, _) = game1
        .deploy(
            @array![
                token_address.into(),
                contract_address_const::<0x0>().into(),
                contract_address_const::<0x0>().into(),
            ],
        )
        .unwrap();

    // 5. Register games with token contract
    let multi_game_dispatcher = IMinigameTokenMultiGameDispatcher {
        contract_address: token_address,
    };
    multi_game_dispatcher
        .register_game(
            game1_address,
            "Game 1",
            "First tournament game",
            "Dev1",
            "Publisher1",
            "Action",
            "game1.png",
            Option::None,
            Option::None,
            Option::None,
        );

    multi_game_dispatcher
        .register_game(
            game2_address,
            "Game 2",
            "Second tournament game",
            "Dev2",
            "Publisher2",
            "Strategy",
            "game2.png",
            Option::None,
            Option::None,
            Option::None,
        );

    multi_game_dispatcher
        .register_game(
            game3_address,
            "Game 3",
            "Third tournament game",
            "Dev3",
            "Publisher3",
            "Puzzle",
            "game3.png",
            Option::None,
            Option::None,
            Option::None,
        );

    // 6. Create tournament context
    let tournament_context = GameContextDetails {
        name: "Winter Tournament 2024",
        description: "Annual championship",
        id: Option::Some(1),
        context: array![
            GameContext { name: "Round", value: "Qualifier Round" },
            GameContext { name: "Round", value: "Semi Finals" },
            GameContext { name: "Round", value: "Finals" },
        ]
            .span(),
    };

    // 7. Create players
    let player1 = contract_address_const::<0x1001>();
    let player2 = contract_address_const::<0x1002>();
    let player3 = contract_address_const::<0x1003>();

    // 8. Mint tokens for players across games using the metagame dispatcher
    let metagame_dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Player 1 - Games 1 and 2
    start_cheat_caller_address(metagame_address, player1);
    let p1_g1_token = metagame_dispatcher
        .mint(
            Option::Some(game1_address),
            Option::Some("Player1"),
            Option::None,
            Option::Some(1000),
            Option::Some(10000),
            Option::None,
            Option::Some(tournament_context.clone()),
            Option::None,
            Option::None,
            player1,
            false,
        );

    let p1_g2_token = metagame_dispatcher
        .mint(
            Option::Some(game2_address),
            Option::Some("Player1"),
            Option::None,
            Option::Some(1000),
            Option::Some(10000),
            Option::None,
            Option::Some(tournament_context.clone()),
            Option::None,
            Option::None,
            player1,
            false,
        );
    stop_cheat_caller_address(metagame_address);

    // Player 2 - All games
    start_cheat_caller_address(metagame_address, player2);
    let p2_g1_token = metagame_dispatcher
        .mint(
            Option::Some(game1_address),
            Option::Some("Player2"),
            Option::None,
            Option::Some(1000),
            Option::Some(10000),
            Option::None,
            Option::Some(tournament_context.clone()),
            Option::None,
            Option::None,
            player2,
            false,
        );

    let p2_g2_token = metagame_dispatcher
        .mint(
            Option::Some(game2_address),
            Option::Some("Player2"),
            Option::None,
            Option::Some(1000),
            Option::Some(10000),
            Option::None,
            Option::Some(tournament_context.clone()),
            Option::None,
            Option::None,
            player2,
            false,
        );

    let p2_g3_token = metagame_dispatcher
        .mint(
            Option::Some(game3_address),
            Option::Some("Player2"),
            Option::None,
            Option::Some(1000),
            Option::Some(10000),
            Option::None,
            Option::Some(tournament_context.clone()),
            Option::None,
            Option::None,
            player2,
            false,
        );
    stop_cheat_caller_address(metagame_address);

    // 9. Verify all tokens have context
    let context_dispatcher = IMetagameContextDispatcher { contract_address: context_address };
    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };

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

    // 12. Verify game isolation
    let p1_g1_metadata = token_dispatcher.token_metadata(p1_g1_token);
    let p2_g3_metadata = token_dispatcher.token_metadata(p2_g3_token);

    assert!(p1_g1_metadata.game_id == 1, "P1 G1 should be game 1");
    assert!(p2_g3_metadata.game_id == 3, "P2 G3 should be game 3");

    // 13. Verify context consistency across all tokens
    let retrieved_context = context_dispatcher.context(p1_g1_token);
    assert!(retrieved_context.name == "Winter Tournament 2024", "Context name mismatch");
    assert!(retrieved_context.context.len() == 3, "Should have 3 tournament rounds");
}

// Mock contracts for integration testing
#[starknet::contract]
mod MockMetagameWithContext {
    use game_components_metagame::metagame::MetagameComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use game_components_metagame::extensions::context::structs::GameContextDetails;

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
        self.metagame.initializer(context_address, minigame_token_address);
    }

    // Expose mint function for testing
    #[abi(embed_v0)]
    impl MockMetagameImpl of super::IMockMetagame<ContractState> {
        fn mint(
            ref self: ContractState,
            game_address: Option<ContractAddress>,
            player_name: Option<ByteArray>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_ids: Option<Span<u32>>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            self
                .metagame
                .mint(
                    game_address,
                    player_name,
                    settings_id,
                    start,
                    end,
                    objective_ids,
                    context,
                    client_url,
                    renderer_address,
                    to,
                    soulbound,
                )
        }
    }
}

// Helper interfaces
use game_components_token::extensions::multi_game::interface::{
    IMinigameTokenMultiGame, IMinigameTokenMultiGameDispatcher,
    IMinigameTokenMultiGameDispatcherTrait,
};

// Interface for testing mint function
#[starknet::interface]
trait IMockMetagame<TContractState> {
    fn mint(
        ref self: TContractState,
        game_address: Option<ContractAddress>,
        player_name: Option<ByteArray>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_ids: Option<Span<u32>>,
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
}

#[starknet::interface]
trait IContextSetter<TContractState> {
    fn store_context(ref self: TContractState, token_id: u64, context: GameContextDetails);
}

#[starknet::interface]
trait IMockMinigameSetter<TContractState> {
    fn set_score(ref self: TContractState, token_id: u64, score: u32);
    fn set_game_over(ref self: TContractState, token_id: u64, game_over: bool);
}
