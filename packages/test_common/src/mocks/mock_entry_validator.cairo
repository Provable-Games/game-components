/// Simple mock that implements IEntryRequirementExtension without using the component.
/// Always accepts entries (valid_entry returns true, should_ban returns false).
#[starknet::contract]
pub mod EntryValidatorMock {
    use game_components_interfaces::entry_requirement_extension::{
        IENTRY_REQUIREMENT_EXTENSION_ID, IEntryRequirementExtension,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        owner_address: ContractAddress,
        registration_only: bool,
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
    fn constructor(ref self: ContractState, owner: ContractAddress, registration_only: bool) {
        self.owner_address.write(owner);
        self.registration_only.write(registration_only);
        self.src5.register_interface(IENTRY_REQUIREMENT_EXTENSION_ID);
    }

    #[abi(embed_v0)]
    impl EntryRequirementExtensionImpl of IEntryRequirementExtension<ContractState> {
        fn owner_address(self: @ContractState) -> ContractAddress {
            self.owner_address.read()
        }

        fn registration_only(self: @ContractState) -> bool {
            self.registration_only.read()
        }

        fn valid_entry(
            self: @ContractState,
            context_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) -> bool {
            true
        }

        fn should_ban(
            self: @ContractState,
            context_id: u64,
            game_token_id: felt252,
            current_owner: ContractAddress,
            qualification: Span<felt252>,
        ) -> bool {
            false
        }

        fn entries_left(
            self: @ContractState,
            context_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) -> Option<u8> {
            Option::None
        }

        fn add_config(
            ref self: ContractState, context_id: u64, entry_limit: u8, config: Span<felt252>,
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
