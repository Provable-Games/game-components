use game_components_metagame::interface::IMetagameDispatcher;
use game_components_minigame::interface::IMinigameDispatcher;
use game_components_test_starknet::metagame::mocks::metagame_starknet_mock::{
    IMetagameStarknetMockDispatcher, IMetagameStarknetMockInitDispatcher,
    IMetagameStarknetMockInitDispatcherTrait,
};
use game_components_test_starknet::minigame::mocks::minigame_starknet_mock::{
    IMinigameStarknetMockDispatcher, IMinigameStarknetMockInitDispatcher,
    IMinigameStarknetMockInitDispatcherTrait,
};
use game_components_token::examples::minigame_registry_contract::IMinigameRegistryDispatcher;
use game_components_token::interface::IMinigameTokenMixinDispatcher;
use openzeppelin_interfaces::erc721::ERC721ABIDispatcher;
use openzeppelin_interfaces::introspection::ISRC5Dispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::token::mocks::mock_game::IMockGameDispatcher;

// ================================================================================================
// TEST CONSTANTS
// ================================================================================================

// Test addresses - using try_into().unwrap() pattern instead of deprecated contract_address_const
pub fn ALICE() -> ContractAddress {
    'ALICE'.try_into().unwrap()
}

pub fn BOB() -> ContractAddress {
    'BOB'.try_into().unwrap()
}

pub fn CHARLIE() -> ContractAddress {
    'CHARLIE'.try_into().unwrap()
}

pub fn ZERO_ADDRESS() -> ContractAddress {
    0.try_into().unwrap()
}

pub fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

pub fn RENDERER_ADDRESS() -> ContractAddress {
    'RENDERER'.try_into().unwrap()
}

// Edge case values
pub const MAX_U64: u64 = 18446744073709551615;
pub const MAX_U32: u32 = 4294967295;

// Time constants
pub const PAST_TIME: u64 = 100;
pub const CURRENT_TIME: u64 = 1000;
pub const FUTURE_TIME: u64 = 2000;
pub const FAR_FUTURE_TIME: u64 = 3000;

// ================================================================================================
// TEST CONTRACTS STRUCT
// ================================================================================================

#[derive(Drop)]
pub struct TestContracts {
    pub minigame_registry: IMinigameRegistryDispatcher,
    pub minigame: IMinigameDispatcher,
    pub mock_minigame: IMinigameStarknetMockDispatcher,
    pub test_token: IMinigameTokenMixinDispatcher,
    pub erc721: ERC721ABIDispatcher,
    pub src5: ISRC5Dispatcher,
    pub metagame_mock: IMetagameStarknetMockDispatcher,
}

// ================================================================================================
// MOCK CONTRACT DEPLOYMENT HELPERS
// ================================================================================================

/// Deploy minigame_starknet_mock contract
pub fn deploy_mock_game() -> (
    IMinigameDispatcher, IMinigameStarknetMockInitDispatcher, IMinigameStarknetMockDispatcher,
) {
    let contract = declare("minigame_starknet_mock").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let minigame_dispatcher = IMinigameDispatcher { contract_address };
    let minigame_init_dispatcher = IMinigameStarknetMockInitDispatcher { contract_address };
    let minigame_mock_dispatcher = IMinigameStarknetMockDispatcher { contract_address };
    (minigame_dispatcher, minigame_init_dispatcher, minigame_mock_dispatcher)
}

/// Deploy basic MockGame contract
pub fn deploy_basic_mock_game() -> (IMinigameDispatcher, IMockGameDispatcher) {
    let contract = declare("MockGame").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let minigame_dispatcher = IMinigameDispatcher { contract_address };
    let mock_game_dispatcher = IMockGameDispatcher { contract_address };
    (minigame_dispatcher, mock_game_dispatcher)
}

/// Deploy metagame_starknet_mock contract
pub fn deploy_mock_metagame_contract() -> (
    IMetagameDispatcher, IMetagameStarknetMockInitDispatcher, IMetagameStarknetMockDispatcher,
) {
    let contract = declare("metagame_starknet_mock").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let metagame_dispatcher = IMetagameDispatcher { contract_address };
    let metagame_init_dispatcher = IMetagameStarknetMockInitDispatcher { contract_address };
    let metagame_mock_dispatcher = IMetagameStarknetMockDispatcher { contract_address };
    (metagame_dispatcher, metagame_init_dispatcher, metagame_mock_dispatcher)
}

