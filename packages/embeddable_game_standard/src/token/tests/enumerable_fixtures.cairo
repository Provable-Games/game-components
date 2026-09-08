//! Test-only embedders and adversarial receiver. Mint is deliberately unrestricted.
use starknet::ContractAddress;

#[starknet::interface]
pub trait IEnumerationFixture<T> {
    fn mint(ref self: T, to: ContractAddress, token_id: u256);
    fn safe_mint(ref self: T, to: ContractAddress, token_id: u256, data: Span<felt252>);
    fn burn(ref self: T, token_id: u256);
    fn all_tokens(self: @T, owner: ContractAddress) -> Span<u256>;
    fn stored_indexes(
        self: @T, owner: ContractAddress, index: felt252, token_id: felt252,
    ) -> (felt252, felt252);
    fn initialize_again(ref self: T);
}

#[starknet::contract]
pub mod EnumerableGenericMock {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;
    use starknet::storage::StorageMapReadAccess;
    use starknet::{ContractAddress, get_caller_address};
    use crate::token::extensions::enumerable::enumerable::EnumerableComponent;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: EnumerableComponent, storage: enumerable, event: EnumerableEvent);
    impl ERC721Internal = ERC721Component::InternalImpl<ContractState>;
    impl EnumerableInternal = EnumerableComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl NFT = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl Introspection = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl Enumeration = EnumerableComponent::EnumerableImpl<ContractState>;
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        enumerable: EnumerableComponent::Storage,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        EnumerableEvent: EnumerableComponent::Event,
    }
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721.initializer("Enumerable test", "ENUM", "");
        self.enumerable.initializer();
    }
    impl Hooks of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract = self.get_contract_mut();
            contract.enumerable.before_update(to, token_id);
        }
    }
    #[abi(embed_v0)]
    impl Fixture of super::IEnumerationFixture<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self.erc721.mint(to, token_id);
        }
        fn safe_mint(
            ref self: ContractState, to: ContractAddress, token_id: u256, data: Span<felt252>,
        ) {
            self.erc721.safe_mint(to, token_id, data);
        }
        fn burn(ref self: ContractState, token_id: u256) {
            assert(self.erc721.owner_of(token_id) == get_caller_address(), 'Only holder can burn');
            self.erc721.burn(token_id);
        }
        fn all_tokens(self: @ContractState, owner: ContractAddress) -> Span<u256> {
            self.enumerable.all_tokens_of_owner(owner)
        }
        fn stored_indexes(
            self: @ContractState, owner: ContractAddress, index: felt252, token_id: felt252,
        ) -> (felt252, felt252) {
            (
                self.enumerable.Enumerable_owned_tokens.read((owner, index)),
                self.enumerable.Enumerable_owned_tokens_index.read(token_id),
            )
        }
        fn initialize_again(ref self: ContractState) {
            self.enumerable.initializer();
        }
    }
}

#[starknet::contract]
pub mod EnumerableOwnerMock {
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;
    use starknet::storage::StorageMapReadAccess;
    use starknet::{ContractAddress, get_caller_address};
    use crate::token::extensions::enumerable::enumerable::EnumerableComponent;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: EnumerableComponent, storage: enumerable, event: EnumerableEvent);
    impl ERC721Internal = ERC721Component::InternalImpl<ContractState>;
    impl EnumerableInternal = EnumerableComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl NFT = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl Introspection = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl Enumeration = EnumerableComponent::EnumerableImpl<ContractState>;
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        enumerable: EnumerableComponent::Storage,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        EnumerableEvent: EnumerableComponent::Event,
    }
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721.initializer("Enumerable test", "ENUM", "");
        self.enumerable.initializer();
    }
    impl Hooks of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let previous_owner = self._owner_of(token_id);
            // Same owner read needed by the standard game's soulbound hook.
            if !previous_owner.is_zero() && !to.is_zero() {
                assert(
                    !crate::token::packing::unpack_soulbound(token_id.try_into().unwrap()),
                    'Token is soulbound',
                );
            }
            let mut contract = self.get_contract_mut();
            let id = token_id.try_into().expect(EnumerableComponent::Errors::TOKEN_ID_OUT_OF_RANGE);
            contract.enumerable.before_update_with_owner(to, id, previous_owner);
        }
    }
    #[abi(embed_v0)]
    impl Fixture of super::IEnumerationFixture<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self.erc721.mint(to, token_id);
        }
        fn safe_mint(
            ref self: ContractState, to: ContractAddress, token_id: u256, data: Span<felt252>,
        ) {
            self.erc721.safe_mint(to, token_id, data);
        }
        fn burn(ref self: ContractState, token_id: u256) {
            assert(self.erc721.owner_of(token_id) == get_caller_address(), 'Only holder can burn');
            self.erc721.burn(token_id);
        }
        fn all_tokens(self: @ContractState, owner: ContractAddress) -> Span<u256> {
            self.enumerable.all_tokens_of_owner(owner)
        }
        fn stored_indexes(
            self: @ContractState, owner: ContractAddress, index: felt252, token_id: felt252,
        ) -> (felt252, felt252) {
            (
                self.enumerable.Enumerable_owned_tokens.read((owner, index)),
                self.enumerable.Enumerable_owned_tokens_index.read(token_id),
            )
        }
        fn initialize_again(ref self: ContractState) {
            self.enumerable.initializer();
        }
    }
}

