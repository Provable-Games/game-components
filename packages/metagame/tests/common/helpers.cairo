use starknet::ContractAddress;
use starknet::get_block_timestamp;
use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,
    start_cheat_block_timestamp_global,
    start_cheat_caller_address_global
};
use super::constants;

// Helper function to deploy mock metagame contract
pub fn deploy_mock_metagame(
    minigame_token_address: ContractAddress,
    context_address: Option<ContractAddress>,
    supports_context: bool
) -> ContractAddress {
    let contract = declare("MockMetagameContract").unwrap().contract_class();
    let mut constructor_calldata: Array<felt252> = array![];
    
    // First parameter: minigame_token_address
    constructor_calldata.append(minigame_token_address.into());
    
    // Second parameter: context_address (Option)
    match context_address {
        Option::Some(addr) => {
            constructor_calldata.append(1); // Option::Some indicator
            constructor_calldata.append(addr.into());
        },
        Option::None => {
            constructor_calldata.append(0); // Option::None indicator
        },
    };
    
    // Third parameter: supports_context (bool)
    let supports_context_felt: felt252 = if supports_context { 1 } else { 0 };
    constructor_calldata.append(supports_context_felt);
    
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

// Helper function to create test context data
pub fn create_test_context() -> GameContextDetails {
    GameContextDetails {
        name: constants::CONTEXT_NAME(),
        description: constants::CONTEXT_DESCRIPTION(),
        id: Option::Some(constants::CONTEXT_ID),
        context: array![
            GameContext { name: "level", value: "10" },
            GameContext { name: "score", value: "1000" },
        ].span(),
    }
}

// Helper function to create objectives array
pub fn create_test_objectives() -> Array<u32> {
    array![1, 2, 3, 4, 5]
}

// Helper function to advance block timestamp
pub fn advance_block_timestamp(seconds: u64) {
    let current = get_block_timestamp();
    start_cheat_block_timestamp_global(current + seconds);
}

// Helper function to set caller address
pub fn set_caller(address: ContractAddress) {
    start_cheat_caller_address_global(address);
}

// Helper function to set contract address
pub fn set_contract_address(address: ContractAddress) {
    // In snforge, we typically don't need to set the contract address
    // as it's handled by the testing framework
}