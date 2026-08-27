// SPDX-License-Identifier: BUSL-1.1

/// ERC721 mock that really moves ownership, so a wrong-NFT payout is
/// observable rather than merely inferred from storage.
#[starknet::contract]
pub mod ERC721TransferMock {
    use core::num::traits::Zero;
    use openzeppelin_interfaces::erc721::IERC721_ID;
    use openzeppelin_interfaces::introspection::ISRC5_ID;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        owners: Map<u256, ContractAddress>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.owners.read(token_id);
            assert!(!owner.is_zero(), "ERC721TransferMock: nonexistent token");
            owner
        }

        #[external(v0)]
        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            // Enforced deliberately: a payout of an NFT this contract does not
            // hold must fail here rather than silently succeed, so the
            // different-collection case shows up as a revert in tests.
            let owner = self.owners.read(token_id);
            assert!(owner == from, "ERC721TransferMock: transfer from non-owner");
            self.owners.write(token_id, to);
        }

        #[external(v0)]
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IERC721_ID || interface_id == ISRC5_ID
        }

        #[external(v0)]
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self.owners.write(token_id, to);
        }
    }
}
