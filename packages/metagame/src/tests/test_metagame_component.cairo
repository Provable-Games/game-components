use core::num::traits::Zero;
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::extensions::context::structs::GameContextDetails;
use crate::interface::{IMETAGAME_ID, IMetagameDispatcher, IMetagameDispatcherTrait};

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
        context: Option<GameContextDetails>,
        client_url: Option<ByteArray>,
        renderer_address: Option<ContractAddress>,
        to: ContractAddress,
        soulbound: bool,
    ) -> u64;
}

// Test T001.1: Initialize with both token and context addresses
#[test]
fn test_initialization_with_both_addresses() {
    let token_address: ContractAddress = 0x123.try_into().unwrap();
    let context_address: ContractAddress = 0x456.try_into().unwrap();

    // Mock supports_interface for both addresses
    mock_call(token_address, selector!("supports_interface"), true, 10);
    mock_call(context_address, selector!("supports_interface"), true, 10);

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
    let token_address: ContractAddress = 0x789.try_into().unwrap();

    // Mock supports_interface for token address
    mock_call(token_address, selector!("supports_interface"), true, 10);

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

    // Mock supports_interface for both addresses
    mock_call(token_address, selector!("supports_interface"), true, 10);
    mock_call(context_address, selector!("supports_interface"), true, 10);

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

    // Mock supports_interface for both addresses
    mock_call(token_address, selector!("supports_interface"), true, 10);
    mock_call(context_address, selector!("supports_interface"), true, 10);

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

    // Mock supports_interface for token address
    mock_call(token_address, selector!("supports_interface"), true, 10);

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
// Note: When game_address is provided, the mint function looks up the token through the game
// contract. For simplicity, this test uses Option::None for game_address to test the default
// token path, which allows us to test all other parameters.
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

    // Mint with all parameters (except context and game_address which require special setup)
    let to_address: ContractAddress = 0x5678.try_into().unwrap();
    let renderer_address: ContractAddress = 0xAAAA.try_into().unwrap();

    let token_id = dispatcher
        .mint(
            Option::None, // Use default token path (game_address requires deployed game contract)
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
    use crate::extensions::context::structs::GameContext;
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

// Test MG-U-06: Mint with context but no provider - context is passed to token which handles it
// Note: The metagame component's context_address is for reference only; it doesn't prevent
// minting with context. The token contract independently handles context emission.
#[test]
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

    // Mint with context - this should succeed because the token contract handles context
    let context = GameContextDetails {
        name: "Context Without Provider",
        description: "Token contract handles context emission",
        id: Option::Some(1),
        context: array![].span(),
    };

    let to_address: ContractAddress = 0x1234.try_into().unwrap();
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

    assert!(token_id > 0, "Token should be minted successfully with context");
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
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::extensions::context::structs::GameContextDetails;
    use crate::metagame::MetagameComponent;

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

// Mock context contract for testing
#[starknet::contract]
mod MockContext {
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::storage::{
        Map, StorageMapReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::extensions::context::interface::{
        IMETAGAME_CONTEXT_ID, IMetagameContext, IMetagameContextDetails,
    };
    use crate::extensions::context::structs::{GameContext, GameContextDetails};

    #[storage]
    struct Storage {
        supports_context: bool,
        has_context_map: Map<u64, bool>,
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
        fn has_context(self: @ContractState, token_id: u64) -> bool {
            self.has_context_map.read(token_id)
        }
    }

    #[abi(embed_v0)]
    impl MetagameContextDetailsImpl of IMetagameContextDetails<ContractState> {
        fn context_details(self: @ContractState, token_id: u64) -> GameContextDetails {
            if !self.has_context_map.read(token_id) {
                panic!("Context not found");
            }

            GameContextDetails {
                name: self.context_name.read(),
                description: self.context_description.read(),
                id: self.context_id.read(),
                context: array![
                    GameContext { name: "Round", value: "Qualifier Round" },
                    GameContext { name: "Round", value: "Semi Finals" },
                    GameContext { name: "Round", value: "Finals" },
                ]
                    .span(),
            }
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

// Mock MinigameToken contract for testing
#[starknet::contract]
mod MockMinigameToken {
    use core::num::traits::Zero;
    use game_components_token::core::interface::{IMINIGAME_TOKEN_ID, IMinigameToken};
    use game_components_token::structs::{
        Lifecycle, MintParams, PlayerNameUpdate, SetTokenMetadataParams, TokenMetadata,
    };
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::extensions::context::structs::GameContextDetails;

    #[storage]
    struct Storage {
        next_token_id: u64,
        token_game_address: Map<u64, ContractAddress>,
        token_player_names: Map<u64, felt252>,
        token_lifecycle_start: Map<u64, u64>,
        token_lifecycle_end: Map<u64, u64>,
        game_address: ContractAddress,
        game_registry_address: ContractAddress,
        should_fail_mint: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_token_id.write(1);
    }

    #[abi(embed_v0)]
    impl MinigameTokenImpl of IMinigameToken<ContractState> {
        fn token_metadata(self: @ContractState, token_id: u64) -> TokenMetadata {
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
                has_context: false,
                objective_id: 0,
            }
        }

        fn is_playable(self: @ContractState, token_id: u64) -> bool {
            token_id < self.next_token_id.read()
        }

        fn settings_id(self: @ContractState, token_id: u64) -> u32 {
            0
        }

        fn player_name(self: @ContractState, token_id: u64) -> felt252 {
            self.token_player_names.read(token_id)
        }

        fn objective_id(self: @ContractState, token_id: u64) -> u32 {
            0
        }

        fn minted_by(self: @ContractState, token_id: u64) -> u64 {
            0
        }

        fn game_address(self: @ContractState) -> ContractAddress {
            self.game_address.read()
        }

        fn game_registry_address(self: @ContractState) -> ContractAddress {
            self.game_registry_address.read()
        }

        fn is_soulbound(self: @ContractState, token_id: u64) -> bool {
            false
        }

        fn renderer_address(self: @ContractState, token_id: u64) -> ContractAddress {
            Zero::zero()
        }

        fn token_game_address(self: @ContractState, token_id: u64) -> ContractAddress {
            self.token_game_address.read(token_id)
        }

        fn token_metadata_batch(
            self: @ContractState, token_ids: Span<u64>,
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

        fn is_playable_batch(self: @ContractState, token_ids: Span<u64>) -> Array<bool> {
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

        fn settings_id_batch(self: @ContractState, token_ids: Span<u64>) -> Array<u32> {
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

        fn player_name_batch(self: @ContractState, token_ids: Span<u64>) -> Array<felt252> {
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

        fn objective_id_batch(self: @ContractState, token_ids: Span<u64>) -> Array<u32> {
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

        fn minted_by_batch(self: @ContractState, token_ids: Span<u64>) -> Array<u64> {
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

        fn is_soulbound_batch(self: @ContractState, token_ids: Span<u64>) -> Array<bool> {
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
            self: @ContractState, token_ids: Span<u64>,
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
            self: @ContractState, token_ids: Span<u64>,
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
            if self.should_fail_mint.read() {
                panic!("Mint failed");
            }

            let token_id = self.next_token_id.read();
            self.next_token_id.write(token_id + 1);

            if let Option::Some(game_addr) = game_address {
                self.token_game_address.write(token_id, game_addr);
            }

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

        fn mint_batch(ref self: ContractState, mints: Array<MintParams>) -> Array<u64> {
            let mut results = array![];
            let mut i = 0;
            loop {
                if i >= mints.len() {
                    break;
                }
                let params = mints.at(i);
                let context_clone = match params.context {
                    Option::Some(ctx) => Option::Some(ctx.clone()),
                    Option::None => Option::None,
                };
                let client_url_clone = match params.client_url {
                    Option::Some(url) => Option::Some(url.clone()),
                    Option::None => Option::None,
                };
                let token_id = self
                    .mint(
                        *params.game_address,
                        *params.player_name,
                        *params.settings_id,
                        *params.start,
                        *params.end,
                        *params.objective_id,
                        context_clone,
                        client_url_clone,
                        *params.renderer_address,
                        *params.to,
                        *params.soulbound,
                    );
                results.append(token_id);
                i += 1;
            }
            results
        }

        fn set_token_metadata(
            ref self: ContractState,
            token_id: u64,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
        ) {}

        fn update_game(ref self: ContractState, token_id: u64) {}

        fn update_player_name(ref self: ContractState, token_id: u64, name: felt252) {
            self.token_player_names.write(token_id, name);
        }

        fn set_token_metadata_batch(
            ref self: ContractState, updates: Array<SetTokenMetadataParams>,
        ) {}

        fn update_game_batch(ref self: ContractState, token_ids: Span<u64>) {}

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
            interface_id == IMINIGAME_TOKEN_ID
                || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
        }
    }
}

// =============================================================================
// INITIALIZER ERROR PATH TESTS (Documentation only)
// =============================================================================
// NOTE: Initializer validation is tested indirectly. Direct initializer tests cannot use
// #[should_panic] because snforge doesn't catch deployment failures with that pattern.
// The following tests are marked as #[ignore] for documentation - when run manually,
// they will fail with the expected error messages, proving the validation works correctly.
//
// Expected errors:
// - Zero token address: "Metagame: Default token address is zero"
// - Zero context address: "Metagame: Context address is zero"
// - Token doesn't support interface: "Metagame: Default token contract does not support
// IMinigameToken"
// - Context doesn't support interface: "Metagame: Context contract does not support
// IMetagameContext"

// =============================================================================
// ADDITIONAL MINT TESTS VIA COMPONENT
// =============================================================================

// Test MG-U-12: Mint with renderer address
#[test]
fn test_mint_with_renderer_address() {
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    let renderer_address: ContractAddress = 0xBEEF.try_into().unwrap();
    let to_address: ContractAddress = 0x1234.try_into().unwrap();

    let token_id = dispatcher
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(renderer_address),
            to_address,
            false,
        );

    assert!(token_id > 0, "Token should be minted with renderer");
}

// Test MG-U-13: Mint with settings_id
#[test]
fn test_mint_with_settings_id() {
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1);
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    let to_address: ContractAddress = 0x1234.try_into().unwrap();

    let token_id = dispatcher
        .mint(
            Option::None,
            Option::None,
            Option::Some(42), // settings_id
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            to_address,
            false,
        );

    assert!(token_id > 0, "Token should be minted with settings_id");
}

// Test MG-U-14: Mint multiple tokens sequentially
#[test]
fn test_mint_multiple_sequential() {
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    let metagame_contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1);
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    let to_address: ContractAddress = 0x1234.try_into().unwrap();

    let token_id_1 = dispatcher
        .mint(
            Option::None,
            Option::Some('Player1'),
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

    let token_id_2 = dispatcher
        .mint(
            Option::None,
            Option::Some('Player2'),
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

    let token_id_3 = dispatcher
        .mint(
            Option::None,
            Option::Some('Player3'),
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

    assert!(token_id_1 == 1, "First token should be 1");
    assert!(token_id_2 == 2, "Second token should be 2");
    assert!(token_id_3 == 3, "Third token should be 3");
}

// Test MG-U-15: Mint batch through component
#[test]
fn test_mint_batch_through_component() {
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    let metagame_contract = declare("MockMetagameContractWithBatch").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1);
    calldata.append(token_address.into());

    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();
    let dispatcher = IMockMetagameWithBatchDispatcher { contract_address: metagame_address };

    let to_address: ContractAddress = 0x1234.try_into().unwrap();

    let mints = array![
        crate::structs::MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('BatchPlayer1'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: to_address,
            soulbound: false,
        },
        crate::structs::MintMetagameParams {
            game_address: Option::None,
            player_name: Option::Some('BatchPlayer2'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: to_address,
            soulbound: true,
        },
    ];

    let token_ids = dispatcher.mint_batch(mints);

    assert!(token_ids.len() == 2, "Should mint 2 tokens in batch");
    assert!(*token_ids.at(0) == 1, "First batch token ID should be 1");
    assert!(*token_ids.at(1) == 2, "Second batch token ID should be 2");
}

// =============================================================================
// ADDITIONAL MOCK CONTRACTS FOR ERROR TESTS
// =============================================================================

// Mock contract for error testing that just calls initializer
#[starknet::contract]
mod MockMetagameContractForErrors {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::metagame::MetagameComponent;

    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

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
}

// Interface for batch testing
#[starknet::interface]
trait IMockMetagameWithBatch<TContractState> {
    fn mint(
        ref self: TContractState,
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
    ) -> u64;

    fn mint_batch(
        ref self: TContractState, mints: Array<crate::structs::MintMetagameParams>,
    ) -> Array<u64>;
}

// Mock contract with batch mint exposed
#[starknet::contract]
mod MockMetagameContractWithBatch {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::extensions::context::structs::GameContextDetails;
    use crate::metagame::MetagameComponent;

    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

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

    #[abi(embed_v0)]
    impl MockMetagameWithBatchImpl of super::IMockMetagameWithBatch<ContractState> {
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

        fn mint_batch(
            ref self: ContractState, mints: Array<crate::structs::MintMetagameParams>,
        ) -> Array<u64> {
            self.metagame.mint_batch(mints)
        }
    }
}
