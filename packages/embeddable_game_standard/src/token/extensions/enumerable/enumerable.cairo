/// # EnumerableComponent
///
/// Drop-in replacement for OZ's ERC721EnumerableComponent that uses felt252
/// for internal storage instead of u256, saving ~2x gas per storage operation.
/// The external interface remains IERC721Enumerable (u256) for full compatibility
/// with existing consumers and dispatchers.
///
/// Burn is not supported — `all_tokens_index` has been removed to save one
/// storage write per mint.
///
/// WARNING: The `before_update` function must be called after every transfer
/// or mint operation via the ERC721HooksTrait::before_update hook.
#[starknet::component]
pub mod EnumerableComponent {
    use core::num::traits::Zero;
    use openzeppelin_interfaces::erc721 as oz_interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::{
        ERC721Impl, InternalImpl as ERC721InternalImpl,
    };
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::token::extensions::enumerable::interface::IERC721_ENUMERABLE_ID;

    // Internal storage uses felt252 for single-slot efficiency.
    // External interface converts u256 <-> felt252 at the boundary.
    #[storage]
    pub struct Storage {
        pub Enumerable_owned_tokens: Map<(ContractAddress, felt252), felt252>,
        pub Enumerable_owned_tokens_index: Map<felt252, felt252>,
        pub Enumerable_all_tokens_len: felt252,
        pub Enumerable_all_tokens: Map<felt252, felt252>,
    }

    pub mod Errors {
        pub const OUT_OF_BOUNDS_INDEX: felt252 = 'ERC721Enum: out of bounds index';
        pub const BURN_NOT_SUPPORTED: felt252 = 'ERC721Enum: burn not supported';
    }

    #[embeddable_as(EnumerableImpl)]
    pub impl Enumerable<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of oz_interface::IERC721Enumerable<ComponentState<TContractState>> {
        fn total_supply(self: @ComponentState<TContractState>) -> u256 {
            let len: felt252 = self.Enumerable_all_tokens_len.read();
            len.into()
        }

        fn token_by_index(self: @ComponentState<TContractState>, index: u256) -> u256 {
            assert(index < self.total_supply(), Errors::OUT_OF_BOUNDS_INDEX);
            let index_felt: felt252 = index.try_into().unwrap();
            let token_id: felt252 = self.Enumerable_all_tokens.read(index_felt);
            token_id.into()
        }

        fn token_of_owner_by_index(
            self: @ComponentState<TContractState>, owner: ContractAddress, index: u256,
        ) -> u256 {
            let erc721_component = get_dep_component!(self, ERC721);
            assert(index < erc721_component.balance_of(owner), Errors::OUT_OF_BOUNDS_INDEX);
            let index_felt: felt252 = index.try_into().unwrap();
            let token_id: felt252 = self.Enumerable_owned_tokens.read((owner, index_felt));
            token_id.into()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IERC721_ENUMERABLE_ID);
        }

        fn before_update(
            ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256,
        ) {
            let erc721_component = get_dep_component!(@self, ERC721);
            let previous_owner = erc721_component._owner_of(token_id);
            assert(!to.is_zero() || previous_owner.is_zero(), Errors::BURN_NOT_SUPPORTED);
            let token_id_felt: felt252 = token_id.try_into().unwrap();

            if previous_owner.is_zero() {
                self._add_token_to_all_tokens_enumeration(token_id_felt);
            } else if previous_owner != to {
                self._remove_token_from_owner_enumeration(previous_owner, token_id_felt);
            }

            if !to.is_zero() && previous_owner != to {
                self._add_token_to_owner_enumeration(to, token_id_felt);
            }
        }

        fn all_tokens_of_owner(
            self: @ComponentState<TContractState>, owner: ContractAddress,
        ) -> Span<u256> {
            let mut result = array![];
            let erc721_component = get_dep_component!(self, ERC721);
            let balance: u64 = erc721_component.balance_of(owner).try_into().unwrap();
            for index in 0..balance {
                let index_felt: felt252 = index.into();
                let token_id: felt252 = self.Enumerable_owned_tokens.read((owner, index_felt));
                result.append(token_id.into());
            }
            result.span()
        }

        fn _add_token_to_owner_enumeration(
            ref self: ComponentState<TContractState>, to: ContractAddress, token_id: felt252,
        ) {
            let erc721_component = get_dep_component!(@self, ERC721);
            let len: felt252 = erc721_component.balance_of(to).try_into().unwrap();
            self.Enumerable_owned_tokens.write((to, len), token_id);
            self.Enumerable_owned_tokens_index.write(token_id, len);
        }

        fn _add_token_to_all_tokens_enumeration(
            ref self: ComponentState<TContractState>, token_id: felt252,
        ) {
            let supply = self.Enumerable_all_tokens_len.read();
            self.Enumerable_all_tokens.write(supply, token_id);
            self.Enumerable_all_tokens_len.write(supply + 1);
        }

        fn _remove_token_from_owner_enumeration(
            ref self: ComponentState<TContractState>, from: ContractAddress, token_id: felt252,
        ) {
            let erc721_component = get_dep_component!(@self, ERC721);
            let last_token_index: felt252 = (erc721_component.balance_of(from) - 1)
                .try_into()
                .unwrap();
            let this_token_index = self.Enumerable_owned_tokens_index.read(token_id);

            if this_token_index != last_token_index {
                let last_token_id = self.Enumerable_owned_tokens.read((from, last_token_index));
                self.Enumerable_owned_tokens.write((from, this_token_index), last_token_id);
                self.Enumerable_owned_tokens_index.write(last_token_id, this_token_index);
            }

            self.Enumerable_owned_tokens.write((from, last_token_index), 0);
            self.Enumerable_owned_tokens_index.write(token_id, 0);
        }
    }
}
