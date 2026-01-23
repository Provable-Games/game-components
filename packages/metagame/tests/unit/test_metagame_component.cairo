use core::num::traits::Zero;
use game_components_metagame::interface::{
    IMETAGAME_ID, IMetagameDispatcher, IMetagameDispatcherTrait,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

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
    let token_address = 0x123.try_into().unwrap();
    let context_address = 0x456.try_into().unwrap();

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
    assert!(dispatcher.default_token_address() == token_address, "Token address mismatch");
    assert!(dispatcher.context_address() == context_address, "Context address mismatch");

    // Verify SRC5 interface registration
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(src5_dispatcher.supports_interface(IMETAGAME_ID), "Should support IMetagame interface");
}

// Test T001.2: Initialize with token address only (context = None)
#[test]
fn test_initialization_with_token_only() {
    let token_address = 0x789.try_into().unwrap();

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
    assert!(dispatcher.default_token_address() == token_address, "Token address mismatch");
    assert!(dispatcher.context_address().is_zero(), "Context address should be zero");

    // Verify SRC5 interface registration
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(src5_dispatcher.supports_interface(IMETAGAME_ID), "Should support IMetagame interface");
}

// Test T002.1: minigame_token_address returns correct value after init
#[test]
fn test_minigame_token_address_view() {
    let token_address: ContractAddress = 0xABC.try_into().unwrap();
    let context_address: ContractAddress = 0xDEF.try_into().unwrap();

    // Deploy with both addresses
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(0); // Some(context_address)
    calldata.append(context_address.into());
    calldata.append(token_address.into());

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IMetagameDispatcher { contract_address };

    // Verify minigame_token_address returns correct value
    assert!(dispatcher.default_token_address() == token_address, "Token address mismatch");
}

// Test T002.2: context_address returns correct value when set
#[test]
fn test_context_address_view_when_set() {
    let token_address: ContractAddress = 0x111.try_into().unwrap();
    let context_address: ContractAddress = 0x222.try_into().unwrap();

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
    let token_address: ContractAddress = 0x333.try_into().unwrap();

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
// NOTE: This test requires a full minigame setup with IMinigame interface implementation
// that returns a token_address which has a game_registry. Skipping for now.
// #[test]
// fn test_assert_game_registered_success() {
//     // Would need to deploy: MockMinigame -> MockMinigameToken -> MockGameRegistry
//     // and register the game in the registry
// }

// Test T003.2: assert_game_registered reverts for unregistered game
// NOTE: Same as above - requires full minigame infrastructure
// #[test]
// #[should_panic]
// fn test_assert_game_registered_fails_unregistered() {
// }

// Test T003.3: assert_game_registered with zero addresses
// NOTE: Same as above - requires full minigame infrastructure
// #[test]
// #[should_panic]
// fn test_assert_game_registered_zero_address() {
// }

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
    let to_address = 0x1234.try_into().unwrap();
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
    let to_address = 0x5678.try_into().unwrap();
    let game_address = 0x9999.try_into().unwrap();
    let renderer_address = 0xAAAA.try_into().unwrap();

    let token_id = dispatcher
        .mint(
            Option::Some(game_address),
            Option::Some('Player One'),
            Option::Some(1), // settings_id
            Option::Some(1000), // start
            Option::Some(2000), // end
            Option::Some(1), // objective_id
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

    let to_address = 0x5678.try_into().unwrap();
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
    use game_components_metagame::extensions::context::structs::{GameContextDetails};
    let context = GameContextDetails {
        name: "Invalid Context",
        description: "Should fail",
        id: Option::Some(1),
        context: array![].span(),
    };

    let to_address = 0x1234.try_into().unwrap();
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

// Test MG-U-10: Mint with objective_id
// Note: objective_ids was changed to objective_id (single u32)
#[test]
fn test_mint_with_objective_id() {
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

    let to_address = 0x1234.try_into().unwrap();
    let token_id = dispatcher
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(42), // objective_id
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
    let to_address = 0x1234.try_into().unwrap();
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
