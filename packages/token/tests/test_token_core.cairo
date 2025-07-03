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
    use super::super::test_contracts::{BasicTokenContract, MultiGameTokenContract};
    use super::super::mocks::{
        setup_mock_minigame, setup_mock_settings, setup_mock_objectives,
        MockMinigameContractTrait, MockSettingsContractTrait, MockObjectivesContractTrait
    };
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

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

    // UT-01: Mint basic token with game_address and recipient
    #[test]
    fn test_mint_basic_token() {
        // Setup mock game
        let (mock_game, _, _, _) = setup_mock_minigame();
        let token = deploy_basic_token(mock_game.contract_address);
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Mint basic token
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None, // No player name
            Option::None, // No settings
            Option::None, // No start time
            Option::None, // No end time
            Option::None, // No objectives
            Option::None, // No context
            Option::None, // No client URL
            Option::None, // No renderer
            recipient,
            false, // Not soulbound
        );
        
        // Verify token was minted
        assert!(token_id == 1, "First token should have ID 1");
        
        // Verify ownership
        let erc721 = IERC721Dispatcher { contract_address: token.contract_address };
        let owner = erc721.owner_of(token_id.into());
        assert!(owner == recipient, "Token should be owned by recipient");
        
        // Verify metadata
        let metadata = token.token_metadata(token_id);
        assert!(metadata.game_id == 0, "Game ID should be 0 for single game token");
        assert!(!metadata.soulbound, "Token should not be soulbound");
        assert!(!metadata.game_over, "Game should not be over initially");
        assert!(!metadata.completed_all_objectives, "Objectives should not be completed initially");
    }
}