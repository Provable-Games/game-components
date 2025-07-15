use game_components_metagame::interface::{
    IMetagameDispatcher, IMetagameDispatcherTrait, IMETAGAME_ID,
};
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::{ContractAddress, contract_address_const};
use core::num::traits::Zero;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use game_components_token::extensions::multi_game::interface::{
    IMinigameTokenMultiGameDispatcher, IMinigameTokenMultiGameDispatcherTrait,
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
        context: Option<game_components_metagame::extensions::context::structs::GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
}

// Test T001.1: Initialize with both token and context addresses
#[test]
fn test_initialization_with_both_addresses() {
    let token_address = contract_address_const::<0x123>();
    let context_address = contract_address_const::<0x456>();

    // Deploy the MockMetagameContract
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    // Serialize Option::Some(context_address) and minigame_token_address
    let mut calldata = array![];
    // Option::Some variant (index 0 for Some)
    calldata.append(0);
    calldata.append(context_address.into());
    calldata.append(token_address.into());

    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify addresses are stored correctly
    assert!(dispatcher.minigame_token_address() == token_address, "Token address mismatch");
    assert!(dispatcher.context_address() == context_address, "Context address mismatch");

    // Verify SRC5 interface registration
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(src5_dispatcher.supports_interface(IMETAGAME_ID), "Should support IMetagame interface");
}

// Test T001.2: Initialize with token address only (context = None)
#[test]
fn test_initialization_with_token_only() {
    let token_address = contract_address_const::<0x789>();

    // Deploy with None for context_address
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    // Serialize Option::None and minigame_token_address
    let mut calldata = array![];
    // Option::None variant (index 1 for None)
    calldata.append(1);
    calldata.append(token_address.into());

    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify token address is stored and context is zero
    assert!(dispatcher.minigame_token_address() == token_address, "Token address mismatch");
    assert!(dispatcher.context_address().is_zero(), "Context address should be zero");

    // Verify SRC5 interface registration
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(src5_dispatcher.supports_interface(IMETAGAME_ID), "Should support IMetagame interface");
}

// Test T002.1: minigame_token_address returns correct value after init
#[test]
fn test_minigame_token_address_view() {
    let token_address = contract_address_const::<0xABC>();
    let context_address = contract_address_const::<0xDEF>();

    // Deploy with both addresses
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(0); // Some(context_address)
    calldata.append(context_address.into());
    calldata.append(token_address.into());

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify minigame_token_address returns correct value
    assert!(dispatcher.minigame_token_address() == token_address, "Token address mismatch");
}

// Test T002.2: context_address returns correct value when set
#[test]
fn test_context_address_view_when_set() {
    let token_address = contract_address_const::<0x111>();
    let context_address = contract_address_const::<0x222>();

    // Deploy with both addresses
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(0); // Some(context_address)
    calldata.append(context_address.into());
    calldata.append(token_address.into());

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify context_address returns correct value
    assert!(dispatcher.context_address() == context_address, "Context address mismatch");
}

// Test T002.3: context_address returns zero when None passed
#[test]
fn test_context_address_view_when_none() {
    let token_address = contract_address_const::<0x333>();

    // Deploy with None for context_address
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None
    calldata.append(token_address.into());

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify context_address returns zero
    assert!(dispatcher.context_address().is_zero(), "Context address should be zero");
}

// Test T003.1: assert_game_registered succeeds for registered game
#[test]
fn test_assert_game_registered_success() {
    // Deploy mock token contract
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // Register a game in the token contract
    let game_address = contract_address_const::<0x1234>();
    let token_dispatcher = IMinigameTokenMultiGameDispatcher { contract_address: token_address };
    token_dispatcher
        .register_game(
            game_address,
            "Test Game",
            "Test Description",
            "Test Developer",
            "Test Publisher",
            "Test Genre",
            "Test Image",
            Option::None,
            Option::None,
            Option::None,
        );

    // Call libs::assert_game_registered directly - should not panic
    game_components_metagame::libs::assert_game_registered(token_address, game_address);
    // If we get here, the test passed (no panic occurred)
}

