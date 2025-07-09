//! Minter Component - Pure Minter Tracking Functionality
//!
//! This component provides only minter tracking functionality and can be
//! composed with any other token component to add minter tracking capabilities.
//!
//! ## Composition Example
//! ```cairo
//! component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
//! component!(path: MinterComponent, storage: minter, event: MinterEvent);
//! 
//! // Embed both interfaces
//! #[abi(embed_v0)]
//! impl TokenImpl = CoreTokenComponent::MinigameTokenImpl<ContractState>;
//! #[abi(embed_v0)]
//! impl MinterImpl = MinterComponent::MinterImpl<ContractState>;
//! ```

use starknet::ContractAddress;
use starknet::storage::{
    StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
};
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
use crate::interface::IMinterToken;

#[starknet::component]
pub mod MinterComponent {
    use super::*;

    #[storage]
    pub struct Storage {
        minter_registry: Map<ContractAddress, u64>, // minter_address -> minter_id
        minter_registry_id: Map<u64, ContractAddress>, // minter_id -> minter_address
        minter_count: u64,
        // Track which minter minted which token (set by core token component)
        token_minted_by: Map<u64, u64>, // token_id -> minter_id
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MinterRegistered: MinterRegistered,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinterRegistered {
        pub minter_id: u64,
        pub minter_address: ContractAddress,
    }

    #[embeddable_as(MinterImpl)]
    impl Minter<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinterToken<ComponentState<TContractState>> {
        fn minted_by(self: @ComponentState<TContractState>, token_id: u64) -> u64 {
            self.token_minted_by.entry(token_id).read()
        }

        fn minter_address(self: @ComponentState<TContractState>, minter_id: u64) -> ContractAddress {
            self.minter_registry_id.entry(minter_id).read()
        }

        fn minter_count(self: @ComponentState<TContractState>) -> u64 {
            self.minter_count.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            // Register the IMinterToken interface
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(0xfedcba0987654321); // IMinterToken interface ID
        }

        /// Register a minter and return its ID
        /// This is called by the core token component during minting
        fn register_minter(ref self: ComponentState<TContractState>, minter_address: ContractAddress) -> u64 {
            let minter_count = self.minter_count.read();
            let minter_id = self.minter_registry.entry(minter_address).read();

            let mut registered_minter_id: u64 = 0;

            // If minter is not registered, register it
            if minter_id == 0 {
                registered_minter_id = minter_count + 1;
                self.minter_registry.entry(minter_address).write(registered_minter_id);
                self.minter_registry_id.entry(registered_minter_id).write(minter_address);
                self.minter_count.write(registered_minter_id);
                
                self.emit(MinterRegistered { minter_id: registered_minter_id, minter_address });
            } else {
                registered_minter_id = minter_id;
            }

            registered_minter_id
        }

        /// Associate a token with its minter
        /// Called by the core token component after minting
        fn set_token_minter(ref self: ComponentState<TContractState>, token_id: u64, minter_id: u64) {
            self.token_minted_by.entry(token_id).write(minter_id);
        }
    }
} 