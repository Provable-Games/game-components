#[starknet::interface]
pub trait IMinterComponent<TState> {
    fn get_minter_address(self: @TState, minter_id: u64) -> starknet::ContractAddress;
    fn get_minter_id(self: @TState, minter_address: starknet::ContractAddress) -> u64;
    fn minter_exists(self: @TState, minter_address: starknet::ContractAddress) -> bool;
    fn total_minters(self: @TState) -> u64;
}

#[starknet::component]
pub mod MinterComponent {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use crate::core::traits::OptionalMinter;
    use super::IMinterComponent;

    #[storage]
    pub struct Storage {
        minter_counter: u64,
        minter_addresses: Map<u64, ContractAddress>,
        minter_id_by_address: Map<ContractAddress, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MinterRegistered: MinterRegistered,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinterRegistered {
        minter_id: u64,
        minter_address: ContractAddress,
    }

    #[embeddable_as(MinterImpl)]
    pub impl Minter<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinterComponent<ComponentState<TContractState>> {
        
        fn get_minter_address(self: @ComponentState<TContractState>, minter_id: u64) -> ContractAddress {
            self.minter_addresses.entry(minter_id).read()
        }

        fn get_minter_id(self: @ComponentState<TContractState>, minter_address: ContractAddress) -> u64 {
            self.minter_id_by_address.entry(minter_address).read()
        }

        fn minter_exists(self: @ComponentState<TContractState>, minter_address: ContractAddress) -> bool {
            self.minter_id_by_address.entry(minter_address).read() != 0
        }

        fn total_minters(self: @ComponentState<TContractState>) -> u64 {
            self.minter_counter.read()
        }
    }

    // Implementation of the OptionalMinter trait for integration with CoreTokenComponent
    pub impl MinterOptionalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of OptionalMinter<TContractState> {
        
        fn on_mint_with_minter(ref self: TContractState, minter: ContractAddress) -> u64 {
            let component = HasComponent::get_component_mut(ref self);
            
            // Check if minter already exists
            let existing_id = component.minter_id_by_address.entry(minter).read();
            if existing_id != 0 {
                return existing_id;
            }
            
            // Register new minter
            let minter_id = component.minter_counter.read() + 1;
            component.minter_addresses.entry(minter_id).write(minter);
            component.minter_id_by_address.entry(minter).write(minter_id);
            component.minter_counter.write(minter_id);
            
            // Emit event
            component.emit(MinterRegistered {
                minter_id,
                minter_address: minter,
            });
            
            minter_id
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        
        fn initializer(ref self: ComponentState<TContractState>) {
            // Initialize minter counter
            self.minter_counter.write(0);
        }
    }
} 