/// Deploy MinigameRegistryContract with default parameters
pub fn deploy_minigame_registry_contract() -> IMinigameRegistryDispatcher {
    deploy_minigame_registry_contract_with_params("GameCreatorToken", "GCT", "", Option::None)
}

/// Deploy MinigameRegistryContract with custom parameters
pub fn deploy_minigame_registry_contract_with_params(
    name: ByteArray,
    symbol: ByteArray,
    base_uri: ByteArray,
    event_relayer_address: Option<ContractAddress>,
) -> IMinigameRegistryDispatcher {
    let contract = declare("MinigameRegistryContract").unwrap().contract_class();

    let mut constructor_calldata = array![];
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    base_uri.serialize(ref constructor_calldata);

    // Serialize event_relayer_address Option
    match event_relayer_address {
        Option::Some(addr) => {
            constructor_calldata.append(0); // Some variant
            constructor_calldata.append(addr.into());
        },
        Option::None => {
            constructor_calldata.append(1); // None variant
        },
    }

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    let minigame_registry_dispatcher = IMinigameRegistryDispatcher { contract_address };
    minigame_registry_dispatcher
}

/// Deploy MockContextProvider contract (for testing context functionality)
pub fn deploy_mock_context_provider() -> ContractAddress {
    let contract = declare("MockContextProvider").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

/// Deploy MockMetagameWithContext contract
pub fn deploy_mock_metagame_with_context(
    context_address: Option<ContractAddress>, minigame_token_address: ContractAddress,
) -> IMetagameDispatcher {
    let contract = declare("MockMetagameWithContext").unwrap().contract_class();

    let mut constructor_calldata = array![];

    // Serialize context_address Option
    match context_address {
        Option::Some(addr) => {
            constructor_calldata.append(0); // Some variant
            constructor_calldata.append(addr.into());
        },
        Option::None => {
            constructor_calldata.append(1); // None variant
        },
    }

    constructor_calldata.append(minigame_token_address.into());

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    IMetagameDispatcher { contract_address }
}

/// Deploy standalone MockGame contract (returns just the address)
pub fn deploy_mock_game_standalone() -> ContractAddress {
    let contract = declare("MockGame").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

// ================================================================================================
// OPTIMIZED TOKEN CONTRACT DEPLOYMENT HELPERS
// ================================================================================================

/// Deploy FullTokenContract with customizable parameters
///
/// # Arguments
/// * `name` - Token name (defaults to "TestToken" if None)
/// * `symbol` - Token symbol (defaults to "TT" if None)
/// * `base_uri` - Base URI for token metadata (defaults to "https://test.com/" if None)
/// * `game_address` - Optional game contract address
/// * `game_registry_address` - Optional game registry address
/// * `event_relayer_address` - Optional event relayer address
///
/// # Returns
/// Tuple of (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress)
pub fn deploy_full_token_contract(
    name: Option<ByteArray>,
    symbol: Option<ByteArray>,
    base_uri: Option<ByteArray>,
    royalty_receiver: Option<ContractAddress>,
    royalty_fraction: Option<u128>,
    game_registry_address: Option<ContractAddress>,
    event_relayer_address: Option<ContractAddress>,
) -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress) {
    let contract = declare("FullTokenContract").unwrap().contract_class();

    let mut constructor_calldata = array![];

    // Set default values if not provided
    let token_name: ByteArray = match name {
        Option::Some(n) => n,
        Option::None => "TestToken",
    };

    let token_symbol: ByteArray = match symbol {
        Option::Some(s) => s,
        Option::None => "TT",
    };

    let token_base_uri: ByteArray = match base_uri {
        Option::Some(uri) => uri,
        Option::None => "https://test.com/",
    };

    // Serialize basic parameters
    token_name.serialize(ref constructor_calldata);
    token_symbol.serialize(ref constructor_calldata);
    token_base_uri.serialize(ref constructor_calldata);

    let royalty_receiver = match royalty_receiver {
        Option::Some(addr) => { addr },
        Option::None => OWNER(),
    };

    let royalty_fraction = match royalty_fraction {
        Option::Some(fraction) => { fraction },
        Option::None => 0,
    };

    royalty_receiver.serialize(ref constructor_calldata);
    royalty_fraction.serialize(ref constructor_calldata);

    // Serialize game_registry_address Option
    match game_registry_address {
        Option::Some(addr) => {
            constructor_calldata.append(0); // Some variant
            constructor_calldata.append(addr.into());
        },
        Option::None => {
            constructor_calldata.append(1); // None variant
        },
    }

    // Serialize event_relayer_address Option
    match event_relayer_address {
        Option::Some(addr) => {
            constructor_calldata.append(0); // Some variant
            constructor_calldata.append(addr.into());
        },
        Option::None => {
            constructor_calldata.append(1); // None variant
        },
    }

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    let token_dispatcher = IMinigameTokenMixinDispatcher { contract_address };
    let erc721_dispatcher = ERC721ABIDispatcher { contract_address };
    let src5_dispatcher = ISRC5Dispatcher { contract_address };

    (token_dispatcher, erc721_dispatcher, src5_dispatcher, contract_address)
}

// ================================================================================================
// SINGLE GAME TOKEN CONTRACT DEPLOYMENT HELPERS
// ================================================================================================

/// Deploy SingleGameTokenContract with customizable parameters
///
/// # Arguments
/// * `name` - Token name (defaults to "TestToken" if None)
/// * `symbol` - Token symbol (defaults to "TT" if None)
/// * `base_uri` - Base URI for token metadata (defaults to "https://test.com/" if None)
/// * `royalty_receiver` - Address to receive royalties
/// * `royalty_fraction` - Royalty fraction (basis points)
/// * `game_address` - Game contract address (required for single-game tokens)
/// * `creator_address` - Creator address for initial mint
/// * `event_relayer_address` - Optional event relayer address
///
/// # Returns
/// Tuple of (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress)
pub fn deploy_single_game_token_contract(
    name: Option<ByteArray>,
    symbol: Option<ByteArray>,
    base_uri: Option<ByteArray>,
    royalty_receiver: Option<ContractAddress>,
    royalty_fraction: Option<u128>,
    game_address: ContractAddress,
    creator_address: ContractAddress,
    event_relayer_address: Option<ContractAddress>,
) -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress) {
    let contract = declare("SingleGameTokenContract").unwrap().contract_class();

    let mut constructor_calldata = array![];

    // Set default values if not provided
    let token_name: ByteArray = match name {
        Option::Some(n) => n,
        Option::None => "TestToken",
    };

    let token_symbol: ByteArray = match symbol {
        Option::Some(s) => s,
        Option::None => "TT",
    };

    let token_base_uri: ByteArray = match base_uri {
        Option::Some(uri) => uri,
        Option::None => "https://test.com/",
    };

    // Serialize basic parameters
    token_name.serialize(ref constructor_calldata);
    token_symbol.serialize(ref constructor_calldata);
    token_base_uri.serialize(ref constructor_calldata);

    let royalty_receiver = match royalty_receiver {
        Option::Some(addr) => addr,
        Option::None => OWNER(),
    };

    let royalty_fraction = match royalty_fraction {
        Option::Some(fraction) => fraction,
        Option::None => 0,
    };

    royalty_receiver.serialize(ref constructor_calldata);
    royalty_fraction.serialize(ref constructor_calldata);
    game_address.serialize(ref constructor_calldata);
    creator_address.serialize(ref constructor_calldata);

    // Serialize event_relayer_address Option
    match event_relayer_address {
        Option::Some(addr) => {
            constructor_calldata.append(0); // Some variant
            constructor_calldata.append(addr.into());
        },
        Option::None => {
            constructor_calldata.append(1); // None variant
        },
    }

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    let token_dispatcher = IMinigameTokenMixinDispatcher { contract_address };
    let erc721_dispatcher = ERC721ABIDispatcher { contract_address };
    let src5_dispatcher = ISRC5Dispatcher { contract_address };

    (token_dispatcher, erc721_dispatcher, src5_dispatcher, contract_address)
}

