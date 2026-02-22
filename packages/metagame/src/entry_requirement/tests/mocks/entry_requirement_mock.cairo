#[starknet::contract]
pub mod EntryRequirementMock {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::entry_requirement::entry_requirement_component::EntryRequirementComponent;
    use crate::entry_requirement::structs::{
        EntryRequirement, QualificationEntries, QualificationProof,
    };

    component!(path: EntryRequirementComponent, storage: entry_req, event: EntryReqEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl EntryRequirementImpl =
        EntryRequirementComponent::EntryRequirementImpl<ContractState>;

    impl EntryRequirementInternalImpl =
        EntryRequirementComponent::EntryRequirementInternalImpl<ContractState>;

    impl EntryRequirementInitializerImpl =
        EntryRequirementComponent::EntryRequirementInitializerImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        entry_req: EntryRequirementComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EntryReqEvent: EntryRequirementComponent::Event,
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.entry_req.initializer();
    }

    #[external(v0)]
    fn set_entry_requirement(
        ref self: ContractState, context_id: u64, entry_requirement: Option<EntryRequirement>,
    ) {
        self.entry_req.set_entry_requirement(context_id, entry_requirement);
    }

    #[external(v0)]
    fn set_qualification_entries(ref self: ContractState, entries: QualificationEntries) {
        self.entry_req.set_qualification_entries(@entries);
    }

    #[external(v0)]
    fn update_qualification_entries(
        ref self: ContractState,
        context_id: u64,
        qualifier: QualificationProof,
        entry_requirement: EntryRequirement,
    ) {
        self.entry_req.update_qualification_entries(context_id, qualifier, entry_requirement);
    }

    #[external(v0)]
    fn validate_qualification(
        self: @ContractState,
        context_id: u64,
        entry_requirement: EntryRequirement,
        qualifier: QualificationProof,
    ) -> ContractAddress {
        self.entry_req.validate_qualification(context_id, entry_requirement, qualifier)
    }

    #[external(v0)]
    fn assert_valid_entry_requirement(self: @ContractState, entry_requirement: EntryRequirement) {
        self.entry_req.assert_valid_entry_requirement(entry_requirement);
    }
}
