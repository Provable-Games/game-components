/// Minimal ERC721 mock for testing validate_qualification.
/// Supports owner_of() and SRC5 supports_interface() for IERC721_ID.
#[starknet::contract]
pub mod ERC721Mock {
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
            assert!(!owner.is_zero(), "ERC721Mock: nonexistent token");
            owner
        }

        #[external(v0)]
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IERC721_ID || interface_id == ISRC5_ID
        }

        #[external(v0)]
        fn set_owner(ref self: ContractState, token_id: u256, owner: ContractAddress) {
            self.owners.write(token_id, owner);
        }
    }
}