/// Deploy SingleGameTokenContract with default parameters
pub fn deploy_single_game_token_default(
    game_address: ContractAddress,
) -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress) {
    deploy_single_game_token_contract(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        game_address,
        OWNER(),
        Option::None,
    )
}

// ================================================================================================
// CONVENIENCE FUNCTIONS
// ================================================================================================

/// Deploy FullTokenContract with default parameters and a default registry
pub fn deploy_optimized_token_default() -> (
    IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress,
) {
    // Deploy a default registry for multi-game token scenario
    let registry = deploy_minigame_registry_contract();
    deploy_full_token_contract(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(registry.contract_address),
        Option::None,
    )
}

/// Deploy SingleGameTokenContract with game address for single-game scenario
pub fn deploy_optimized_token_with_game(
    game_address: ContractAddress,
) -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress) {
    // For single-game token scenarios, use SingleGameTokenContract which supports
    // direct game address without requiring a registry
    deploy_single_game_token_contract(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        game_address,
        OWNER(),
        Option::None,
    )
}

/// Deploy FullTokenContract with game and registry addresses
pub fn deploy_optimized_token_with_game_and_registry(
    game_address: ContractAddress, registry_address: ContractAddress,
) -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress) {
    deploy_full_token_contract(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(registry_address),
        Option::None,
    )
}

