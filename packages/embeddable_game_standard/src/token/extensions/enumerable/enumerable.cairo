/// # EnumerableComponent
///
/// Extension of MinigameToken (ERC721) that adds enumerability of all token ids
/// as well as all token ids owned by each account. Uses felt252 for token IDs
/// (matching game-components convention) instead of u256, saving ~2x gas per
/// storage operation.
///
/// WARNING: The `before_update` function must be called after every transfer,
/// mint, or burn operation via the ERC721HooksTrait::before_update hook.
#[starknet::component]
pub mod EnumerableComponent {
    use core::num::traits::Zero;
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
    use crate::token::extensions::enumerable::interface::{
        IMINIGAME_TOKEN_ENUMERABLE_ID, IMinigameTokenEnumerable,
    };

    #[storage]
    pub struct Storage {
        Enumerable_owned_tokens: Map<(ContractAddress, felt252), felt252>,
        Enumerable_owned_tokens_index: Map<felt252, felt252>,
        Enumerable_all_tokens_len: u64,
        Enumerable_all_tokens: Map<felt252, felt252>,
        Enumerable_all_tokens_index: Map<felt252, felt252>,
    }

    pub mod Errors {
        pub const OUT_OF_BOUNDS_INDEX: felt252 = 'Enumerable: out of bounds index';
    }

    #[embeddable_as(EnumerableImpl)]
    pub impl Enumerable<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinigameTokenEnumerable<ComponentState<TContractState>> {
        fn total_supply(self: @ComponentState<TContractState>) -> u64 {
            self.Enumerable_all_tokens_len.read()
        }

        fn token_by_index(self: @ComponentState<TContractState>, index: u64) -> felt252 {
            assert(index < self.Enumerable_all_tokens_len.read(), Errors::OUT_OF_BOUNDS_INDEX);
            self.Enumerable_all_tokens.read(index.into())
        }

        fn token_of_owner_by_index(
            self: @ComponentState<TContractState>, owner: ContractAddress, index: u64,
        ) -> felt252 {
            let erc721_component = get_dep_component!(self, ERC721);
            let balance: u64 = erc721_component.balance_of(owner).try_into().unwrap();
            assert(index < balance, Errors::OUT_OF_BOUNDS_INDEX);
            self.Enumerable_owned_tokens.read((owner, index.into()))
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
            src5_component.register_interface(IMINIGAME_TOKEN_ENUMERABLE_ID);
        }

        fn before_update(
            ref self: ComponentState<TContractState>, to: ContractAddress, token_id: felt252,
        ) {
            let erc721_component = get_dep_component!(@self, ERC721);
            let previous_owner = erc721_component._owner_of(token_id.into());

            if previous_owner.is_zero() {
                self._add_token_to_all_tokens_enumeration(token_id);
            } else if previous_owner != to {
                self._remove_token_from_owner_enumeration(previous_owner, token_id);
            }

            if to.is_zero() {
                self._remove_token_from_all_tokens_enumeration(token_id);
            } else if previous_owner != to {
                self._add_token_to_owner_enumeration(to, token_id);
            }
        }

        fn all_tokens_of_owner(
            self: @ComponentState<TContractState>, owner: ContractAddress,
        ) -> Span<felt252> {
            let mut result = array![];
            let erc721_component = get_dep_component!(self, ERC721);
            let balance: u64 = erc721_component.balance_of(owner).try_into().unwrap();
            for index in 0..balance {
                result.append(self.Enumerable_owned_tokens.read((owner, index.into())));
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
            let supply_felt: felt252 = supply.into();
            self.Enumerable_all_tokens_index.write(token_id, supply_felt);
            self.Enumerable_all_tokens.write(supply_felt, token_id);
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

        fn _remove_token_from_all_tokens_enumeration(
            ref self: ComponentState<TContractState>, token_id: felt252,
        ) {
            let last_token_index: felt252 = (self.Enumerable_all_tokens_len.read() - 1).into();
            let this_token_index = self.Enumerable_all_tokens_index.read(token_id);
            let last_token_id = self.Enumerable_all_tokens.read(last_token_index);

            self.Enumerable_all_tokens.write(last_token_index, 0);
            self.Enumerable_all_tokens_index.write(token_id, 0);
            self.Enumerable_all_tokens_len.write(self.Enumerable_all_tokens_len.read() - 1);

            self.Enumerable_all_tokens_index.write(last_token_id, this_token_index);
            self.Enumerable_all_tokens.write(this_token_index, last_token_id);
        }
    }
}
