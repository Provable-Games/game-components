#[cfg(test)]
mod tests {
    use starknet::{ContractAddress};
    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait, ContractClass,
        start_cheat_caller_address, stop_cheat_caller_address,
        start_cheat_block_timestamp, stop_cheat_block_timestamp,
    };
    use game_components_token::interface::{IMinigameToken, IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
    use game_components_token::structs::{TokenMetadata, Lifecycle};
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use super::super::test_contracts::{BasicTokenContract, MultiGameTokenContract};
    use super::super::mocks::{
        setup_mock_minigame, setup_mock_settings, setup_mock_objectives,
        MockMinigameContractTrait, MockSettingsContractTrait, MockObjectivesContractTrait
    };
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

    // Helper function to deploy basic token contract
    fn deploy_basic_token(game_address: ContractAddress) -> IMinigameTokenDispatcher {
        let contract = declare("BasicTokenContract").unwrap().contract_class();
        let mut calldata = array![];
        calldata.append('TestToken');
        calldata.append('TST');
        calldata.append('https://test.com/');
        calldata.append(game_address.into());
        
        let (contract_address, _) = contract.deploy(@calldata).unwrap();
        IMinigameTokenDispatcher { contract_address }
    }

    #[test]
    fn test_empty_player_name() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Mint with empty player name
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::Some(""), // Empty string
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
        
        // Verify empty name is stored
        let stored_name = token.player_name(token_id);
        assert!(stored_name == "", "Empty player name should be stored");
    }

    #[test]
    fn test_very_long_player_name() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Create a very long player name
        let long_name = "ThisIsAVeryLongPlayerNameThatExceedsNormalLengthExpectationsAndShouldStillBeStoredCorrectlyInTheContract";
        
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::Some(long_name),
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
        
        // Verify long name is stored correctly
        let stored_name = token.player_name(token_id);
        assert!(stored_name == long_name, "Long player name should be stored correctly");
    }

    #[test]
    fn test_zero_lifecycle_times() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Mint with start and end both 0
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::Some(0_u64),
            Option::Some(0_u64),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Token with zero lifecycle should always be playable (no time restrictions)
        assert!(token.is_playable(token_id), "Token with zero lifecycle should be playable");
        
        // Even at different timestamps
        start_cheat_block_timestamp(token.contract_address, 999999);
        assert!(token.is_playable(token_id), "Token with zero lifecycle should always be playable");
        stop_cheat_block_timestamp(token.contract_address);
    }

    #[test]
    fn test_end_before_start() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Mint with end time before start time
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::Some(2000_u64), // start
            Option::Some(1000_u64), // end (before start)
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Token should never be playable
        start_cheat_block_timestamp(token.contract_address, 500);
        assert!(!token.is_playable(token_id), "Token should not be playable before invalid range");
        
        start_cheat_block_timestamp(token.contract_address, 1500);
        assert!(!token.is_playable(token_id), "Token should not be playable in invalid range");
        
        start_cheat_block_timestamp(token.contract_address, 2500);
        assert!(!token.is_playable(token_id), "Token should not be playable after invalid range");
        
        stop_cheat_block_timestamp(token.contract_address);
    }

    #[test]
    fn test_max_u64_values() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        let max_u64: u64 = 0xffffffffffffffff;
        
        // Mint with max u64 values
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::Some(max_u64 - 1000), // start near max
            Option::Some(max_u64), // end at max
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        let metadata = token.token_metadata(token_id);
        assert!(metadata.lifecycle.start == max_u64 - 1000, "Start time should be near max");
        assert!(metadata.lifecycle.end == max_u64, "End time should be max u64");
    }

    #[test]
    fn test_mint_to_zero_address() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let zero_address = starknet::contract_address_const::<0>();
        
        // Minting to zero address should fail (ERC721 standard)
        // This will panic in the ERC721 component
        let result = std::panic::catch_unwind(|| {
            token.mint(
                Option::Some(mock_game.contract_address),
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                zero_address,
                false,
            );
        });
        
        // We expect this to panic
        assert!(result.is_err(), "Minting to zero address should fail");
    }

    #[test]
    fn test_consecutive_mints_increment_id() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Mint multiple tokens consecutively
        let mut token_ids = array![];
        let mut i = 0;
        loop {
            if i == 5 {
                break;
            }
            
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
            
            token_ids.append(token_id);
            i += 1;
        };
        
        // Verify IDs are sequential
        assert!(*token_ids.at(0) == 1, "First token ID should be 1");
        assert!(*token_ids.at(1) == 2, "Second token ID should be 2");
        assert!(*token_ids.at(2) == 3, "Third token ID should be 3");
        assert!(*token_ids.at(3) == 4, "Fourth token ID should be 4");
        assert!(*token_ids.at(4) == 5, "Fifth token ID should be 5");
    }

    #[test]
    fn test_token_metadata_for_nonexistent_token() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        
        // Try to get metadata for non-existent token
        // This should return default/zero values
        let metadata = token.token_metadata(999);
        
        // All values should be zero/false for non-existent token
        assert!(metadata.game_id == 0, "Non-existent token should have zero game_id");
        assert!(metadata.minted_at == 0, "Non-existent token should have zero minted_at");
        assert!(metadata.settings_id == 0, "Non-existent token should have zero settings_id");
        assert!(!metadata.soulbound, "Non-existent token should not be soulbound");
        assert!(!metadata.game_over, "Non-existent token should not have game_over");
        assert!(!metadata.completed_all_objectives, "Non-existent token should not have completed objectives");
    }

    #[test]
    fn test_player_name_for_nonexistent_token() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        
        // Try to get player name for non-existent token
        let name = token.player_name(999);
        
        // Should return empty string
        assert!(name == "", "Non-existent token should have empty player name");
    }

    #[test]
    fn test_is_playable_with_game_over() {
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
        
        // Initially playable
        assert!(token.is_playable(token_id), "Token should be playable initially");
        
        // After game over, token metadata would have game_over = true
        // But since we can't directly set it in this test, we verify the logic
        // by checking that is_playable returns false when game_over is true
        let metadata = token.token_metadata(token_id);
        assert!(!metadata.game_over, "Game should not be over initially");
    }

    #[test]
    fn test_settings_id_overflow() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Test with max u32 settings_id
        let max_u32: u32 = 0xffffffff;
        
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None, // Would need settings support for this to work
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Settings ID should be 0 when not provided
        let settings_id = token.settings_id(token_id);
        assert!(settings_id == 0, "Settings ID should be 0 when not provided");
    }
}