/// Deploy FullTokenContract with registry address only (for multi-game scenarios)
pub fn deploy_optimized_token_with_registry(
    registry_address: ContractAddress,
) -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress) {
    deploy_full_token_contract(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(registry_address),
        Option::None,
    )
}

/// Deploy FullTokenContract with custom name/symbol/uri but no addresses
pub fn deploy_optimized_token_custom_metadata(
    name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
) -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress) {
    let minigame_registry_dispatcher = deploy_minigame_registry_contract();
    deploy_full_token_contract(
        Option::Some(name),
        Option::Some(symbol),
        Option::Some(base_uri),
        Option::None,
        Option::None,
        Option::Some(minigame_registry_dispatcher.contract_address),
        Option::None,
    )
}

// ================================================================================================
// COMPLETE TEST SETUP FUNCTIONS
// ================================================================================================

/// Deploy test token contract with game - wrapper for backward compatibility
pub fn deploy_test_token_contract_with_game_registry(
    game_registry_address: Option<ContractAddress>, event_relay_address: Option<ContractAddress>,
) -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress) {
    deploy_full_token_contract(
        Option::Some("TestToken"),
        Option::Some("TT"),
        Option::Some("https://test.com/token/"),
        Option::None,
        Option::None,
        game_registry_address,
        event_relay_address,
    )
}

/// Deploy single-game test token contract with game address
pub fn deploy_test_token_contract_with_game(
    game_address: ContractAddress, event_relay_address: Option<ContractAddress>,
) -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress) {
    deploy_single_game_token_contract(
        Option::Some("TestToken"),
        Option::Some("TT"),
        Option::Some("https://test.com/token/"),
        Option::None,
        Option::None,
        game_address,
        OWNER(),
        event_relay_address,
    )
}

/// Deploy test token contract - wrapper for backward compatibility
pub fn deploy_test_token_contract() -> (
    IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ISRC5Dispatcher, ContractAddress,
) {
    deploy_optimized_token_default()
}

/// Complete test setup with all contracts initialized
/// Uses SingleGameTokenContract for single-game scenarios
pub fn setup() -> TestContracts {
    let (minigame_dispatcher, minigame_init_dispatcher, mock_minigame_dispatcher) =
        deploy_mock_game();
    let (_metagame_dispatcher, metagame_init_dispatcher, metagame_mock_dispatcher) =
        deploy_mock_metagame_contract();
    let minigame_registry_dispatcher = deploy_minigame_registry_contract();

    // Use SingleGameTokenContract for single-game tests
    let (test_token_dispatcher, erc721_dispatcher, src5_dispatcher, _) =
        deploy_single_game_token_contract(
        Option::Some("TestToken"),
        Option::Some("TT"),
        Option::Some("https://test.com/token/"),
        Option::None,
        Option::None,
        minigame_dispatcher.contract_address,
        OWNER(),
        Option::None,
    );

    // Initialize the minigame mock
    minigame_init_dispatcher
        .initializer(
            OWNER(),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(minigame_init_dispatcher.contract_address),
            Option::Some(minigame_init_dispatcher.contract_address),
            test_token_dispatcher.contract_address,
        );

    // Mock the supports_interface call for the context address
    mock_call(
        metagame_init_dispatcher.contract_address, selector!("supports_interface"), true, 100,
    );

    metagame_init_dispatcher
        .initializer(
            Option::Some(metagame_init_dispatcher.contract_address),
            test_token_dispatcher.contract_address,
            true,
        );

    TestContracts {
        minigame: minigame_dispatcher,
        mock_minigame: mock_minigame_dispatcher,
        minigame_registry: minigame_registry_dispatcher,
        test_token: test_token_dispatcher,
        erc721: erc721_dispatcher,
        src5: src5_dispatcher,
        metagame_mock: metagame_mock_dispatcher,
    }
}

