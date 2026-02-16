pub use game_components_interfaces::extension::ExtensionConfig;
use starknet::ContractAddress;

pub const IENTRY_REQUIREMENT_ID: felt252 =
    0x01a96fed356e101112c0cc86d357a4ca8ec9c41f7f7d34a88c03e7083ddceb55;

#[derive(Copy, Drop, Serde, PartialEq)]
pub struct EntryRequirement {
    pub entry_limit: u32,
    pub entry_requirement_type: EntryRequirementType,
}

#[derive(Copy, Drop, Serde, PartialEq)]
pub enum EntryRequirementType {
    token: ContractAddress,
    allowlist: Span<ContractAddress>,
    extension: ExtensionConfig,
}

#[derive(Copy, Drop, Serde)]
pub struct QualificationEntries {
    pub context_id: u64,
    pub qualification_proof: QualificationProof,
    pub entry_count: u32,
}

#[derive(Copy, Drop, Serde, PartialEq)]
pub enum QualificationProof {
    NFT: NFTQualification,
    Address: ContractAddress,
    Extension: Span<felt252>,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct NFTQualification {
    pub token_id: u256,
}

#[starknet::interface]
pub trait IEntryRequirement<TState> {
    /// Get entry requirement configuration for a context (tournament, quest, etc.)
    /// Returns None if no entry requirement is set
    fn get_entry_requirement(self: @TState, context_id: u64) -> Option<EntryRequirement>;

    /// Get qualification entries for a context and qualification proof
    fn get_qualification_entries(
        self: @TState, context_id: u64, proof: QualificationProof,
    ) -> QualificationEntries;
}
