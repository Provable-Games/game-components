use game_components_metagame::extensions::context::interface::{
    IMETAGAME_CONTEXT_ID, IMetagameContext, IMetagameContextDetails,
};
use game_components_metagame::extensions::context::structs::{GameContext, GameContextDetails};
use openzeppelin_interfaces::introspection::ISRC5;

// Interface for setting context in tests
#[starknet::interface]
trait IContextSetter<TContractState> {
    fn store_context(ref self: TContractState, token_id: u64, context: GameContextDetails);
}

#[starknet::contract]
pub mod MockContext {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::*;

    #[storage]
    struct Storage {
        supports_context: bool,
        has_context_map: Map<u64, bool>,
        // Store context fields separately to avoid Store trait issues
        context_name: ByteArray,
        context_description: ByteArray,
        context_id: Option<u32>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, supports_context: bool) {
        self.supports_context.write(supports_context);
        self.context_name.write("");
        self.context_description.write("");
        self.context_id.write(Option::None);
    }

    #[abi(embed_v0)]
    impl MetagameContextImpl of IMetagameContext<ContractState> {
        fn has_context(self: @ContractState, token_id: u64) -> bool {
            self.has_context_map.read(token_id)
        }
    }

    #[abi(embed_v0)]
    impl MetagameContextDetailsImpl of IMetagameContextDetails<ContractState> {
        fn context_details(self: @ContractState, token_id: u64) -> GameContextDetails {
            if !self.has_context_map.read(token_id) {
                panic!("Context not found");
            }

            // Return stored context data
            GameContextDetails {
                name: self.context_name.read(),
                description: self.context_description.read(),
                id: self.context_id.read(),
                context: array![
                    GameContext { name: "Round", value: "Qualifier Round" },
                    GameContext { name: "Round", value: "Semi Finals" },
                    GameContext { name: "Round", value: "Finals" },
                ]
                    .span(),
            }
        }
    }

    #[abi(embed_v0)]
    impl ContextSetterImpl of IContextSetter<ContractState> {
        fn store_context(ref self: ContractState, token_id: u64, context: GameContextDetails) {
            self.has_context_map.write(token_id, true);
            self.context_name.write(context.name);
            self.context_description.write(context.description);
            self.context_id.write(context.id);
        }
    }

    #[abi(embed_v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            if self.supports_context.read() {
                interface_id == IMETAGAME_CONTEXT_ID
                    || interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
            } else {
                interface_id == openzeppelin_interfaces::introspection::ISRC5_ID
            }
        }
    }
}
