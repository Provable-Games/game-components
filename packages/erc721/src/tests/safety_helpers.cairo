use snforge_std::{
    start_cheat_block_number, start_cheat_block_timestamp, start_cheat_caller_address,
};
use starknet::ContractAddress;
pub fn context(address: ContractAddress, caller: felt252, block: u64, now: u64) {
    start_cheat_caller_address(address, caller.try_into().unwrap());
    start_cheat_block_number(address, block);
    start_cheat_block_timestamp(address, now);
}
pub fn expect_error<T, +Drop<T>>(result: Result<T, Array<felt252>>, error: felt252) {
    match result {
        Result::Err(data) => assert_eq!(data, array![error, 'ENTRYPOINT_FAILED']),
        Result::Ok(_) => panic!("Expected revert"),
    }
}