// Test T003.2: assert_game_registered reverts for unregistered game
#[test]
#[should_panic]
fn test_assert_game_registered_fails_unregistered() {
    // Deploy mock token contract
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // Deploy metagame contract
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (_metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();

    // Try to assert an unregistered game - this should panic
    let unregistered_game = contract_address_const::<0x9999>();

    // Call libs::assert_game_registered directly
    game_components_metagame::libs::assert_game_registered(token_address, unregistered_game);
}

// Test T003.3: assert_game_registered with zero addresses
#[test]
#[should_panic]
fn test_assert_game_registered_zero_address() {
    // Deploy mock token contract
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // Try to assert with zero game address - this should panic
    let zero_address = contract_address_const::<0x0>();

    // Call libs::assert_game_registered directly
    game_components_metagame::libs::assert_game_registered(token_address, zero_address);
}

// Test MG-U-04: Mint minimal (to address only)
#[test]
fn test_mint_minimal() {
    // Deploy mock token contract
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // Deploy metagame contract
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Mint with minimal parameters (only to address)
    let to_address = contract_address_const::<0x1234>();
    let token_id = dispatcher
        .mint(
            Option::None, // game_address
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_ids
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            to_address,
            false // soulbound
        );

    assert!(token_id == 1, "First token ID should be 1");
}

// Test MG-U-05: Mint with all parameters (except context)
#[test]
fn test_mint_with_all_parameters() {
    // Deploy mock token contract
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // Deploy metagame contract
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Mint with all parameters (except context which requires special setup)
    let to_address = contract_address_const::<0x5678>();
    let game_address = contract_address_const::<0x9999>();
    let renderer_address = contract_address_const::<0xAAAA>();

    let token_id = dispatcher
        .mint(
            Option::Some(game_address),
            Option::Some("Player One"),
            Option::Some(1), // settings_id
            Option::Some(1000), // start
            Option::Some(2000), // end
            Option::Some(array![1, 2, 3].span()), // objective_ids
            Option::None, // context (requires special setup)
            Option::Some("https://game.example.com"),
            Option::Some(renderer_address),
            to_address,
            true // soulbound
        );

    assert!(token_id > 0, "Token ID should be valid");
}

// Test MG-U-05b: Mint with context when provider is set
#[test]
fn test_mint_with_context_provider_set() {
    // Deploy mock token contract
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // Deploy mock context provider
    let context_contract = declare("MockContext").unwrap().contract_class();
    let (context_address, _) = context_contract
        .deploy(@array![1])
        .unwrap(); // supports_context = true

    // Deploy metagame contract WITH context provider
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(0); // Some(context_address)
    calldata.append(context_address.into());
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
    let context = GameContextDetails {
        name: "Test Tournament",
        description: "A test tournament",
        id: Option::Some(42),
        context: array![
            GameContext { name: "Prize", value: "1000 USD" },
            GameContext { name: "Duration", value: "7 days" },
        ]
            .span(),
    };

    let to_address = contract_address_const::<0x5678>();
    let token_id = dispatcher
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(context),
            Option::None,
            Option::None,
            to_address,
            false,
        );

    assert!(token_id > 0, "Token ID should be valid with context");
}

// Test MG-U-06: Mint with context but no provider
#[test]
#[should_panic]
fn test_mint_with_context_no_provider() {
    // Deploy mock token contract
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // Deploy metagame contract WITHOUT context provider
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Try to mint with context when no provider is set
    use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
    let context = GameContextDetails {
        name: "Invalid Context",
        description: "Should fail",
        id: Option::Some(1),
        context: array![].span(),
    };

    let to_address = contract_address_const::<0x1234>();
    dispatcher
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(context), // This should cause panic
            Option::None,
            Option::None,
            to_address,
            false,
        );
}

// Test MG-U-10: Mint with max objectives (255)
#[test]
fn test_mint_with_max_objectives() {
    // Deploy mock token contract
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // Deploy metagame contract
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Create array with 255 objectives
    let mut objectives = array![];
    let mut i: u32 = 0;
    loop {
        if i == 255 {
            break;
        }
        objectives.append(i);
        i += 1;
    };

    let to_address = contract_address_const::<0x1234>();
    let token_id = dispatcher
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objectives.span()),
            Option::None,
            Option::None,
            Option::None,
            to_address,
            false,
        );

    assert!(token_id > 0, "Token should be minted successfully");
}

// Test MG-U-11: Mint with start = end
#[test]
fn test_mint_with_instant_game() {
    // Deploy mock token contract
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    // Deploy metagame contract
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Mint with start = end (instant game)
    let to_address = contract_address_const::<0x1234>();
    let timestamp = 1000_u64;

    let token_id = dispatcher
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::Some(timestamp), // start
            Option::Some(timestamp), // end (same as start)
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            to_address,
            false,
        );

    assert!(token_id > 0, "Token should be minted successfully");
}

// Mock contract that embeds MetagameComponent for testing
#[starknet::contract]
mod MockMetagameContract {
    use game_components_metagame::metagame::MetagameComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use game_components_metagame::extensions::context::structs::GameContextDetails;

    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Embed the implementations
    #[abi(embed_v0)]
    impl MetagameImpl = MetagameComponent::MetagameImpl<ContractState>;
    impl MetagameInternalImpl = MetagameComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

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
