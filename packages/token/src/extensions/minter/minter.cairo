#[starknet::component]
pub mod MinterComponent {
    use starknet::ContractAddress;
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use crate::core::traits::OptionalMinter;
    use crate::extensions::minter::interface::{IMinigameTokenMinter, IMINIGAME_TOKEN_MINTER_ID};

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;

    use crate::interface::{ITokenEventRelayerDispatcher, ITokenEventRelayerDispatcherTrait};

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
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IMinigameTokenMinter<ComponentState<TContractState>> {
        fn get_minter_address(
            self: @ComponentState<TContractState>, minter_id: u64,
        ) -> ContractAddress {
            self.minter_addresses.entry(minter_id).read()
        }

        fn get_minter_id(
            self: @ComponentState<TContractState>, minter_address: ContractAddress,
        ) -> u64 {
            self.minter_id_by_address.entry(minter_address).read()
        }

        fn minter_exists(
            self: @ComponentState<TContractState>, minter_address: ContractAddress,
        ) -> bool {
            self.minter_id_by_address.entry(minter_address).read() != 0
        }

        fn total_minters(self: @ComponentState<TContractState>) -> u64 {
            self.minter_counter.read()
        }
    }

    // Implementation of the OptionalMinter trait for integration with CoreTokenComponent
    pub impl MinterOptionalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of OptionalMinter<TContractState> {
        fn get_minter_address(self: @TContractState, minter_id: u64) -> ContractAddress {
            let component = HasComponent::get_component(self);
            component.get_minter_address(minter_id)
        }

        fn add_minter(
            ref self: TContractState,
            minter: ContractAddress,
            event_relayer: Option<ITokenEventRelayerDispatcher>,
        ) -> u64 {
            let mut component = HasComponent::get_component_mut(ref self);

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
            component.emit(MinterRegistered { minter_id, minter_address: minter });

            if let Option::Some(event_relayer) = event_relayer {
                event_relayer.emit_minter_registry_update(minter_id, minter);
                event_relayer.emit_minter_counter_update(minter_id);
            }

            minter_id
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
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_TOKEN_MINTER_ID);
        }
    }
}
