use openzeppelin_interfaces::erc721::{
    IERC721CamelOnlySafeDispatcher, IERC721CamelOnlySafeDispatcherTrait,
};
use starknet::ContractAddress;
#[starknet::interface]
pub trait IVirtualControls<T> {
    fn seed(ref self: T, owner: ContractAddress);
    fn burn(ref self: T);
}
#[starknet::contract]
pub mod VirtualOwnerHost {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::{
        StorageMapReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::erc721::ERC721Component;
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    impl Internal = ERC721Component::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl NFT = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl Camel = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        virtual_owner: ContractAddress,
        active: bool,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }
    impl Owner of ERC721Component::ERC721TokenOwnerTrait<ContractState> {
        fn owner_of(
            self: @ERC721Component::ComponentState<ContractState>, token_id: u256,
        ) -> ContractAddress {
            let contract = self.get_contract();
            if token_id >= 0x800000000000011000000000000000000000000000000000000000000000001 {
                return contract.virtual_owner.read();
            }
            if token_id == 42 && contract.active.read() {
                contract.virtual_owner.read()
            } else {
                match token_id.try_into() {
                    Some(key) => self.ERC721_owners.read(key),
                    None => 0.try_into().unwrap(),
                }
            }
        }
    }
    impl Hooks of ERC721Component::ERC721HooksTrait<ContractState> {
        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            if token_id == 42 {
                let mut contract = self.get_contract_mut();
                contract.active.write(false);
            }
        }
    }
    #[abi(embed_v0)]
    impl Controls of super::IVirtualControls<ContractState> {
        fn seed(ref self: ContractState, owner: ContractAddress) {
            assert(!self.active.read(), 'ALREADY_SEEDED');
            self.virtual_owner.write(owner);
            self.active.write(true);
            self.erc721.increase_balance(owner, 1);
        }
        fn burn(ref self: ContractState) {
            self.erc721.burn(42);
        }
    }
}
use openzeppelin_interfaces::erc721::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721SafeDispatcher, IERC721SafeDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use super::safety_helpers::{context, expect_error};
#[test]
#[feature("safe_dispatcher")]
fn custom_virtual_owner_transfer_uses_trait_and_clears_approval() {
    let (address, _) = declare("VirtualOwnerHost")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();
    let owner: ContractAddress = 201.try_into().unwrap();
    let recipient: ContractAddress = 202.try_into().unwrap();
    let operator: ContractAddress = 203.try_into().unwrap();
    IVirtualControlsDispatcher { contract_address: address }.seed(owner);
    let nft = IERC721Dispatcher { contract_address: address };
    assert_eq!(nft.owner_of(42), owner);
    assert_eq!(nft.balance_of(owner), 1);
    context(address, 201, 0, 0);
    nft.approve(operator, 42);
    context(address, 203, 0, 0);
    nft.transfer_from(owner, recipient, 42);
    assert_eq!(nft.owner_of(42), recipient);
    assert_eq!(nft.balance_of(owner), 0);
    assert_eq!(nft.balance_of(recipient), 1);
    assert_eq!(nft.get_approved(42), 0.try_into().unwrap());
    IVirtualControlsDispatcher { contract_address: address }.burn();
    expect_error(
        IERC721SafeDispatcher { contract_address: address }.owner_of(42),
        'ERC721: invalid token ID',
    );
    assert_eq!(nft.balance_of(recipient), 0);
}
#[test]
#[feature("safe_dispatcher")]
fn custom_virtual_owner_burn_uses_trait_and_checked_balance() {
    let (address, _) = declare("VirtualOwnerHost")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();
    let owner: ContractAddress = 201.try_into().unwrap();
    let raw = IVirtualControlsDispatcher { contract_address: address };
    raw.seed(owner);
    raw.burn();
    assert_eq!(IERC721Dispatcher { contract_address: address }.balance_of(owner), 0);
    expect_error(
        IERC721SafeDispatcher { contract_address: address }.owner_of(42),
        'ERC721: invalid token ID',
    );
}

#[test]
#[feature("safe_dispatcher")]
fn custom_owner_cannot_claim_out_of_domain_ids() {
    let (address, _) = declare("VirtualOwnerHost")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();
    let owner: ContractAddress = 201.try_into().unwrap();
    IVirtualControlsDispatcher { contract_address: address }.seed(owner);
    context(address, 201, 0, 0);
    let safe = IERC721SafeDispatcher { contract_address: address };
    for id in array![
        0x800000000000011000000000000000000000000000000000000000000000001_u256,
        0x800000000000011000000000000000000000000000000000000000000000002,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
    ] {
        expect_error(safe.owner_of(id), 'ERC721: invalid token ID');
        expect_error(safe.get_approved(id), 'ERC721: invalid token ID');
        expect_error(safe.approve(owner, id), 'ERC721: invalid token ID');
        expect_error(
            safe.transfer_from(owner, 202.try_into().unwrap(), id), 'ERC721: invalid token ID',
        );
    }
    assert_eq!(IERC721Dispatcher { contract_address: address }.owner_of(42), owner);
    assert_eq!(IERC721Dispatcher { contract_address: address }.balance_of(owner), 1);
}

#[test]
#[feature("safe_dispatcher")]
fn custom_wide_owner_cannot_grant_approval_or_operator_authority() {
    let (address, _) = declare("VirtualOwnerHost")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();
    let owner: ContractAddress = 201.try_into().unwrap();
    let operator: ContractAddress = 202.try_into().unwrap();
    IVirtualControlsDispatcher { contract_address: address }.seed(owner);
    context(address, 201, 0, 0);
    let nft = IERC721Dispatcher { contract_address: address };
    nft.set_approval_for_all(operator, true);
    let safe = IERC721SafeDispatcher { contract_address: address };
    let wide: u256 = 0x800000000000011000000000000000000000000000000000000000000000001;
    expect_error(
        IERC721CamelOnlySafeDispatcher { contract_address: address }.ownerOf(wide),
        'ERC721: invalid token ID',
    );
    expect_error(safe.get_approved(wide), 'ERC721: invalid token ID');
    context(address, 202, 0, 0);
    expect_error(safe.transfer_from(owner, operator, wide), 'ERC721: invalid token ID');
    assert_eq!(nft.balance_of(owner), 1);
    assert_eq!(nft.owner_of(42), owner);
}
