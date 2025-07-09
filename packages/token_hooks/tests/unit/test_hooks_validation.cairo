use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, set_block_timestamp};
use snforge_std::{declare, ContractClassTrait};
use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use game_components_token::structs::TokenMetadata;

// Mock token contract with validation hooks
#[starknet::contract]
mod MockTokenWithValidation {
    use starknet::ContractAddress;
    use game_components_token::token::TokenComponent;
    use game_components_token::interface::IMinigameToken;
    use game_components_token::structs::TokenMetadata;
    use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
    use game_components_minigame::extensions::settings::interface::{IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait};
    use game_components_minigame::extensions::objectives::interface::{IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait};
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};

    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;
    impl TokenInternalImpl = TokenComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        token: TokenComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        settings_address: ContractAddress,
        objectives_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        TokenEvent: TokenComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: Option<ContractAddress>,
        settings_address: ContractAddress,
        objectives_address: ContractAddress,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.token.initializer(game_address);
        self.settings_address.write(settings_address);
        self.objectives_address.write(objectives_address);
    }

    impl TokenHooks of TokenComponent::TokenHooksTrait<ContractState> {
        fn before_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            game_address: Option<ContractAddress>,
            settings_id: Option<u32>,
            objective_ids: Option<Span<u32>>,
        ) -> (u64, u32, u32) {
            let contract_state = TokenComponent::HasComponent::get_contract(@self);
            
            // Validate game address if provided
            if let Option::Some(addr) = game_address {
                let src5 = ISRC5Dispatcher { contract_address: addr };
                assert!(
                    src5.supports_interface(game_components_minigame::interface::IMINIGAME_ID),
                    "Invalid game address"
                );
            }
            
            // Validate settings if provided
            let validated_settings_id = if let Option::Some(id) = settings_id {
                if id > 0 {
                    let settings_dispatcher = IMinigameSettingsDispatcher { 
                        contract_address: contract_state.settings_address.read() 
                    };
                    let settings = settings_dispatcher.settings(id);
                    assert!(settings.is_valid, "Invalid settings ID");
                    id
                } else {
                    0
                }
            } else {
                0
            };
            
            // Validate objectives if provided
            let objectives_count = if let Option::Some(ids) = objective_ids {
                assert!(ids.len() <= 255, "Too many objectives");
                let objectives_dispatcher = IMinigameObjectivesDispatcher { 
                    contract_address: contract_state.objectives_address.read() 
                };
                
                let mut i = 0;
                loop {
                    if i >= ids.len() {
                        break;
                    }
                    let objective = objectives_dispatcher.objective(*ids.at(i));
                    assert!(objective.is_valid, "Invalid objective ID");
                    i += 1;
                };
                
                ids.len()
            } else {
                0
            };
            
            (0, validated_settings_id, objectives_count.try_into().unwrap())
        }
        
        fn after_mint(
            ref self: TokenComponent::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u64,
            caller_address: ContractAddress,
            game_address: Option<ContractAddress>,
            token_metadata: TokenMetadata,
        ) {}
        
        fn before_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
            token_metadata: TokenMetadata,
        ) -> ContractAddress {
            self.game_address.read()
        }
        
        fn after_update_game(
            ref self: TokenComponent::ComponentState<ContractState>,
            token_id: u64,
        ) -> bool {
            false
        }
    }
}

fn deploy_token_with_validation() -> (IMinigameTokenDispatcher, ContractAddress, ContractAddress) {
    // Deploy mock settings
    let settings_contract = declare("MockSettings").unwrap();
    let (settings_address, _) = settings_contract.deploy(@array![]).unwrap();
    
    // Deploy mock objectives
    let objectives_contract = declare("MockObjectives").unwrap();
    let (objectives_address, _) = objectives_contract.deploy(@array![]).unwrap();
    
    // Deploy mock game
    let game_contract = declare("MockMinigame").unwrap();
    let (game_address, _) = game_contract.deploy(@array![]).unwrap();
    
    // Deploy token with validation hooks
    let token_contract = declare("MockTokenWithValidation").unwrap();
    let (token_address, _) = token_contract.deploy(@array![
        'TestToken', 'TST', 'https://test.com/', 
        game_address.into(),
        settings_address.into(),
        objectives_address.into()
    ]).unwrap();
    
    (IMinigameTokenDispatcher { contract_address: token_address }, settings_address, objectives_address)
}

// UT-H-02: Validation hooks
#[test]
fn test_unit_hooks_validation_valid_inputs() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _, _) = deploy_token_with_validation();
    
    set_caller_address(user1);
    
    // Valid settings (1 and 2 are pre-populated in MockSettings)
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::Some(1),  // Valid settings ID
        Option::None,
        Option::None,
        Option::Some(array![1, 2, 3].span()),  // Valid objectives
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    let metadata = token.token_metadata(token_id);
    assert!(metadata.settings_id == 1, "Settings ID should be validated and stored");
    assert!(metadata.objectives_count == 3, "Objectives should be validated and counted");
}

#[test]
#[should_panic(expected: 'Invalid settings ID')]
fn test_unit_hooks_validation_invalid_settings() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _, _) = deploy_token_with_validation();
    
    set_caller_address(user1);
    
    token.mint(
        Option::None,
        Option::None,
        Option::Some(999),  // Invalid settings ID
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
}

#[test]
#[should_panic(expected: 'Invalid objective ID')]
fn test_unit_hooks_validation_invalid_objectives() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _, _) = deploy_token_with_validation();
    
    set_caller_address(user1);
    
    token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(array![1, 2, 999].span()),  // 999 is invalid
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
}

#[test]
#[should_panic(expected: 'Invalid game address')]
fn test_unit_hooks_validation_invalid_game() {
    let user1 = contract_address_const::<'user1'>();
    let invalid_game = contract_address_const::<'not_a_game'>();
    let (token, _, _) = deploy_token_with_validation();
    
    set_caller_address(user1);
    
    token.mint(
        Option::Some(invalid_game),  // Not a valid game contract
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
}

#[test]
fn test_unit_hooks_validation_lifecycle() {
    let user1 = contract_address_const::<'user1'>();
    let (token, _, _) = deploy_token_with_validation();
    
    set_caller_address(user1);
    
    // Test that lifecycle validation happens (this would be in the token component itself)
    // The validation hooks don't validate lifecycle, but we test it doesn't interfere
    let token_id = token.mint(
        Option::None,
        Option::None,
        Option::None,
        Option::Some(1000),
        Option::Some(2000),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        user1,
        false
    );
    
    let metadata = token.token_metadata(token_id);
    assert!(metadata.lifecycle.start == 1000, "Start time should be set");
    assert!(metadata.lifecycle.end == 2000, "End time should be set");
}