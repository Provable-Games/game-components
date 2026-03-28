#[starknet::component]
pub mod SkillsComponent {
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use openzeppelin_token::erc721::ERC721Component::ERC721Impl;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::token::extensions::skills::interface::{
        IMINIGAME_TOKEN_SKILLS_ID, IMinigameTokenSkills,
    };
    use crate::token::token::address_utils;
    use crate::token::token_component::CoreTokenComponent;
    use crate::token::token_component::CoreTokenComponent::EventEmittersTrait;
    use crate::token::traits::OptionalSkills;

    #[storage]
    pub struct Storage {
        token_skills: Map<felt252, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(SkillsImpl)]
    pub impl Skills<
        TContractState,
        +HasComponent<TContractState>,
        impl CoreToken: CoreTokenComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameTokenSkills<ComponentState<TContractState>> {
        fn get_skills_address(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> ContractAddress {
            self.token_skills.entry(token_id).read()
        }

        fn has_custom_skills(self: @ComponentState<TContractState>, token_id: felt252) -> bool {
            let addr = self.token_skills.entry(token_id).read();
            address_utils::is_non_zero_address(addr)
        }

        fn reset_token_skills(ref self: ComponentState<TContractState>, token_id: felt252) {
            // Get the contract address to check ownership
            let contract_address = get_contract_address();
            let erc721 = IERC721Dispatcher { contract_address };
            let token_owner = erc721.owner_of(token_id.into());
            let caller = get_caller_address();
            assert!(token_owner == caller, "MinigameToken: Caller is not owner of token");
            let zero_address: ContractAddress = 0.try_into().unwrap();
            self.token_skills.entry(token_id).write(zero_address);

            let mut core_token = get_dep_component_mut!(ref self, CoreToken);
            let token_id_u256: u256 = token_id.into();
            core_token.emit_metadata_update(token_id_u256);
        }

        fn reset_token_skills_batch(
            ref self: ComponentState<TContractState>, token_ids: Span<felt252>,
        ) {
            let mut index = 0;
            loop {
                if index >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(index);
                self.reset_token_skills(token_id);
                index += 1;
            }
        }

        fn get_skills_address_batch(
            self: @ComponentState<TContractState>, token_ids: Span<felt252>,
        ) -> Array<ContractAddress> {
            let mut results = array![];
            let mut index = 0;

            loop {
                if index >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(index);
                let addr = self.get_skills_address(token_id);
                results.append(addr);
                index += 1;
            }

            results
        }
    }

    // Implementation of the OptionalSkills trait for integration with CoreTokenComponent
    pub impl SkillsOptionalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of OptionalSkills<TContractState> {
        fn get_token_skills(self: @TContractState, token_id: felt252) -> Option<ContractAddress> {
            let component = HasComponent::get_component(self);
            let addr = component.token_skills.entry(token_id).read();
            address_utils::address_to_option(addr)
        }

        fn set_token_skills(
            ref self: TContractState, token_id: felt252, skills_address: ContractAddress,
        ) {
            let mut component = HasComponent::get_component_mut(ref self);
            component.token_skills.entry(token_id).write(skills_address);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_TOKEN_SKILLS_ID);
        }
    }
}
