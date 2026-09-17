use starknet::ContractAddress;

#[starknet::interface]
pub trait IExtensionControls<T> {
    fn mint(ref self: T, to: ContractAddress, id: u256);
    fn mint_pair(ref self: T, to: ContractAddress, first: u256, second: u256);
    fn safe_mint(ref self: T, to: ContractAddress, id: u256, data: Span<felt252>);
    fn burn(ref self: T, id: u256);
    fn set_uri(ref self: T, id: u256, uri: ByteArray);
    fn set_royalty(ref self: T, id: u256, to: ContractAddress, amount: u128);
    fn set_hook_mode(ref self: T, mode: u8);
    fn hook_counts(self: @T) -> (u32, u32);
}

#[starknet::contract]
pub mod ExtensionHost {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::common::erc2981::{DefaultConfig, ERC2981Component};
    use crate::erc721::extensions::erc721_uri_storage::ERC721URIStorageComponent::ERC721TokenURIStorageImpl;
    use crate::erc721::extensions::{ERC721EnumerableComponent, ERC721URIStorageComponent};
    use crate::erc721::{ERC721Component, ERC721OwnerOfDefaultImpl};
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721EnumerableComponent, storage: enumerable, event: EnumerableEvent);
    component!(path: ERC721URIStorageComponent, storage: uri, event: URIEvent);
    component!(path: ERC2981Component, storage: royalty, event: RoyaltyEvent);
    impl ERC721Internal = ERC721Component::InternalImpl<ContractState>;
    impl EnumerableInternal = ERC721EnumerableComponent::InternalImpl<ContractState>;
    impl URIInternal = ERC721URIStorageComponent::InternalImpl<ContractState>;
    impl RoyaltyInternal = ERC2981Component::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl NFT = ERC721Component::ERC721MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl Enumeration =
        ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;
    #[abi(embed_v0)]
    impl Royalties = ERC2981Component::ERC2981Impl<ContractState>;
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        uri: ERC721URIStorageComponent::Storage,
        #[substorage(v0)]
        royalty: ERC2981Component::Storage,
        mode: u8,
        before_count: u32,
        after_count: u32,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        URIEvent: ERC721URIStorageComponent::Event,
        #[flat]
        RoyaltyEvent: ERC2981Component::Event,
    }
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721.initializer("Felt", "FELT", "");
        self.enumerable.initializer();
        self.royalty.initializer(201.try_into().unwrap(), 100);
    }
    impl Hooks of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract = self.get_contract_mut();
            contract.before_count.write(contract.before_count.read() + 1);
            assert(contract.mode.read() != 1, 'BEFORE_REJECT');
            if contract.mode.read() == 3 {
                contract.mode.write(0);
                contract.erc721.mint(to, token_id + 1);
            }
            contract.enumerable.before_update(to, token_id);
        }
        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract = self.get_contract_mut();
            contract.after_count.write(contract.after_count.read() + 1);
            contract.uri.after_update(to, token_id, auth);
            assert(contract.mode.read() != 2, 'AFTER_REJECT');
        }
    }
    #[abi(embed_v0)]
    impl Controls of super::IExtensionControls<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, id: u256) {
            self.erc721.mint(to, id);
        }
        fn mint_pair(ref self: ContractState, to: ContractAddress, first: u256, second: u256) {
            self.erc721.mint(to, first);
            self.uri.set_token_uri(first, "FIRST");
            self.royalty._set_token_royalty(first, to, 222);
            self.erc721.mint(to, second);
        }
        fn safe_mint(ref self: ContractState, to: ContractAddress, id: u256, data: Span<felt252>) {
            self.erc721.safe_mint(to, id, data);
        }
        fn burn(ref self: ContractState, id: u256) {
            self.erc721.burn(id);
        }
        fn set_uri(ref self: ContractState, id: u256, uri: ByteArray) {
            self.uri.set_token_uri(id, uri);
        }
        fn set_royalty(ref self: ContractState, id: u256, to: ContractAddress, amount: u128) {
            self.royalty._set_token_royalty(id, to, amount);
        }
        fn set_hook_mode(ref self: ContractState, mode: u8) {
            self.mode.write(mode);
        }
        fn hook_counts(self: @ContractState) -> (u32, u32) {
            (self.before_count.read(), self.after_count.read())
        }
    }
}
