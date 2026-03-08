/// EntryRequirementComponent handles entry requirements for any context (tournaments, quests,
/// etc.).
/// This component manages:
/// - Entry requirement configuration per context
/// - Entry requirement type (token, allowlist, extension)
/// - Qualification entries tracking
/// - Entry count management

#[starknet::component]
pub mod EntryRequirementComponent {
    use core::num::traits::Zero;
    use game_components_interfaces::entry_requirement::{IENTRY_REQUIREMENT_ID, IEntryRequirement};
    use interfaces::entry_requirement_extension::IENTRY_REQUIREMENT_EXTENSION_ID;
    use openzeppelin_interfaces::erc721::IERC721_ID;
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use crate::entry_requirement::entry_requirement::entry_requirement;
    use crate::entry_requirement::entry_requirement_store::{
        EntryRequirementStoreImpl, EntryRequirementStoreTrait,
    };
    use crate::entry_requirement::store::Store;
    use crate::entry_requirement::structs::{
        EntryRequirement, EntryRequirementMeta, EntryRequirementMetaStorePacking,
        EntryRequirementType, QualificationEntries, QualificationProof,
    };

    #[storage]
    pub struct Storage {
        /// Entry requirement metadata keyed by context_id (entry_limit + req_type)
        EntryRequirement_meta: Map<u64, EntryRequirementMeta>,
        /// Token address for token-gated requirements
        EntryRequirement_token: Map<u64, ContractAddress>,
        /// Allowlist addresses for allowlist-gated requirements (stored as Vec)
        EntryRequirement_allowlist: Map<u64, Vec<ContractAddress>>,
        /// Extension address for extension-gated requirements
        EntryRequirement_extension_address: Map<u64, ContractAddress>,
        /// Extension config data (stored as Vec)
        EntryRequirement_extension_config: Map<u64, Vec<felt252>>,
        /// Qualification entries tracking keyed by (context_id, qualification_hash)
        EntryRequirement_qualification_entries: Map<(u64, felt252), u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    // Implement the Store trait for this component
    impl ComponentStore<
        TContractState, +HasComponent<TContractState>,
    > of Store<ComponentState<TContractState>> {
        fn get_meta(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> EntryRequirementMeta {
            self.EntryRequirement_meta.entry(context_id).read()
        }

        fn set_meta(
            ref self: ComponentState<TContractState>, context_id: u64, meta: EntryRequirementMeta,
        ) {
            self.EntryRequirement_meta.entry(context_id).write(meta);
        }

        fn get_token(self: @ComponentState<TContractState>, context_id: u64) -> ContractAddress {
            self.EntryRequirement_token.entry(context_id).read()
        }

        fn set_token(
            ref self: ComponentState<TContractState>, context_id: u64, token: ContractAddress,
        ) {
            self.EntryRequirement_token.entry(context_id).write(token);
        }

        fn get_allowlist(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Span<ContractAddress> {
            let vec = self.EntryRequirement_allowlist.entry(context_id);
            let mut arr = ArrayTrait::new();
            let len = vec.len();
            let mut i: u64 = 0;
            loop {
                if i >= len {
                    break;
                }
                arr.append(vec.at(i).read());
                i += 1;
            }
            arr.span()
        }

        fn set_allowlist(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            addresses: Span<ContractAddress>,
        ) {
            let mut vec = self.EntryRequirement_allowlist.entry(context_id);
            let mut i: u32 = 0;
            loop {
                if i >= addresses.len() {
                    break;
                }
                vec.push(*addresses.at(i));
                i += 1;
            };
        }

        fn get_extension_address(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> ContractAddress {
            self.EntryRequirement_extension_address.entry(context_id).read()
        }

        fn set_extension_address(
            ref self: ComponentState<TContractState>, context_id: u64, address: ContractAddress,
        ) {
            self.EntryRequirement_extension_address.entry(context_id).write(address);
        }

        fn get_extension_config(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Span<felt252> {
            let vec = self.EntryRequirement_extension_config.entry(context_id);
            let mut arr = ArrayTrait::new();
            let len = vec.len();
            let mut i: u64 = 0;
            loop {
                if i >= len {
                    break;
                }
                arr.append(vec.at(i).read());
                i += 1;
            }
            arr.span()
        }

        fn set_extension_config(
            ref self: ComponentState<TContractState>, context_id: u64, config: Span<felt252>,
        ) {
            let mut vec = self.EntryRequirement_extension_config.entry(context_id);
            let mut i: u32 = 0;
            loop {
                if i >= config.len() {
                    break;
                }
                vec.push(*config.at(i));
                i += 1;
            };
        }

        fn get_qualification_entries(
            self: @ComponentState<TContractState>, context_id: u64, hash: felt252,
        ) -> u32 {
            self.EntryRequirement_qualification_entries.entry((context_id, hash)).read()
        }

        fn set_qualification_entries(
            ref self: ComponentState<TContractState>, context_id: u64, hash: felt252, count: u32,
        ) {
            self.EntryRequirement_qualification_entries.entry((context_id, hash)).write(count);
        }
    }

    #[embeddable_as(EntryRequirementImpl)]
    impl EntryRequirementComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IEntryRequirement<ComponentState<TContractState>> {
        fn get_entry_requirement(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Option<EntryRequirement> {
            self._get_entry_requirement(context_id)
        }

        fn get_qualification_entries(
            self: @ComponentState<TContractState>, context_id: u64, proof: QualificationProof,
        ) -> QualificationEntries {
            self._get_qualification_entries(context_id, proof)
        }
    }

    #[generate_trait]
    pub impl EntryRequirementInternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of EntryRequirementInternalTrait<TContractState> {
        /// Get entry requirement for a context (internal)
        /// Returns None if no entry requirement is set (req_type is 255)
        fn _get_entry_requirement(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> Option<EntryRequirement> {
            EntryRequirementStoreTrait::get_entry_requirement(self, context_id)
        }

        /// Set entry requirement for a context
        /// Performs SRC5 validation before storing
        fn set_entry_requirement(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            entry_requirement: Option<EntryRequirement>,
        ) {
            match entry_requirement {
                Option::Some(req) => {
                    let (req_type, entry_limit) = match req.entry_requirement_type {
                        EntryRequirementType::token(token) => {
                            let src5 = ISRC5Dispatcher { contract_address: token };
                            let display_address: felt252 = token.into();
                            assert!(
                                src5.supports_interface(IERC721_ID),
                                "EntryRequirement: Token {} does not support IERC721",
                                display_address,
                            );
                            self.set_token(context_id, token);
                            (entry_requirement::REQ_TYPE_TOKEN, req.entry_limit)
                        },
                        EntryRequirementType::allowlist(addresses) => {
                            self.set_allowlist(context_id, addresses);
                            (entry_requirement::REQ_TYPE_ALLOWLIST, req.entry_limit)
                        },
                        EntryRequirementType::extension(config) => {
                            assert!(
                                !config.address.is_zero(),
                                "EntryRequirement: Extension address cannot be zero",
                            );
                            let src5 = ISRC5Dispatcher { contract_address: config.address };
                            let display_address: felt252 = config.address.into();
                            assert!(
                                src5.supports_interface(IENTRY_REQUIREMENT_EXTENSION_ID),
                                "EntryRequirement: Extension {} does not support IEntryValidator",
                                display_address,
                            );
                            self.set_extension_address(context_id, config.address);
                            self.set_extension_config(context_id, config.config);
                            (entry_requirement::REQ_TYPE_EXTENSION, req.entry_limit)
                        },
                    };

                    let meta = EntryRequirementMeta { entry_limit, req_type };
                    self.set_meta(context_id, meta);
                },
                Option::None => {
                    // Write empty meta with REQ_TYPE_NONE
                    let meta = EntryRequirementMeta {
                        entry_limit: 0, req_type: entry_requirement::REQ_TYPE_NONE,
                    };
                    self.set_meta(context_id, meta);
                },
            }
        }

        /// Get qualification entries for a context and qualification proof (internal)
        fn _get_qualification_entries(
            self: @ComponentState<TContractState>, context_id: u64, proof: QualificationProof,
        ) -> QualificationEntries {
            EntryRequirementStoreTrait::get_qualification_entries(self, context_id, proof)
        }

        /// Set qualification entries for a context
        fn set_qualification_entries(
            ref self: ComponentState<TContractState>, entries: @QualificationEntries,
        ) {
            EntryRequirementStoreTrait::set_qualification_entries(ref self, entries);
        }

        /// Hash a qualification proof for storage key lookup
        fn hash_qualification_proof(
            self: @ComponentState<TContractState>, proof: QualificationProof,
        ) -> felt252 {
            entry_requirement::hash_qualification_proof(proof)
        }

        /// Validates a qualification proof against an entry requirement.
        /// Returns the qualifying address (NFT owner, allowlist address, or caller).
        fn validate_qualification(
            self: @ComponentState<TContractState>,
            context_id: u64,
            entry_requirement: EntryRequirement,
            qualifier: QualificationProof,
        ) -> ContractAddress {
            EntryRequirementStoreTrait::validate_qualification(
                self, context_id, entry_requirement, qualifier,
            )
        }

        /// Validates entry requirement configuration at creation time.
        /// Checks SRC5 interfaces (ERC721 for token, IEntryValidator for extension).
        fn assert_valid_entry_requirement(
            self: @ComponentState<TContractState>, entry_requirement: EntryRequirement,
        ) {
            EntryRequirementStoreTrait::assert_valid_entry_requirement(self, entry_requirement);
        }

        fn _contains_address(addresses: Span<ContractAddress>, target: ContractAddress) -> bool {
            entry_requirement::contains_address(addresses, target)
        }

        /// Update qualification entries after a successful entry
        fn update_qualification_entries(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            qualifier: QualificationProof,
            entry_requirement: EntryRequirement,
        ) {
            EntryRequirementStoreTrait::update_qualification_entries(
                ref self, context_id, qualifier, entry_requirement,
            );
        }
    }

    #[generate_trait]
    pub impl EntryRequirementInitializerImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of EntryRequirementInitializerTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IENTRY_REQUIREMENT_ID);
        }
    }
}
