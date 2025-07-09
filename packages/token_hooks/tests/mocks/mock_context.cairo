#[starknet::contract]
pub mod MockContext {
    use game_components_metagame::extensions::context::interface::{IMetagameContext, IMETAGAME_CONTEXT_ID};
    use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContextData};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use openzeppelin_introspection::src5::{SRC5Component, SRC5Component::InternalTrait};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        contexts: Map<u64, GameContextData>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.src5.register_interface(IMETAGAME_CONTEXT_ID);
    }

    #[abi(embed_v0)]
    impl MetagameContextImpl of IMetagameContext<ContractState> {
        fn context(self: @ContractState, token_id: u64) -> GameContextData {
            self.contexts.read(token_id)
        }
    }

    #[external(v0)]
    fn set_context(ref self: ContractState, token_id: u64, context: GameContextData) {
        self.contexts.write(token_id, context);
    }
}