#[starknet::contract]
pub mod EnumerableReferenceMock {
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;
    use starknet::storage::StorageMapReadAccess;
    use starknet::{ContractAddress, get_caller_address};
    use crate::token::tests::enumerable_reference::EnumerableComponent;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: EnumerableComponent, storage: enumerable, event: EnumerableEvent);
    impl ERC721Internal = ERC721Component::InternalImpl<ContractState>;
    impl EnumerableInternal = EnumerableComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl NFT = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl Introspection = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl Enumeration = EnumerableComponent::EnumerableImpl<ContractState>;
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        enumerable: EnumerableComponent::Storage,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        EnumerableEvent: EnumerableComponent::Event,
    }
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721.initializer("Enumerable test", "ENUM", "");
        self.enumerable.initializer();
    }
    impl Hooks of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let previous_owner = self._owner_of(token_id);
            // Same owner read needed by the standard game's soulbound hook.
            if !previous_owner.is_zero() && !to.is_zero() {
                assert(
                    !crate::token::packing::unpack_soulbound(token_id.try_into().unwrap()),
                    'Token is soulbound',
                );
            }
            let mut contract = self.get_contract_mut();
            contract.enumerable.before_update(to, token_id);
        }
    }
    #[abi(embed_v0)]
    impl Fixture of super::IEnumerationFixture<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self.erc721.mint(to, token_id);
        }
        fn safe_mint(
            ref self: ContractState, to: ContractAddress, token_id: u256, data: Span<felt252>,
        ) {
            self.erc721.safe_mint(to, token_id, data);
        }
        fn burn(ref self: ContractState, token_id: u256) {
            assert(self.erc721.owner_of(token_id) == get_caller_address(), 'Only holder can burn');
            self.erc721.burn(token_id);
        }
        fn all_tokens(self: @ContractState, owner: ContractAddress) -> Span<u256> {
            self.enumerable.all_tokens_of_owner(owner)
        }
        fn stored_indexes(
            self: @ContractState, owner: ContractAddress, index: felt252, token_id: felt252,
        ) -> (felt252, felt252) {
            (
                self.enumerable.Enumerable_owned_tokens.read((owner, index)),
                self.enumerable.Enumerable_owned_tokens_index.read(token_id),
            )
        }
        fn initialize_again(ref self: ContractState) {
            self.enumerable.initializer();
        }
    }
}

#[starknet::contract]
pub mod EnumerationAuditReceiver {
    use openzeppelin_interfaces::erc721::{
        IERC721Dispatcher, IERC721DispatcherTrait, IERC721Receiver, IERC721_RECEIVER_ID,
    };
    use openzeppelin_interfaces::introspection::ISRC5;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::token::extensions::enumerable::interface::{
        IEnumerableOwnerDispatcher, IEnumerableOwnerDispatcherTrait,
    };
    use super::{IEnumerationFixtureDispatcher, IEnumerationFixtureDispatcherTrait};
    #[storage]
    struct Storage {}
    #[abi(embed_v0)]
    impl Introspection of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == IERC721_RECEIVER_ID
        }
    }
    #[abi(embed_v0)]
    impl Receiver of IERC721Receiver<ContractState> {
        fn on_erc721_received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>,
        ) -> felt252 {
            let target = get_caller_address();
            let owner = get_contract_address();
            let nft = IERC721Dispatcher { contract_address: target };
            let enumeration = IEnumerableOwnerDispatcher { contract_address: target };
            // A receiver must observe fully consistent ERC721 and enumeration state.
            assert!(nft.owner_of(token_id) == owner, "Enumeration mismatch");
            assert!(
                enumeration.token_of_owner_by_index(owner, nft.balance_of(owner) - 1) == token_id,
                "Enumeration mismatch",
            );
            let mode = *data.at(0);
            if mode == 1 || mode == 3 {
                nft.transfer_from(owner, from, token_id);
            } else if mode == 2 {
                IEnumerationFixtureDispatcher { contract_address: target }.burn(token_id);
            }
            if mode == 3 {
                0
            } else {
                IERC721_RECEIVER_ID
            }
        }
    }
}


// A single measured call per operation; setup and assertions stay outside this contract.
#[starknet::interface]
pub trait IEnumerationProbe<T> {
    fn measure(ref self: T, target: ContractAddress, entrypoint: felt252, calldata: Span<felt252>);
    fn floor(ref self: T, target: ContractAddress, entrypoint: felt252, calldata: Span<felt252>);
}
#[starknet::contract]
pub mod EnumerationGasProbe {
    use starknet::ContractAddress;
    #[storage]
    struct Storage {}
    #[abi(embed_v0)]
    impl Probe of super::IEnumerationProbe<ContractState> {
        fn measure(
            ref self: ContractState,
            target: ContractAddress,
            entrypoint: felt252,
            calldata: Span<felt252>,
        ) {
            starknet::syscalls::call_contract_syscall(target, entrypoint, calldata).unwrap();
        }
        fn floor(
            ref self: ContractState,
            target: ContractAddress,
            entrypoint: felt252,
            calldata: Span<felt252>,
        ) {}
    }
}
