use openzeppelin_interfaces::introspection::ISRC5;

#[starknet::contract]
pub mod MockSRC5 {
    use super::*;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        supported_interfaces: Map<felt252, bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Always support SRC5 itself
        self.supported_interfaces.write(openzeppelin_interfaces::introspection::ISRC5_ID, true);
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            self.supported_interfaces.read(interface_id)
        }
    }

    // Helper functions for testing
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn set_supported_interface(
            ref self: ContractState, interface_id: felt252, supported: bool,
        ) {
            self.supported_interfaces.write(interface_id, supported);
        }
    }
}
