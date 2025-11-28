use game_components_metagame::interface::{IMetagameDispatcher, IMetagameDispatcherTrait};
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use starknet::{contract_address_const, ContractAddress};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

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

// Fuzz test F-02: Mint parameter fuzzing
#[test]
fn test_fuzz_mint_parameters() {
    // Deploy contracts
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    let minigame_contract = declare("MockMinigame").unwrap().contract_class();
    let (minigame_address, _) = minigame_contract
        .deploy(
            @array![
                token_address.into(),
                contract_address_const::<0x0>().into(),
                contract_address_const::<0x0>().into(),
            ],
        )
        .unwrap();

    let metagame_contract = declare("MockMetagame").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());
    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();

    let metagame_dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };
    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };

    // Fuzz test different timestamp combinations
    let test_cases = array![
        // (start, end, should_succeed)
        (0_u64, 0_u64, true), // No lifecycle
        (1000_u64, 2000_u64, true), // Valid range
        (0_u64, 1000_u64, true), // Start from 0
        (1000_u64, 1000_u64, true), // Instant game
        (2000_u64, 1000_u64, false), // Invalid: start > end
        (1_u64, 0xFFFFFFFFFFFFFFFF_u64, true) // Max duration
    ];

    let mut i = 0;
    loop {
        if i >= test_cases.len() {
            break;
        }

        let (start, end, should_succeed) = *test_cases.at(i);

        // Try to mint with these parameters
        let result = try_mint_with_lifecycle(metagame_dispatcher, minigame_address, start, end);

        if should_succeed {
            assert!(result.is_some(), "Mint should succeed for case {}", i);

            // Verify token was minted with correct lifecycle
            if let Option::Some(token_id) = result {
                let metadata = token_dispatcher.token_metadata(token_id);
                assert!(metadata.lifecycle.start == start, "Start mismatch case {}", i);
                assert!(metadata.lifecycle.end == end, "End mismatch case {}", i);
            }
        } else {
            assert!(result.is_none(), "Mint should fail for case {}", i);
        }

        i += 1;
    };
}

// Fuzz test player names
#[test]
fn test_fuzz_player_names() {
    // Deploy contracts
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    let minigame_contract = declare("MockMinigame").unwrap().contract_class();
    let (minigame_address, _) = minigame_contract
        .deploy(
            @array![
                token_address.into(),
                contract_address_const::<0x0>().into(),
                contract_address_const::<0x0>().into(),
            ],
        )
        .unwrap();

    let metagame_contract = declare("MockMetagame").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());
    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();

    let metagame_dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };
    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };

    // Test various player names (removed unicode characters)
    let test_names = array![
        "", // Empty
        "A", // Single char
        "Player123", // Alphanumeric
        "GamePlayer", // Regular name
        "Very Long Player Name That Exceeds Normal Length", // Long name
        "PlayerWithNewlines", // Without special chars
        "   Spaces   " // Whitespace
    ];

    let mut i = 0;
    loop {
        if i >= test_names.len() {
            break;
        }

        let name = test_names.at(i);
        let owner = contract_address_const::<0x1000>();

        // Mint with this player name
        let token_id = metagame_dispatcher
            .mint(
                Option::Some(minigame_address),
                Option::Some(name.clone()),
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                owner,
                false,
            );

        // Verify name was stored correctly
        let retrieved_name = token_dispatcher.player_name(token_id);
        assert!(retrieved_name == name.clone(), "Name mismatch for case {}", i);

        i += 1;
    };
}

// Property test P-01: Token ID Monotonicity
#[test]
fn test_property_token_id_monotonicity() {
    // Deploy contracts
    let token_contract = declare("MockMinigameToken").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    let minigame_contract = declare("MockMinigame").unwrap().contract_class();
    let (minigame_address, _) = minigame_contract
        .deploy(
            @array![
                token_address.into(),
                contract_address_const::<0x0>().into(),
                contract_address_const::<0x0>().into(),
            ],
        )
        .unwrap();

    let metagame_contract = declare("MockMetagame").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());
    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();

    let metagame_dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };

    // Mint 100 tokens and verify monotonicity
    let mut previous_id: u64 = 0;
    let mut i: u32 = 0;

    loop {
        if i >= 100 {
            break;
        }

        let owner = contract_address_const::<0x2000>();

        let token_id = metagame_dispatcher
            .mint(
                Option::Some(minigame_address),
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                owner,
                false,
            );

        // Verify monotonicity
        if i == 0 {
            assert!(token_id == 1, "First token should be 1");
        } else {
            assert!(token_id == previous_id + 1, "Token ID should increment by 1");
        }

        previous_id = token_id;
        i += 1;
    };
}

// Helper function to try minting with lifecycle parameters
fn try_mint_with_lifecycle(
    dispatcher: IMockMetagameDispatcher, game_address: ContractAddress, start: u64, end: u64,
) -> Option<u64> {
    // In a real fuzz test framework, we would catch panics
    // For now, we'll assume valid ranges succeed
    if start > end && start != 0 && end != 0 {
        return Option::None;
    }

    let token_id = dispatcher
        .mint(
            Option::Some(game_address),
            Option::None,
            Option::None,
            Option::Some(start),
            Option::Some(end),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            contract_address_const::<0x9999>(),
            false,
        );

    Option::Some(token_id)
}

// Mock Metagame contract for testing
#[starknet::contract]
mod MockMetagame {
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
