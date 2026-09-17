//! Optional owner enumeration for felt252 ERC721 token IDs.
//! Uses pre-update ERC721 balances; supports burns with swap-and-pop removal.
//! Integrate from the first mint in a new/empty collection, with default OZ ownership and
//! felt252 IDs on every mint path. A populated collection needs a separate index migration.
//! For every active owner index, both maps agree with ERC721 ownership. Vacated tail cells
//! and reverse indexes of burned tokens are zero. Index zero itself is a valid value.
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
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::token::extensions::enumerable::interface::IENUMERABLE_OWNER_ID;

    // Internal storage uses felt252 for single-slot efficiency.
    // External interface converts u256 <-> felt252 at the boundary.
    #[storage]
    pub struct Storage {
        pub Enumerable_owned_tokens: Map<(ContractAddress, felt252), felt252>,
        pub Enumerable_owned_tokens_index: Map<felt252, felt252>,
    }

    pub mod Errors {
        pub const TOKEN_ID_OUT_OF_RANGE: felt252 = 'ERC721Enum: token ID too large';
        pub const OUT_OF_BOUNDS_INDEX: felt252 = 'ERC721Enum: out of bounds index';
    }

    #[embeddable_as(EnumerableImpl)]
    pub impl Enumerable<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +ERC721Component::ERC721TokenOwnerTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of super::super::interface::IEnumerableOwner<ComponentState<TContractState>> {
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
        +ERC721Component::ERC721TokenOwnerTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IENUMERABLE_OWNER_ID);
        }

        fn before_update(
            ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256,
        ) {
            let erc721_component = get_dep_component!(@self, ERC721);
            let previous_owner = erc721_component._owner_of(token_id);
            // This component supports felt252 IDs only. Generic embedders must fail closed
            // on wider IDs instead of allowing ERC721 balances to diverge from the indexes.
            let id = token_id.try_into().expect(Errors::TOKEN_ID_OUT_OF_RANGE);
            self.before_update_with_owner(to, id, previous_owner);
        }

        /// The caller supplies the current ERC721 owner, read before the update and without
        /// any intervening external call. Balances must still be the pre-update balances.
        fn before_update_with_owner(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id_felt: felt252,
            previous_owner: ContractAddress,
        ) {
            if previous_owner == to {
                return;
            }
            let is_mint = previous_owner.is_zero();
            let is_burn = to.is_zero();
            if !is_mint {
                self._remove_token_from_owner_enumeration(previous_owner, token_id_felt, is_burn);
            }

            if !is_burn {
                self._add_token_to_owner_enumeration(to, token_id_felt, is_mint);
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
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id: felt252,
            is_mint: bool,
        ) {
            let erc721_component = get_dep_component!(@self, ERC721);
            let len: felt252 = erc721_component.balance_of(to).try_into().unwrap();
            self.Enumerable_owned_tokens.write((to, len), token_id);
            // Fresh IDs and burned IDs have a zero reverse index. Transfers must always
            // overwrite it, including when moving a nonzero index into an empty wallet.
            if !is_mint || len != 0 {
                self.Enumerable_owned_tokens_index.write(token_id, len);
            }
        }

        fn _remove_token_from_owner_enumeration(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            token_id: felt252,
            is_burn: bool,
        ) {
            let erc721_component = get_dep_component!(@self, ERC721);
            let last_token_index: felt252 = (erc721_component.balance_of(from) - 1)
                .try_into()
                .unwrap();
            let index_entry = self.Enumerable_owned_tokens_index.entry(token_id);
            let this_token_index = index_entry.read();

            let last_entry = self.Enumerable_owned_tokens.entry((from, last_token_index));
            if this_token_index != last_token_index {
                let last_token_id = last_entry.read();
                self.Enumerable_owned_tokens.write((from, this_token_index), last_token_id);
                self.Enumerable_owned_tokens_index.write(last_token_id, this_token_index);
            }

            last_entry.write(0);
            // A transfer overwrites this reverse index in _add immediately, without any
            // external call in between. Burns retain the zero-on-absence invariant.
            if is_burn && this_token_index != 0 {
                index_entry.write(0);
            }
        }
    }
}
