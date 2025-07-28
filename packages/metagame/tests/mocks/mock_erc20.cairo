use starknet::ContractAddress;
use openzeppelin_token::erc20::interface::IERC20;

#[starknet::contract]
pub mod MockERC20 {
    use openzeppelin_token::erc20::interface::IERC20;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{get_caller_address, get_contract_address};

    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
        total_supply: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Mint initial supply to deployer for testing
        let deployer = get_caller_address();
        let initial_supply = 1000000_u256 * 1000000000000000000_u256; // 1M tokens with 18 decimals
        self.balances.write(deployer, initial_supply);
        self.total_supply.write(initial_supply);
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.entry((owner, spender)).read()
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            let current_allowance = self.allowances.entry((sender, caller)).read();

            // For testing purposes, allow unlimited transfers if allowance is max
            if current_allowance != core::num::traits::Bounded::<u256>::MAX {
                assert!(current_allowance >= amount, "ERC20: insufficient allowance");
                self.allowances.entry((sender, caller)).write(current_allowance - amount);
            }

            self._transfer(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let owner = get_caller_address();
            self.allowances.entry((owner, spender)).write(amount);
            true
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let sender_balance = self.balances.read(sender);
            assert!(sender_balance >= amount, "ERC20: insufficient balance");

            self.balances.write(sender, sender_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);
        }
    }

    // Helper function for testing - mint tokens to an address
    #[external(v0)]
    fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
        let current_balance = self.balances.read(to);
        self.balances.write(to, current_balance + amount);
        let current_supply = self.total_supply.read();
        self.total_supply.write(current_supply + amount);
    }
}