/// Setup multi-game test environment
pub fn setup_multi_game() -> TestContracts {
    let minigame_registry_dispatcher = deploy_minigame_registry_contract();
    let (test_token_dispatcher, erc721_dispatcher, src5_dispatcher, _) =
        deploy_test_token_contract_with_game_registry(
        Option::Some(minigame_registry_dispatcher.contract_address), Option::None,
    );

    // Deploy and register multiple games
    let (game1_dispatcher, game1_init_dispatcher, mock1_dispatcher) = deploy_mock_game();
    let (_game2_dispatcher, game2_init_dispatcher, _mock2_dispatcher) = deploy_mock_game();
    let (_metagame_dispatcher, _metagame_init_dispatcher, metagame_mock_dispatcher) =
        deploy_mock_metagame_contract();

    // Initialize game 1 (registers in init)
    game1_init_dispatcher
        .initializer(
            OWNER(),
            "Game1",
            "Description1",
            "Developer1",
            "Publisher1",
            "Genre1",
            "Image1",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            test_token_dispatcher.contract_address,
        );

    // Initialize game 2 (registers in init)
    game2_init_dispatcher
        .initializer(
            OWNER(),
            "Game2",
            "Description2",
            "Developer2",
            "Publisher2",
            "Genre2",
            "Image2",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            test_token_dispatcher.contract_address,
        );

    TestContracts {
        minigame: game1_dispatcher,
        mock_minigame: mock1_dispatcher,
        minigame_registry: minigame_registry_dispatcher,
        test_token: test_token_dispatcher,
        erc721: erc721_dispatcher,
        src5: src5_dispatcher,
        metagame_mock: metagame_mock_dispatcher,
    }
}

/// Simple deployment helper for integration tests - returns token, token address, and game address
pub fn deploy_simple_setup() -> (IMinigameTokenMixinDispatcher, ContractAddress, ContractAddress) {
    // Deploy mock game
    let game_address = deploy_mock_game_standalone();

    // Deploy single-game token with the game address
    let (token_dispatcher, _, _, token_address) = deploy_single_game_token_default(game_address);

    (token_dispatcher, token_address, game_address)
}

/// Deploy MockSettingsContract (for testing settings functionality)
pub fn deploy_mock_settings_contract() -> ContractAddress {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

/// Deploy TokenWithSettings contract
pub fn deploy_token_with_settings(settings_address: ContractAddress) -> ContractAddress {
    let contract = declare("TokenWithSettings").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(settings_address.into());
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

/// Deploy MinimalOptimizedContract
pub fn deploy_minimal_optimized_contract(
    name: ByteArray,
    symbol: ByteArray,
    base_uri: ByteArray,
    game_address: Option<ContractAddress>,
    creator_address: Option<ContractAddress>,
) -> (IMinigameTokenMixinDispatcher, ERC721ABIDispatcher) {
    let contract = declare("MinimalOptimizedContract").unwrap().contract_class();
    let mut constructor_calldata = array![];

    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    base_uri.serialize(ref constructor_calldata);

    // Serialize game_address Option
    match game_address {
        Option::Some(addr) => {
            constructor_calldata.append(0); // Some variant
            constructor_calldata.append(addr.into());
        },
        Option::None => {
            constructor_calldata.append(1); // None variant
        },
    }

    // Serialize creator_address Option
    match creator_address {
        Option::Some(addr) => {
            constructor_calldata.append(0); // Some variant
            constructor_calldata.append(addr.into());
        },
        Option::None => {
            constructor_calldata.append(1); // None variant
        },
    }

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    let token_dispatcher = IMinigameTokenMixinDispatcher { contract_address };
    let erc721_dispatcher = ERC721ABIDispatcher { contract_address };

    (token_dispatcher, erc721_dispatcher)
}

/// Deploy MockObjectivesContract (for testing objectives functionality)
pub fn deploy_mock_objectives_contract() -> ContractAddress {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}
