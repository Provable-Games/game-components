/// Simple mock that implements IEntryRequirementExtension but always rejects entries.
#[starknet::contract]
pub mod RejectingEntryValidatorMock {
    use metagame_extensions_interfaces::entry_requirement_extension::{
        IENTRY_REQUIREMENT_EXTENSION_ID, IEntryRequirementExtension,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        owner_address: ContractAddress,
        bannable: Map<u64, bool>,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner_address.write(owner);
        self.src5.register_interface(IENTRY_REQUIREMENT_EXTENSION_ID);
    }

    #[abi(embed_v0)]
    impl EntryValidatorImpl of IEntryRequirementExtension<ContractState> {
        fn context_owner(self: @ContractState, context_id: u64) -> ContractAddress {
            self.owner_address.read()
        }

        fn bannable(self: @ContractState, context_id: u64) -> bool {
            self.bannable.read(context_id)
        }

        fn valid_entry(
            self: @ContractState,
            context_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) -> bool {
            false
        }

        fn should_ban(
            self: @ContractState,
            context_id: u64,
            game_token_id: felt252,
            current_owner: ContractAddress,
            qualification: Span<felt252>,
        ) -> bool {
            true
        }

        fn entries_left(
            self: @ContractState,
            context_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) -> Option<u32> {
            Option::Some(0)
        }

        fn add_config(
            ref self: ContractState, context_id: u64, entry_limit: u32, config: Span<felt252>,
        ) {}

        fn add_entry(
            ref self: ContractState,
            context_id: u64,
            game_token_id: felt252,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) {}

        fn remove_entry(
            ref self: ContractState,
            context_id: u64,
            game_token_id: felt252,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) {}
    }
}
