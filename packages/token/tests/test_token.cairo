#[cfg(test)]
mod tests {
    use starknet::{ContractAddress, get_block_timestamp};
    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait, ContractClass,
        start_cheat_caller_address, stop_cheat_caller_address,
        start_cheat_block_timestamp, stop_cheat_block_timestamp,
    };
    use game_components_token::interface::{IMinigameToken, IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
    use game_components_token::structs::{TokenMetadata, Lifecycle};
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    // use super::test_contracts::{BasicTokenContract, MultiGameTokenContract};
    use super::super::mocks::{
        setup_mock_minigame, setup_mock_settings, setup_mock_objectives,
        MockMinigameContractTrait, MockSettingsContractTrait, MockObjectivesContractTrait
    };
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

    // Helper function to deploy basic token contract
    fn deploy_basic_token(game_address: ContractAddress) -> IMinigameTokenDispatcher {
        let contract = declare("BasicTestTokenContract").unwrap().contract_class();
        let mut calldata = array![];
        calldata.append_serde('TestToken');
        calldata.append_serde('TST');
        calldata.append_serde('https://test.com/');
        calldata.append_serde(Option::Some(game_address));
        
        let (contract_address, _) = contract.deploy(@calldata).unwrap();
        IMinigameTokenDispatcher { contract_address }
    }

    // Helper function to deploy multi-game token contract  
    fn deploy_multi_game_token() -> IMinigameTokenDispatcher {
        let contract = declare("BasicTestTokenContract").unwrap().contract_class();
        let mut calldata = array![];
        calldata.append_serde('MultiGameToken');
        calldata.append_serde('MGT');
        calldata.append_serde('https://test.com/');
        calldata.append_serde(Option::None::<ContractAddress>);
        
        let (contract_address, _) = contract.deploy(@calldata).unwrap();
        IMinigameTokenDispatcher { contract_address }
    }

    #[test]
    fn test_basic_mint() {
        // Setup mock game
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Mint token without any parameters
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_ids
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            recipient,
            false, // soulbound
        );
        
        assert!(token_id == 1, "First token should have ID 1");
        
        // Verify token metadata
        let metadata = token.token_metadata(token_id);
        assert!(metadata.game_id == 0, "Game ID should be 0 for basic token");
        assert!(metadata.settings_id == 0, "Settings ID should be 0 when not provided");
        assert!(metadata.lifecycle.start == 0, "Start time should be 0 when not provided");
        assert!(metadata.lifecycle.end == 0, "End time should be 0 when not provided");
        assert!(!metadata.soulbound, "Token should not be soulbound");
        assert!(!metadata.game_over, "Game should not be over initially");
        assert!(!metadata.completed_all_objectives, "Objectives should not be completed initially");
        assert!(metadata.objectives_count == 0, "Should have 0 objectives");
    }

    #[test]
    fn test_mint_with_player_name() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        let player_name: ByteArray = "Alice";
        
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::Some(player_name.clone()),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Verify player name is stored
        let stored_name = token.player_name(token_id);
        assert!(stored_name == player_name, "Player name should be stored correctly");
    }

    #[test]
    fn test_mint_with_lifecycle() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        let start_time: u64 = 1000;
        let end_time: u64 = 2000;
        
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::Some(start_time),
            Option::Some(end_time),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        let metadata = token.token_metadata(token_id);
        assert!(metadata.lifecycle.start == start_time, "Start time should match");
        assert!(metadata.lifecycle.end == end_time, "End time should match");
    }

    #[test]
    fn test_is_playable() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Set current time to 1500
        start_cheat_block_timestamp(token.contract_address, 1500);
        
        // Mint token with lifecycle
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::Some(1000_u64), // start
            Option::Some(2000_u64), // end
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Token should be playable (current time is between start and end)
        assert!(token.is_playable(token_id), "Token should be playable within lifecycle");
        
        // Change time to before start
        start_cheat_block_timestamp(token.contract_address, 500);
        assert!(!token.is_playable(token_id), "Token should not be playable before start");
        
        // Change time to after end
        start_cheat_block_timestamp(token.contract_address, 2500);
        assert!(!token.is_playable(token_id), "Token should not be playable after end");
        
        stop_cheat_block_timestamp(token.contract_address);
    }

    #[test]
    fn test_update_game() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Mint token
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Setup game state
        mock_game.mock_game_over(token_id, true);
        
        // Update game should complete without error
        token.update_game(token_id);
        
        // Note: In a real implementation, update_game would update the token's game_over state
        // But since our basic token doesn't have objectives, it just validates the token exists
    }

    #[test]
    fn test_settings_id() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let mock_settings = setup_mock_settings();
        let token = deploy_multi_game_token();
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Mock settings exist
        mock_settings.mock_settings_exist(5, true);
        
        // Mint token with settings
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::Some(5_u32), // settings_id
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Verify settings ID
        let settings_id = token.settings_id(token_id);
        assert!(settings_id == 5, "Settings ID should match");
    }

    #[test]
    fn test_multiple_tokens() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient1 = starknet::contract_address_const::<'RECIPIENT1'>();
        let recipient2 = starknet::contract_address_const::<'RECIPIENT2'>();
        
        // Mint first token
        let token_id1 = token.mint(
            Option::Some(mock_game.contract_address),
            Option::Some("Player1"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient1,
            false,
        );
        
        // Mint second token
        let token_id2 = token.mint(
            Option::Some(mock_game.contract_address),
            Option::Some("Player2"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient2,
            false,
        );
        
        assert!(token_id1 == 1, "First token ID should be 1");
        assert!(token_id2 == 2, "Second token ID should be 2");
        
        // Verify different player names
        assert!(token.player_name(token_id1) == "Player1", "First player name should match");
        assert!(token.player_name(token_id2) == "Player2", "Second player name should match");
    }

    #[test]
    fn test_token_metadata_minted_at() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Set specific timestamp
        let mint_time: u64 = 12345;
        start_cheat_block_timestamp(token.contract_address, mint_time);
        
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        let metadata = token.token_metadata(token_id);
        assert!(metadata.minted_at == mint_time, "Minted at timestamp should match block time");
        
        stop_cheat_block_timestamp(token.contract_address);
    }

    #[test]
    fn test_soulbound_token() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Mint soulbound token
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            true, // soulbound
        );
        
        let metadata = token.token_metadata(token_id);
        assert!(metadata.soulbound, "Token should be marked as soulbound");
    }

    #[test]
    #[should_panic(expected: "MinigameToken: Token id 999 not minted")]
    fn test_update_nonexistent_token() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        
        // Try to update non-existent token
        token.update_game(999);
    }

    #[test]
    #[should_panic(expected: "MinigameToken: Selected game address does not match initialized game address")]
    fn test_mint_wrong_game_address() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        let wrong_game = starknet::contract_address_const::<'WRONG_GAME'>();
        
        // Try to mint with different game address
        token.mint(
            Option::Some(wrong_game),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
    }
}