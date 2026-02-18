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
    use core::poseidon::poseidon_hash_span;
    use game_components_interfaces::entry_requirement::{IENTRY_REQUIREMENT_ID, IEntryRequirement};
    use interfaces::entry_requirement_extension::{
        IENTRY_REQUIREMENT_EXTENSION_ID, IEntryValidatorDispatcher, IEntryValidatorDispatcherTrait,
    };
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait, IERC721_ID};
    use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::entry_requirement::models::{
        EntryRequirement, EntryRequirementMeta, EntryRequirementMetaStorePacking,
        EntryRequirementType, ExtensionConfig, QualificationEntries, QualificationProof,
    };

    // Entry requirement type constants
    const REQ_TYPE_TOKEN: u8 = 0;
    const REQ_TYPE_ALLOWLIST: u8 = 1;
    const REQ_TYPE_EXTENSION: u8 = 2;
    const REQ_TYPE_NONE: u8 = 255;

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
            let meta = self.EntryRequirement_meta.entry(context_id).read();

            // If req_type is 255, no entry requirement is set
            if meta.req_type == REQ_TYPE_NONE {
                return Option::None;
            }

            let entry_requirement_type = match meta.req_type {
                0 => { // TOKEN
                    let token = self.EntryRequirement_token.entry(context_id).read();
                    EntryRequirementType::token(token)
                },
                1 => { // ALLOWLIST
                    let addresses = self.read_allowlist(context_id);
                    EntryRequirementType::allowlist(addresses)
                },
                2 => { // EXTENSION
                    let address = self.EntryRequirement_extension_address.entry(context_id).read();
                    let config = self.read_extension_config(context_id);
                    EntryRequirementType::extension(ExtensionConfig { address, config })
                },
                _ => { return Option::None; },
            };

            Option::Some(EntryRequirement { entry_limit: meta.entry_limit, entry_requirement_type })
        }

        /// Set entry requirement for a context
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
                            self.EntryRequirement_token.entry(context_id).write(token);
                            (REQ_TYPE_TOKEN, req.entry_limit)
                        },
                        EntryRequirementType::allowlist(addresses) => {
                            self.write_allowlist(context_id, addresses);
                            (REQ_TYPE_ALLOWLIST, req.entry_limit)
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
                            self
                                .EntryRequirement_extension_address
                                .entry(context_id)
                                .write(config.address);
                            self.write_extension_config(context_id, config.config);
                            (REQ_TYPE_EXTENSION, req.entry_limit)
                        },
                    };

                    let meta = EntryRequirementMeta { entry_limit, req_type };
                    self.EntryRequirement_meta.entry(context_id).write(meta);
                },
                Option::None => {
                    // Write empty meta with REQ_TYPE_NONE
                    let meta = EntryRequirementMeta { entry_limit: 0, req_type: REQ_TYPE_NONE };
                    self.EntryRequirement_meta.entry(context_id).write(meta);
                },
            }
        }

        /// Get qualification entries for a context and qualification proof (internal)
        fn _get_qualification_entries(
            self: @ComponentState<TContractState>, context_id: u64, proof: QualificationProof,
        ) -> QualificationEntries {
            let qualification_hash = self.hash_qualification_proof(proof);
            let entry_count = self
                .EntryRequirement_qualification_entries
                .entry((context_id, qualification_hash))
                .read();
            QualificationEntries { context_id, qualification_proof: proof, entry_count }
        }

        /// Set qualification entries for a context
        fn set_qualification_entries(
            ref self: ComponentState<TContractState>, entries: @QualificationEntries,
        ) {
            let qualification_hash = self.hash_qualification_proof(*entries.qualification_proof);
            self
                .EntryRequirement_qualification_entries
                .entry((*entries.context_id, qualification_hash))
                .write(*entries.entry_count);
        }

        // Internal helper functions
        fn read_allowlist(
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

        fn write_allowlist(
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

        fn read_extension_config(
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

        fn write_extension_config(
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

        fn hash_qualification_proof(
            self: @ComponentState<TContractState>, proof: QualificationProof,
        ) -> felt252 {
            let mut data = ArrayTrait::new();
            proof.serialize(ref data);
            poseidon_hash_span(data.span())
        }

        /// Validates a qualification proof against an entry requirement.
        /// Returns the qualifying address (NFT owner, allowlist address, or caller).
        fn validate_qualification(
            self: @ComponentState<TContractState>,
            context_id: u64,
            entry_requirement: EntryRequirement,
            qualifier: QualificationProof,
        ) -> ContractAddress {
            match entry_requirement.entry_requirement_type {
                EntryRequirementType::token(token_address) => {
                    let qualification = match qualifier {
                        QualificationProof::NFT(qual) => qual,
                        _ => panic!(
                            "EntryRequirement: Provided qualification proof is not of type 'NFT'",
                        ),
                    };
                    let erc721_dispatcher = IERC721Dispatcher { contract_address: token_address };
                    erc721_dispatcher.owner_of(qualification.token_id)
                },
                EntryRequirementType::allowlist(addresses) => {
                    let qualifying_address = match qualifier {
                        QualificationProof::Address(addr) => addr,
                        _ => panic!(
                            "EntryRequirement: Provided qualification proof is not of type 'Address'",
                        ),
                    };
                    assert!(
                        Self::_contains_address(addresses, qualifying_address),
                        "EntryRequirement: Qualifying address is not in allowlist",
                    );
                    qualifying_address
                },
                EntryRequirementType::extension(extension_config) => {
                    let qualification = match qualifier {
                        QualificationProof::Extension(qual) => qual,
                        _ => panic!(
                            "EntryRequirement: Provided qualification proof is not of type 'Extension'",
                        ),
                    };
                    let entry_validator_dispatcher = IEntryValidatorDispatcher {
                        contract_address: extension_config.address,
                    };
                    let caller_address = get_caller_address();
                    let display_extension_address: felt252 = extension_config.address.into();
                    assert!(
                        entry_validator_dispatcher
                            .valid_entry(context_id, caller_address, qualification),
                        "EntryRequirement: Invalid entry according to extension {}",
                        display_extension_address,
                    );
                    caller_address
                },
            }
        }

        /// Validates entry requirement configuration at creation time.
        /// Checks SRC5 interfaces (ERC721 for token, IEntryValidator for extension).
        fn assert_valid_entry_requirement(
            self: @ComponentState<TContractState>, entry_requirement: EntryRequirement,
        ) {
            match entry_requirement.entry_requirement_type {
                EntryRequirementType::token(token) => {
                    let src5_dispatcher = ISRC5Dispatcher { contract_address: token };
                    let display_address: felt252 = token.into();
                    assert!(
                        src5_dispatcher.supports_interface(IERC721_ID),
                        "EntryRequirement: Token address {} does not support IERC721 interface",
                        display_address,
                    );
                },
                EntryRequirementType::allowlist(_) => {},
                EntryRequirementType::extension(extension_config) => {
                    let extension_address = extension_config.address;
                    assert!(
                        !extension_address.is_zero(),
                        "EntryRequirement: Extension address can't be zero",
                    );
                    let src5_dispatcher = ISRC5Dispatcher { contract_address: extension_address };
                    let display_address: felt252 = extension_address.into();
                    assert!(
                        src5_dispatcher.supports_interface(IENTRY_REQUIREMENT_EXTENSION_ID),
                        "EntryRequirement: Extension address {} does not support IEntryValidator interface",
                        display_address,
                    );
                },
            }
        }

        fn _contains_address(addresses: Span<ContractAddress>, target: ContractAddress) -> bool {
            let mut i = 0;
            loop {
                if i >= addresses.len() {
                    break false;
                }
                if *addresses.at(i) == target {
                    break true;
                }
                i += 1;
            }
        }

        /// Update qualification entries after a successful entry
        fn update_qualification_entries(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            qualifier: QualificationProof,
            entry_requirement: EntryRequirement,
        ) {
            match entry_requirement.entry_requirement_type {
                EntryRequirementType::extension(extension_config) => {
                    let extension_address = extension_config.address;
                    let entry_validator_dispatcher = IEntryValidatorDispatcher {
                        contract_address: extension_address,
                    };
                    let display_extension_address: felt252 = extension_address.into();
                    let caller_address = get_caller_address();

                    let qualification = match qualifier {
                        QualificationProof::Extension(qual) => qual,
                        _ => panic!(
                            "EntryRequirement: Provided qualification proof is not of type 'Extension'",
                        ),
                    };

                    let entries_left = entry_validator_dispatcher
                        .entries_left(context_id, caller_address, qualification);

                    match entries_left {
                        Option::Some(entries_left) => {
                            assert!(
                                entries_left > 0,
                                "EntryRequirement: No entries left according to extension {}",
                                display_extension_address,
                            );
                        },
                        Option::None => {},
                    }
                },
                _ => {
                    let entry_limit = entry_requirement.entry_limit;
                    if entry_limit != 0 {
                        let mut qualification_entries = self
                            ._get_qualification_entries(context_id, qualifier);

                        assert!(
                            qualification_entries.entry_count.into() < entry_limit,
                            "EntryRequirement: Maximum qualified entries reached for context {}",
                            context_id,
                        );

                        qualification_entries.entry_count += 1;

                        self.set_qualification_entries(@qualification_entries);
                    }
                },
            }
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
