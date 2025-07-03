#[cfg(test)]
mod tests {
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    use starknet::contract_address_const;
    use game_components_token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
    use core::option::OptionTrait;
    
    #[test]
    fn test_basic_mint() {
        // Deploy the test token contract
        let contract = declare("TestTokenContract").unwrap().contract_class();
        let (contract_address, _) = contract.deploy(@array![]).unwrap();
        
        let token = IMinigameTokenDispatcher { contract_address };
        
        // Test basic mint
        let recipient = contract_address_const::<0x123>();
        let token_id = token.mint(
            game_address: Option::None,
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_ids: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: recipient,
            soulbound: false
        );
        
        assert!(token_id == 1, "First token ID should be 1");
        
        // Verify token metadata
        let metadata = token.token_metadata(token_id);
        assert!(metadata.game_address.is_zero(), "Game address should be zero");
        assert!(metadata.start == 0, "Start time should be 0");
        assert!(metadata.end == 0, "End time should be 0");
    }
}