#[starknet::contract]
pub mod RegistrationMock {
    use game_components_interfaces::registration::Registration;
    use crate::registration::registration_component::RegistrationComponent;

    component!(path: RegistrationComponent, storage: registration, event: RegistrationEvent);

    #[abi(embed_v0)]
    impl RegistrationImpl = RegistrationComponent::RegistrationImpl<ContractState>;

    impl RegistrationInternalImpl = RegistrationComponent::RegistrationInternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        registration: RegistrationComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RegistrationEvent: RegistrationComponent::Event,
    }

    // Expose internal functions for testing
    #[external(v0)]
    fn set_entry(ref self: ContractState, registration: Registration) {
        self.registration.set_entry(@registration);
    }

    #[external(v0)]
    fn increment_entry_count(ref self: ContractState, context_id: u64) -> u32 {
        self.registration.increment_entry_count(context_id)
    }

    #[external(v0)]
    fn mark_entry_submitted(ref self: ContractState, context_id: u64, entry_id: u32) {
        self.registration.mark_entry_submitted(context_id, entry_id);
    }

    #[external(v0)]
    fn ban_entry(ref self: ContractState, context_id: u64, entry_id: u32) {
        self.registration.ban_entry(context_id, entry_id);
    }

    #[external(v0)]
    fn assert_valid_for_submission(
        self: @ContractState, registration: Registration, context_id: u64,
    ) {
        self.registration.assert_valid_for_submission(@registration, context_id);
    }

    #[external(v0)]
    fn get_token_context(self: @ContractState, token_id: felt252) -> u64 {
        self.registration._get_token_context(token_id)
    }

    #[external(v0)]
    fn get_entry_id_for_token(self: @ContractState, token_id: felt252) -> u32 {
        self.registration._get_entry_id_for_token(token_id)
    }
}
