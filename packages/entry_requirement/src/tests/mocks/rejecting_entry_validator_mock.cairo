/// Entry validator mock that always rejects entries.
#[starknet::contract]
pub mod RejectingEntryValidatorMock {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::entry_validator::EntryValidatorComponent;

    component!(path: EntryValidatorComponent, storage: entry_validator, event: EntryValidatorEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl EntryValidatorImpl =
        EntryValidatorComponent::EntryValidatorImpl<ContractState>;

    impl EntryValidatorInternalImpl = EntryValidatorComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        entry_validator: EntryValidatorComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EntryValidatorEvent: EntryValidatorComponent::Event,
        SRC5Event: SRC5Component::Event,
    }

    impl EntryValidatorTraitImpl of EntryValidatorComponent::EntryValidator<ContractState> {
        fn validate_entry(
            self: @ContractState,
            context_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) -> bool {
            false // Always reject
        }

        fn should_ban_entry(
            self: @ContractState,
            context_id: u64,
            game_token_id: u64,
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

        fn on_entry_added(
            ref self: ContractState,
            context_id: u64,
            game_token_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) {}

        fn on_entry_removed(
            ref self: ContractState,
            context_id: u64,
            game_token_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) {}
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, registration_only: bool) {
        self.entry_validator.initializer(owner, registration_only);
    }
}
