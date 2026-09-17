#[starknet::interface]
pub trait IReceiverState<T> {
    fn callbacks(self: @T) -> u32;
}

#[starknet::contract]
pub mod ReentrantReceiver {
    use openzeppelin_interfaces::erc721::{
        IERC721Dispatcher, IERC721DispatcherTrait, IERC721_RECEIVER_ID,
    };
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_contract_address};
    use crate::tests::extension_host::{
        IExtensionControlsDispatcher, IExtensionControlsDispatcherTrait,
    };
    #[storage]
    struct Storage {
        target: ContractAddress,
        reject: bool,
        count: u32,
    }
    #[constructor]
    fn constructor(ref self: ContractState, target: ContractAddress, reject: bool) {
        self.target.write(target);
        self.reject.write(reject);
    }
    #[abi(embed_v0)]
    impl SRC5 of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IERC721_RECEIVER_ID
        }
    }
    #[external(v0)]
    fn on_erc721_received(
        ref self: ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    ) -> felt252 {
        self.count.write(self.count.read() + 1);
        let target = self.target.read();
        let controls = IExtensionControlsDispatcher { contract_address: target };
        controls.set_uri(token_id, "RECEIVER");
        controls.set_royalty(token_id, get_contract_address(), 333);
        controls.mint(get_contract_address(), token_id + 1);
        IERC721Dispatcher { contract_address: target }.approve(209.try_into().unwrap(), token_id);
        assert(!self.reject.read(), 'RECEIVER_REJECT');
        IERC721_RECEIVER_ID
    }
    #[abi(embed_v0)]
    impl State of super::IReceiverState<ContractState> {
        fn callbacks(self: @ContractState) -> u32 {
            self.count.read()
        }
    }
}
