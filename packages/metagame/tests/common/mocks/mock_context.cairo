use starknet::ContractAddress;
use game_components_metagame::extensions::context::structs::GameContextDetails;
use snforge_std::{start_mock_call, stop_mock_call, mock_call};

#[derive(Drop, Copy)]
pub struct MockContextContract {
    pub contract_address: ContractAddress,
}

pub impl MockContextContractImpl of MockContextContractTrait {
    fn new(address: ContractAddress) -> MockContextContract {
        MockContextContract {
            contract_address: address,
        }
    }

    fn mock_supports_interface(self: @MockContextContract, interface_id: felt252, supports: bool) {
        let selector = selector!("supports_interface");
        start_mock_call(*self.contract_address, selector, supports);
    }

    fn mock_supports_interface_once(self: @MockContextContract, interface_id: felt252, supports: bool) {
        let selector = selector!("supports_interface");
        mock_call(*self.contract_address, selector, supports, 1);
    }

    fn mock_game_context(self: @MockContextContract, token_id: u64, context: GameContextDetails) {
        let selector = selector!("game_context");
        start_mock_call(*self.contract_address, selector, context);
    }

    fn stop_mock(self: @MockContextContract, selector: felt252) {
        stop_mock_call(*self.contract_address, selector);
    }
}

pub trait MockContextContractTrait {
    fn new(address: ContractAddress) -> MockContextContract;
    fn mock_supports_interface(self: @MockContextContract, interface_id: felt252, supports: bool);
    fn mock_supports_interface_once(self: @MockContextContract, interface_id: felt252, supports: bool);
    fn mock_game_context(self: @MockContextContract, token_id: u64, context: GameContextDetails);
    fn stop_mock(self: @MockContextContract, selector: felt252);
}