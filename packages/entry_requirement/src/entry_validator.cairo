/// EntryValidatorComponent provides extensible entry validation for any context.
/// This component allows external contracts to implement custom entry validation logic.

#[starknet::component]
pub mod EntryValidatorComponent {
    use game_components_interfaces::entry_validator::{IENTRY_VALIDATOR_ID, IEntryValidator};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        owner_address: ContractAddress,
        registration_only: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    /// Internal trait that implementors must provide.
    /// This trait defines the validation logic that each extension implements.
    pub trait EntryValidator<TContractState> {
        /// Validate if a player can enter a context (for NEW entries)
        fn validate_entry(
            self: @TContractState,
            context_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) -> bool;

        /// Determine if an existing entry should be banned (for EXISTING entries)
        /// Returns true if the entry should be banned
        fn should_ban_entry(
            self: @TContractState,
            context_id: u64,
            game_token_id: u64,
            current_owner: ContractAddress,
            qualification: Span<felt252>,
        ) -> bool;

        /// Check how many entries are left for a player
        fn entries_left(
            self: @TContractState,
            context_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) -> Option<u8>;

        /// Add configuration for a context
        fn add_config(
            ref self: TContractState, context_id: u64, entry_limit: u8, config: Span<felt252>,
        );

        /// Called when an entry is added
        fn on_entry_added(
            ref self: TContractState,
            context_id: u64,
            game_token_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        );

        /// Called when an entry is removed (banned)
        fn on_entry_removed(
            ref self: TContractState,
            context_id: u64,
            game_token_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        );
    }

    #[embeddable_as(EntryValidatorImpl)]
    impl EntryValidatorComponentImpl<
        TContractState,
        +HasComponent<TContractState>,
        +EntryValidator<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IEntryValidator<ComponentState<TContractState>> {
        fn owner_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner_address.read()
        }

        fn registration_only(self: @ComponentState<TContractState>) -> bool {
            self.registration_only.read()
        }

        fn valid_entry(
            self: @ComponentState<TContractState>,
            context_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) -> bool {
            let contract = self.get_contract();
            EntryValidator::validate_entry(contract, context_id, player_address, qualification)
        }

        fn should_ban(
            self: @ComponentState<TContractState>,
            context_id: u64,
            game_token_id: u64,
            current_owner: ContractAddress,
            qualification: Span<felt252>,
        ) -> bool {
            let contract = self.get_contract();
            EntryValidator::should_ban_entry(
                contract, context_id, game_token_id, current_owner, qualification,
            )
        }

        fn entries_left(
            self: @ComponentState<TContractState>,
            context_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) -> Option<u8> {
            let contract = self.get_contract();
            EntryValidator::entries_left(contract, context_id, player_address, qualification)
        }

        fn add_config(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            entry_limit: u8,
            config: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            EntryValidator::add_config(ref contract, context_id, entry_limit, config);
        }

        fn add_entry(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            game_token_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            EntryValidator::on_entry_added(
                ref contract, context_id, game_token_id, player_address, qualification,
            );
        }

        fn remove_entry(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            game_token_id: u64,
            player_address: ContractAddress,
            qualification: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            EntryValidator::on_entry_removed(
                ref contract, context_id, game_token_id, player_address, qualification,
            );
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            owner_address: ContractAddress,
            registration_only: bool,
        ) {
            self.owner_address.write(owner_address);
            self.registration_only.write(registration_only);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IENTRY_VALIDATOR_ID);
        }

        fn get_owner_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner_address.read()
        }

        fn is_registration_only(self: @ComponentState<TContractState>) -> bool {
            self.registration_only.read()
        }

        fn assert_only_owner(self: @ComponentState<TContractState>) {
            assert!(
                get_caller_address() == self.owner_address.read(),
                "Entry Validator: Only owner can call",
            );
        }
    }
}
