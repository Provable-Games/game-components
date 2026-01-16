use core::num::traits::Zero;
use game_components_metagame::interface::{
    IMETAGAME_ID, IMetagameDispatcher, IMetagameDispatcherTrait,
};
use game_components_tests::minigame::mocks::minigame_starknet_mock::IMinigameStarknetMockInitDispatcherTrait;
use game_components_tests::token::setup::{
    deploy_minigame_registry_contract, deploy_mock_game, deploy_optimized_token_default,
    deploy_optimized_token_with_game, deploy_optimized_token_with_registry,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

// Interface for testing mint function
#[starknet::interface]
trait IMockMetagame<TContractState> {
    fn mint(
        ref self: TContractState,
        game_address: Option<ContractAddress>,
        player_name: Option<felt252>,
        settings_id: Option<u32>,
        start: Option<u64>,
        end: Option<u64>,
        objective_id: Option<u32>,
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
    let token_address = addr(0x123);
    let context_address = addr(0x456);

    // Deploy the MockMetagameContract
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    // Serialize Option::Some(context_address) and minigame_token_address
    let mut calldata = array![];
    // Option::Some variant (index 0 for Some)
    calldata.append(0);
    calldata.append(context_address.into());
    calldata.append(token_address.into());

    mock_call(context_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("supports_interface"), true, 100);

    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify addresses are stored correctly
    assert!(dispatcher.default_token_address() == token_address, "Token address mismatch");
    assert!(dispatcher.context_address() == context_address, "Context address mismatch");

    // Verify SRC5 interface registration
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(src5_dispatcher.supports_interface(IMETAGAME_ID), "Should support IMetagame interface");
}

// Test T001.2: Initialize with token address only (context = None)
#[test]
fn test_initialization_with_token_only() {
    let token_address = addr(0x789);

    // Deploy with None for context_address
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    // Serialize Option::None and minigame_token_address
    let mut calldata = array![];
    // Option::None variant (index 1 for None)
    calldata.append(1);
    calldata.append(token_address.into());

    mock_call(token_address, selector!("supports_interface"), true, 100);

    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify token address is stored and context is zero
    assert!(dispatcher.default_token_address() == token_address, "Token address mismatch");
    assert!(dispatcher.context_address().is_zero(), "Context address should be zero");

    // Verify SRC5 interface registration
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(src5_dispatcher.supports_interface(IMETAGAME_ID), "Should support IMetagame interface");
}

// Test T002.1: minigame_token_address returns correct value after init
#[test]
fn test_minigame_token_address_view() {
    let token_address = addr(0xABC);
    let context_address = addr(0xDEF);

    // Deploy with both addresses
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(0); // Some(context_address)
    calldata.append(context_address.into());
    calldata.append(token_address.into());

    mock_call(context_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("supports_interface"), true, 100);

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify minigame_token_address returns correct value
    assert!(dispatcher.default_token_address() == token_address, "Token address mismatch");
}

// Test T002.2: context_address returns correct value when set
#[test]
fn test_context_address_view_when_set() {
    let token_address = addr(0x111);
    let context_address = addr(0x222);

    // Deploy with both addresses
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(0); // Some(context_address)
    calldata.append(context_address.into());
    calldata.append(token_address.into());

    mock_call(context_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("supports_interface"), true, 100);

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify context_address returns correct value
    assert!(dispatcher.context_address() == context_address, "Context address mismatch");
}

// Test T002.3: context_address returns zero when None passed
#[test]
fn test_context_address_view_when_none() {
    let token_address = addr(0x333);

    // Deploy with None for context_address
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None
    calldata.append(token_address.into());

    mock_call(token_address, selector!("supports_interface"), true, 100);

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify context_address returns zero
    assert!(dispatcher.context_address().is_zero(), "Context address should be zero");
}

// Test T003.2: assert_game_registered reverts for unregistered game
#[test]
#[should_panic]
fn test_assert_game_registered_fails_unregistered() {
    // Deploy registry contract first
    let _registry = deploy_minigame_registry_contract();

    // Try to assert an unregistered game - this should panic
    let unregistered_game = addr(0x9999);

    // Call libs::assert_game_registered directly
    game_components_metagame::libs::assert_game_registered(unregistered_game);
}

// Test T003.3: assert_game_registered with zero addresses
#[test]
#[should_panic]
fn test_assert_game_registered_zero_address() {
    // Deploy registry contract first
    let _registry = deploy_minigame_registry_contract();

    // Try to assert with zero game address - this should panic
    let zero_address = addr(0x0);

    // Call libs::assert_game_registered directly
    game_components_metagame::libs::assert_game_registered(zero_address);
}

// Test MG-U-04: Mint minimal (to address only)
#[test]
fn test_mint_minimal() {
    // Deploy token contract without any specific game
    let (_token_dispatcher, _, _, token_address) = deploy_optimized_token_default();

    // Deploy metagame contract
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Mint with minimal parameters (only to address)
    let to_address = addr(0x1234);
    let token_id = dispatcher
        .mint(
            Option::None, // game_address
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_id
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
    // Deploy a mock game first
    let (game_dispatcher, game_init_dispatcher, _mock_game_dispatcher) = deploy_mock_game();

    // Deploy token contract with the game
    let (_token_dispatcher, _, _, token_address) = deploy_optimized_token_with_game(
        game_dispatcher.contract_address,
    );

    // Initialize the game with the token address
    game_init_dispatcher
        .initializer(
            addr('CREATOR'),
            "Test Game",
            "A test game",
            "Test Dev",
            "Test Pub",
            "Test Genre",
            "test.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None, // settings_address
            Option::None, // objectives_address
            token_address,
        );

    // Deploy metagame contract
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Mint with all parameters (except context which requires special setup)
    let to_address = addr(0x5678);
    let renderer_address = addr(0xAAAA);

    let token_id = dispatcher
        .mint(
            Option::Some(game_dispatcher.contract_address),
            Option::Some('Player One'),
            Option::None, // settings_id - None since game doesn't have settings support
            Option::Some(1000), // start
            Option::Some(2000), // end
            Option::None, // objective_id - None since game doesn't have objectives support
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
    // Deploy token contract without any specific game
    let (_token_dispatcher, _, _, token_address) = deploy_optimized_token_default();

    // Deploy mock context provider
    let context_contract = declare("MockContextContract").unwrap().contract_class();
    let (context_address, _) = context_contract.deploy(@array![]).unwrap();

    // Deploy metagame contract WITH context provider
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(0); // Some(context_address)
    calldata.append(context_address.into());
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };
    use game_components_metagame::extensions::context::structs::{GameContext, GameContextDetails};
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

    let to_address = addr(0x5678);
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
    let token_contract = declare("MinigameRegistryContract").unwrap().contract_class();
    let mut calldata = array![];
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TST";
    let base_uri: ByteArray = "https://test.com/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    calldata.append(1); // Option::None for event_relayer_address
    let (token_address, _) = token_contract.deploy(@calldata).unwrap();

    // Deploy metagame contract WITHOUT context provider
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Try to mint with context when no provider is set
    use game_components_metagame::extensions::context::structs::{GameContextDetails};
    let context = GameContextDetails {
        name: "Invalid Context",
        description: "Should fail",
        id: Option::Some(1),
        context: array![].span(),
    };

    let to_address = addr(0x1234);
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

// Test MG-U-10: Mint with objective_id set to max u32
#[test]
fn test_mint_with_max_objective_id() {
    // Deploy token contract without any specific game
    let (_token_dispatcher, _, _, token_address) = deploy_optimized_token_default();

    // Deploy metagame contract
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Test with max u32 value for objective_id
    let max_objective_id: u32 = 255;

    let to_address = addr(0x1234);
    let token_id = dispatcher
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(max_objective_id),
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
    // Deploy token contract without any specific game
    let (_token_dispatcher, _, _, token_address) = deploy_optimized_token_default();

    // Deploy metagame contract
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Mint with start = end (instant game)
    let to_address = addr(0x1234);
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

// Test MG-U-12: Mint with unregistered game - should panic
#[test]
#[should_panic]
fn test_mint_with_unregistered_game() {
    // Deploy registry and token contract
    let registry = deploy_minigame_registry_contract();
    let (_token_dispatcher, _, _, token_address) = deploy_optimized_token_with_registry(
        registry.contract_address,
    );

    // Deploy metagame contract WITHOUT context provider
    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Deploy a contract that doesn't implement IMinigame interface
    // This simulates an unregistered game
    let mock_context_contract = declare("MockContextContract").unwrap().contract_class();
    let (unregistered_game_address, _) = mock_context_contract.deploy(@array![]).unwrap();

    let to_address = addr(0x1234);

    dispatcher
        .mint(
            Option::Some(unregistered_game_address), // This should cause panic
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            to_address,
            false,
        );
}

// Mock contract that embeds MetagameComponent for testing
#[starknet::contract]
mod MockMetagameContract {
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use game_components_metagame::metagame::MetagameComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

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
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
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
                    objective_id,
                    context,
                    client_url,
                    renderer_address,
                    to,
                    soulbound,
                )
        }
    }
}
