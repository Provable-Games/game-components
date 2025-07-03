use starknet::ContractAddress;
use snforge_std::{start_mock_call, stop_mock_call, mock_call};

#[derive(Drop, Copy)]
pub struct MockMinigameToken {
    pub contract_address: ContractAddress,
    pub minted_tokens: u64,
    pub registered_games: Span<ContractAddress>,
}

pub impl MockMinigameTokenImpl of MockMinigameTokenTrait {
    fn new(address: ContractAddress) -> MockMinigameToken {
        MockMinigameToken {
            contract_address: address,
            minted_tokens: 0,
            registered_games: array![].span(),
        }
    }

    fn mock_is_game_registered(self: @MockMinigameToken, game_address: ContractAddress, is_registered: bool) {
        let selector = selector!("is_game_registered");
        start_mock_call(*self.contract_address, selector, is_registered);
    }

    fn mock_is_game_registered_once(self: @MockMinigameToken, game_address: ContractAddress, is_registered: bool) {
        let selector = selector!("is_game_registered");
        mock_call(*self.contract_address, selector, is_registered, 1);
    }

    fn mock_mint(self: @MockMinigameToken, token_id: u64) {
        let selector = selector!("mint");
        start_mock_call(*self.contract_address, selector, token_id);
    }

    fn mock_mint_once(self: @MockMinigameToken, token_id: u64) {
        let selector = selector!("mint");
        mock_call(*self.contract_address, selector, token_id, 1);
    }

    fn stop_mock(self: @MockMinigameToken, selector: felt252) {
        stop_mock_call(*self.contract_address, selector);
    }
}

pub trait MockMinigameTokenTrait {
    fn new(address: ContractAddress) -> MockMinigameToken;
    fn mock_is_game_registered(self: @MockMinigameToken, game_address: ContractAddress, is_registered: bool);
    fn mock_is_game_registered_once(self: @MockMinigameToken, game_address: ContractAddress, is_registered: bool);
    fn mock_mint(self: @MockMinigameToken, token_id: u64);
    fn mock_mint_once(self: @MockMinigameToken, token_id: u64);
    fn stop_mock(self: @MockMinigameToken, selector: felt252);
}