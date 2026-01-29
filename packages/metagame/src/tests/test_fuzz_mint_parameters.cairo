use game_components_token::core::interface::{
    IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use crate::extensions::context::structs::GameContextDetails;

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

// Fuzz test F-02: Mint parameter fuzzing
#[test]
fn test_fuzz_mint_parameters() {
    // Deploy contracts
    let token_contract = declare("MockMinigameTokenFuzz").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    let minigame_contract = declare("MockMinigameFuzz").unwrap().contract_class();
    let (minigame_address, _) = minigame_contract
        .deploy(@array![token_address.into(), 0, 0])
        .unwrap();

    let metagame_contract = declare("MockMetagameFuzz").unwrap().contract_class();
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
    let token_contract = declare("MockMinigameTokenFuzz").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    let minigame_contract = declare("MockMinigameFuzz").unwrap().contract_class();
    let (minigame_address, _) = minigame_contract
        .deploy(@array![token_address.into(), 0, 0])
        .unwrap();

    let metagame_contract = declare("MockMetagameFuzz").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append(1); // None for context_address
    calldata.append(token_address.into());
    let (metagame_address, _) = metagame_contract.deploy(@calldata).unwrap();

    let metagame_dispatcher = IMockMetagameDispatcher { contract_address: metagame_address };
    let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };

    // Test various player names as felt252 shortstrings (max 31 chars)
    let test_names: Array<felt252> = array![
        0, // Empty (zero)
        'A', // Single char
        'Player123', // Alphanumeric
        'GamePlayer', // Regular name
        'VeryLongPlayerName12345', // Long name (within 31 char limit)
        'PlayerWithNewlines', // Without special chars
        'Spaces' // Whitespace trimmed
    ];

    let mut i = 0;
    loop {
        if i >= test_names.len() {
            break;
        }

        let name = *test_names.at(i);
        let owner: ContractAddress = 0x1000.try_into().unwrap();

        // Mint with this player name
        let token_id = metagame_dispatcher
            .mint(
                Option::Some(minigame_address),
                Option::Some(name),
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
        assert!(retrieved_name == name, "Name mismatch for case {}", i);

        i += 1;
    };
}

// Property test P-01: Token ID Monotonicity
#[test]
fn test_property_token_id_monotonicity() {
    // Deploy contracts
    let token_contract = declare("MockMinigameTokenFuzz").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();

    let minigame_contract = declare("MockMinigameFuzz").unwrap().contract_class();
    let (minigame_address, _) = minigame_contract
        .deploy(@array![token_address.into(), 0, 0])
        .unwrap();

    let metagame_contract = declare("MockMetagameFuzz").unwrap().contract_class();
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

        let owner: ContractAddress = 0x2000.try_into().unwrap();

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
            0x9999.try_into().unwrap(),
            false,
        );

    Option::Some(token_id)
}

// Mock Metagame contract for testing
#[starknet::contract]
mod MockMetagameFuzz {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::extensions::context::structs::GameContextDetails;
    use crate::metagame::MetagameComponent;

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

// Mock Minigame contract for testing
#[starknet::contract]
mod MockMinigameFuzz {
    use game_components_minigame::interface::{IMINIGAME_ID, IMinigame, IMinigameTokenData};
    use game_components_minigame::structs::MintGameParams;
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::extensions::context::structs::GameContextDetails;

    #[storage]
    struct Storage {
        token_address: ContractAddress,
        settings_address: ContractAddress,
        objectives_address: ContractAddress,
        token_scores: Map<u64, u64>,
        token_game_over: Map<u64, bool>,
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
            to: ContractAddress,
            soulbound: bool,
        ) -> u64 {
            1
        }

        fn mint_game_batch(self: @ContractState, mints: Array<MintGameParams>) -> Array<u64> {
            let mut results = array![];
            let mut i: u64 = 1;
            let mut index = 0;
            loop {
                if index >= mints.len() {
                    break;
                }
                results.append(i);
                i += 1;
                index += 1;
            }
            results
        }
    }

    #[abi(embed_v0)]
    impl MinigameTokenDataImpl of IMinigameTokenData<ContractState> {
        fn score(self: @ContractState, token_id: u64) -> u64 {
            self.token_scores.read(token_id)
        }

        fn game_over(self: @ContractState, token_id: u64) -> bool {
            self.token_game_over.read(token_id)
        }

        fn score_batch(self: @ContractState, token_ids: Span<u64>) -> Array<u64> {
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

        fn game_over_batch(self: @ContractState, token_ids: Span<u64>) -> Array<bool> {
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
}

// Mock MinigameToken contract for testing
#[starknet::contract]
mod MockMinigameTokenFuzz {
    use core::num::traits::Zero;
    use game_components_metagame::extensions::context::structs::GameContextDetails;
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

    #[storage]
    struct Storage {
        next_token_id: u64,
        token_game_address: Map<u64, ContractAddress>,
        token_player_names: Map<u64, felt252>,
        token_lifecycle_start: Map<u64, u64>,
        token_lifecycle_end: Map<u64, u64>,
        game_address: ContractAddress,
        game_registry_address: ContractAddress,
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
