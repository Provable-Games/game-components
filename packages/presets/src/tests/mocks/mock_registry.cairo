/// Mock Token Registry for testing StreamToken
/// Accepts register_token calls without any validation or external calls

use ekubo::interfaces::erc20::IERC20Dispatcher;

#[starknet::interface]
pub trait IMockTokenRegistry<TContractState> {
    fn register_token(ref self: TContractState, token: IERC20Dispatcher);
    fn get_registered_count(self: @TContractState) -> u32;
}

#[starknet::contract]
pub mod MockTokenRegistry {
    use ekubo::interfaces::erc20::IERC20Dispatcher;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        registered_count: u32,
    }

    #[abi(embed_v0)]
    impl MockTokenRegistryImpl of super::IMockTokenRegistry<ContractState> {
        fn register_token(ref self: ContractState, token: IERC20Dispatcher) {
            // Just count registrations, don't do any validation
            let _ = token; // Suppress unused warning
            let count = self.registered_count.read();
            self.registered_count.write(count + 1);
        }

        fn get_registered_count(self: @ContractState) -> u32 {
            self.registered_count.read()
        }
    }
}
