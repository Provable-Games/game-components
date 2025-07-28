use starknet::ContractAddress;
use openzeppelin_token::erc721::interface::IERC721;

#[starknet::contract]
pub mod MockERC721 {
    use openzeppelin_token::erc721::interface::IERC721;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{get_caller_address, get_contract_address};

    #[storage]
    struct Storage {
        owners: Map<u256, ContractAddress>,
        balances: Map<ContractAddress, u256>,
        token_approvals: Map<u256, ContractAddress>,
        operator_approvals: Map<(ContractAddress, ContractAddress), bool>,
        next_token_id: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_token_id.write(1);

        // Mint some test tokens to the deployer
        let deployer = get_caller_address();
        self._mint(deployer, 1);
        self._mint(deployer, 2);
        self._mint(deployer, 3);
    }

    #[abi(embed_v0)]
    impl ERC721Impl of IERC721<ContractState> {
        fn balance_of(self: @ContractState, owner: ContractAddress) -> u256 {
            assert!(!owner.is_zero(), "ERC721: balance query for zero address");
            self.balances.read(owner)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.owners.read(token_id);
            assert!(!owner.is_zero(), "ERC721: owner query for nonexistent token");
            owner
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            self._require_minted(token_id);
            self.token_approvals.read(token_id)
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress,
        ) -> bool {
            self.operator_approvals.read((owner, operator))
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self.owner_of(token_id);
            assert!(to != owner, "ERC721: approval to current owner");

            let caller = get_caller_address();
            assert!(
                caller == owner || self.is_approved_for_all(owner, caller),
                "ERC721: approve caller is not owner nor approved for all",
            );

            self.token_approvals.write(token_id, to);
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool,
        ) {
            let owner = get_caller_address();
            assert!(owner != operator, "ERC721: approve to caller");
            self.operator_approvals.write((owner, operator), approved);
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            assert!(
                self._is_approved_or_owner(get_caller_address(), token_id),
                "ERC721: transfer caller is not owner nor approved",
            );
            self._transfer(from, to, token_id);
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>,
        ) {
            self.transfer_from(from, to, token_id);
            // In a real implementation, this would check if `to` is a contract and call
        // onERC721Received
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            assert!(!to.is_zero(), "ERC721: mint to zero address");
            assert!(self.owners.read(token_id).is_zero(), "ERC721: token already minted");

            let balance = self.balances.read(to);
            self.balances.write(to, balance + 1);
            self.owners.write(token_id, to);
        }

        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            assert!(self.owner_of(token_id) == from, "ERC721: transfer from incorrect owner");
            assert!(!to.is_zero(), "ERC721: transfer to zero address");

            // Clear approvals
            self.token_approvals.write(token_id, starknet::contract_address_const::<0>());

            // Update balances
            let from_balance = self.balances.read(from);
            self.balances.write(from, from_balance - 1);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + 1);

            // Update owner
            self.owners.write(token_id, to);
        }

        fn _is_approved_or_owner(
            self: @ContractState, spender: ContractAddress, token_id: u256,
        ) -> bool {
            self._require_minted(token_id);
            let owner = self.owner_of(token_id);
            spender == owner
                || self.get_approved(token_id) == spender
                || self.is_approved_for_all(owner, spender)
        }

        fn _require_minted(self: @ContractState, token_id: u256) {
            assert!(!self.owners.read(token_id).is_zero(), "ERC721: invalid token ID");
        }
    }

    // Helper function for testing - mint tokens to an address
    #[external(v0)]
    fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
        self._mint(to, token_id);
    }

    // Helper function for testing - set owner directly (for testing golden pass ownership)
    #[external(v0)]
    fn set_owner(ref self: ContractState, token_id: u256, owner: ContractAddress) {
        // Remove from current owner's balance if exists
        let current_owner = self.owners.read(token_id);
        if !current_owner.is_zero() {
            let current_balance = self.balances.read(current_owner);
            if current_balance > 0 {
                self.balances.write(current_owner, current_balance - 1);
            }
        }

        // Add to new owner's balance
        let new_balance = self.balances.read(owner);
        self.balances.write(owner, new_balance + 1);

        // Set owner
        self.owners.write(token_id, owner);
    }
}
