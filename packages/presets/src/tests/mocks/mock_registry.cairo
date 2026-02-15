/// Mock Token Registry for testing StreamToken
/// Simulates Ekubo's registry behavior: accepts 1 token, verifies, and returns it

use ekubo::interfaces::erc20::IERC20Dispatcher;

#[starknet::interface]
pub trait IMockTokenRegistry<TContractState> {
    fn register_token(ref self: TContractState, token: IERC20Dispatcher);
    fn get_registered_count(self: @TContractState) -> u32;
}

#[starknet::contract]
pub mod MockTokenRegistry {
    use ekubo::interfaces::erc20::IERC20Dispatcher;
    use openzeppelin_interfaces::token::erc20::{
        IERC20Dispatcher as OzIERC20Dispatcher, IERC20DispatcherTrait,
    };
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{get_caller_address, get_contract_address};

    #[storage]
    struct Storage {
        registered_count: u32,
    }

    #[abi(embed_v0)]
    impl MockTokenRegistryImpl of super::IMockTokenRegistry<ContractState> {
        fn register_token(ref self: ContractState, token: IERC20Dispatcher) {
            // Simulate Ekubo's registry behavior:
            // 1. Receive 1 token from caller (already done by StreamToken minting to registry)
            // 2. Verify token is valid (skip for mock)
            // 3. Return 1 token back to the caller
            let caller = get_caller_address();
            let this = get_contract_address();

            // Use OZ dispatcher to transfer the token back to caller (like Ekubo does)
            let oz_token = OzIERC20Dispatcher { contract_address: token.contract_address };
            let balance = oz_token.balance_of(this);
            if balance > 0 {
                oz_token.transfer(caller, balance);
            }

            let count = self.registered_count.read();
            self.registered_count.write(count + 1);
        }

        fn get_registered_count(self: @ContractState) -> u32 {
            self.registered_count.read()
        }
    }
}
