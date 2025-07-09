#[starknet::component]
pub mod MinterComponent {
    use starknet::ContractAddress;
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use crate::extensions::minter::interface::IMINIGAME_TOKEN_MINTER_ID;

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;

    #[storage]
    pub struct Storage {
        minter_registry: Map<ContractAddress, u64>,
        minter_registry_id: Map<u64, ContractAddress>,
        minter_count: u64,
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_TOKEN_MINTER_ID);
        }

        fn add_minter(
            ref self: ComponentState<TContractState>, minter_address: ContractAddress,
        ) -> u64 {
            let minter_count = self.minter_count.read();
            let minter_id = self.minter_registry.entry(minter_address).read();

            let mut minted_by: u64 = 0;

            // If get_new_minter_id returned a new ID (greater than current count), register the
            // minter
            if minter_id == 0 {
                minted_by = minter_count + 1;
                self.minter_registry.entry(minter_address).write(minted_by);
                self.minter_registry_id.entry(minted_by).write(minter_address);
                self.minter_count.write(minted_by);
            } else {
                minted_by = minter_id;
            }

            minted_by
        }
    }
}
