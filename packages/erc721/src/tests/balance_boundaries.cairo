use openzeppelin_interfaces::erc721::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721SafeDispatcher, IERC721SafeDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use super::balance_support::{
    IResearchBalanceDispatcher, IResearchBalanceDispatcherTrait, IResearchBalanceSafeDispatcher,
    IResearchBalanceSafeDispatcherTrait,
};
use super::safety_helpers::{context, expect_error};
const P: u256 = 0x800000000000011000000000000000000000000000000000000000000000001;
const UMAX: u128 = 0xffffffffffffffffffffffffffffffff;
fn deploy() -> ContractAddress {
    let (address, _) = declare("ResearchBalanceHost")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();
    address
}
fn account(id: felt252) -> ContractAddress {
    id.try_into().unwrap()
}

#[test]
#[feature("safe_dispatcher")]
fn research_balance_mint_overflow_and_late_batch_rollback() {
    let address = deploy();
    let raw = IResearchBalanceDispatcher { contract_address: address };
    let safe = IResearchBalanceSafeDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    let nft_safe = IERC721SafeDispatcher { contract_address: address };
    let owner = account(201);
    raw.set_balance(owner, P - 1);
    expect_error(safe.mint(owner, 1), 'ERC721: balance overflow');
    assert_eq!(nft.balance_of(owner), P - 1);
    expect_error(nft_safe.owner_of(1), 'ERC721: invalid token ID');
    raw.set_balance(owner, P - 2);
    expect_error(safe.mint_pair(owner, 2, 3), 'ERC721: balance overflow');
    assert_eq!(nft.balance_of(owner), P - 2);
    expect_error(nft_safe.owner_of(2), 'ERC721: invalid token ID');
    expect_error(nft_safe.owner_of(3), 'ERC721: invalid token ID');
    raw.mint(owner, 4);
    assert_eq!(nft.balance_of(owner), P - 1);
}

#[test]
#[feature("safe_dispatcher")]
fn research_balance_transfer_overflow_rolls_back_owner_approval_and_balances() {
    let address = deploy();
    let raw = IResearchBalanceDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    let safe = IERC721SafeDispatcher { contract_address: address };
    let owner = account(201);
    let receiver = account(202);
    let operator = account(203);
    raw.mint(owner, 1);
    context(address, 201, 42000, 1700000000);
    nft.approve(operator, 1);
    raw.set_balance(receiver, P - 1);
    context(address, 203, 42000, 1700000000);
    expect_error(safe.transfer_from(owner, receiver, 1), 'ERC721: balance overflow');
    assert_eq!(nft.owner_of(1), owner);
    assert_eq!(nft.get_approved(1), operator);
    assert_eq!(nft.balance_of(owner), 1);
    assert_eq!(nft.balance_of(receiver), P - 1);
    raw.set_balance(receiver, 0);
    nft.transfer_from(owner, receiver, 1);
    assert_eq!(nft.owner_of(1), receiver);
    assert_eq!(nft.get_approved(1), account(0));
    assert_eq!(nft.balance_of(owner), 0);
    assert_eq!(nft.balance_of(receiver), 1);
    raw.burn(1);
    assert_eq!(nft.balance_of(receiver), 0);
    raw.mint(receiver, 1);
    assert_eq!(nft.balance_of(receiver), 1);
}

#[test]
#[feature("safe_dispatcher")]
fn research_balance_zero_decrement_burn_rejects_and_restores_approval() {
    let address = deploy();
    let raw = IResearchBalanceDispatcher { contract_address: address };
    let safe = IResearchBalanceSafeDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    let owner = account(201);
    let operator = account(203);
    raw.mint(owner, 1);
    context(address, 201, 42000, 1700000000);
    nft.approve(operator, 1);
    raw.set_balance(owner, 0);
    expect_error(safe.burn(1), 'u256_sub Overflow');
    assert_eq!(nft.owner_of(1), owner);
    assert_eq!(nft.get_approved(1), operator);
    assert_eq!(nft.balance_of(owner), 0);
}

#[test]
#[feature("safe_dispatcher")]
fn research_balance_zero_decrement_transfer_rejects_and_restores_approval() {
    let address = deploy();
    let raw = IResearchBalanceDispatcher { contract_address: address };
    let safe = IERC721SafeDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    let owner = account(201);
    let operator = account(203);
    raw.mint(owner, 1);
    context(address, 201, 42000, 1700000000);
    nft.approve(operator, 1);
    raw.set_balance(owner, 0);
    context(address, 203, 42000, 1700000000);
    expect_error(safe.transfer_from(owner, account(202), 1), 'u256_sub Overflow');
    assert_eq!(nft.owner_of(1), owner);
    assert_eq!(nft.get_approved(1), operator);
    assert_eq!(nft.balance_of(owner), 0);
    assert_eq!(nft.balance_of(account(202)), 0);
}

#[test]
#[feature("safe_dispatcher")]
fn research_balance_maximum_self_transfer_preserves_balance_and_authorization() {
    let address = deploy();
    let raw = IResearchBalanceDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    let safe = IERC721SafeDispatcher { contract_address: address };
    let owner = account(201);
    let operator = account(203);
    raw.mint(owner, 0);
    raw.set_balance(owner, P - 1);
    context(address, 203, 42000, 1700000000);
    expect_error(safe.transfer_from(owner, owner, 0), 'ERC721: unauthorized caller');
    context(address, 201, 42000, 1700000000);
    nft.approve(operator, 0);
    context(address, 203, 42000, 1700000000);
    nft.transfer_from(owner, owner, 0);
    assert_eq!(nft.balance_of(owner), P - 1);
    assert_eq!(nft.owner_of(0), owner);
    assert_eq!(nft.get_approved(0), account(0));
    context(address, 201, 42000, 1700000000);
    nft.set_approval_for_all(operator, true);
    context(address, 203, 42000, 1700000000);
    nft.transfer_from(owner, account(202), 0);
    assert_eq!(nft.balance_of(owner), P - 2);
    assert_eq!(nft.balance_of(account(202)), 1);
}

#[test]
#[feature("safe_dispatcher")]
fn research_balance_increase_boundaries() {
    let address = deploy();
    let raw = IResearchBalanceDispatcher { contract_address: address };
    let safe = IResearchBalanceSafeDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    let owner = account(201);
    let cases: Array<(u256, u128)> = array![
        (0, 0), (0, 1), (P - 1, 0), (P - 1, 1), (P - 1, 2),
        (P - Into::<u128, u256>::into(UMAX) - 1, UMAX), (P - Into::<u128, u256>::into(UMAX), UMAX),
        (0x100000000000000000000000000000007, 9),
    ];
    for (current, amount) in cases {
        raw.set_balance(owner, current);
        let expected = current + amount.into();
        let result = safe.increase(owner, amount);
        if expected >= P {
            expect_error(result, 'ERC721: balance overflow');
            assert_eq!(nft.balance_of(owner), current);
        } else {
            result.unwrap();
            assert_eq!(nft.balance_of(owner), expected);
        }
    }
    expect_error(safe.set_balance(owner, P), 'RESEARCH_BALANCE_RANGE');
    assert_eq!(nft.balance_of(owner), 0x100000000000000000000000000000010);
}

#[test]
#[fuzzer]
#[feature("safe_dispatcher")]
fn research_balance_increase_matches_u256_oracle(current: felt252, amount: u128) {
    let address = deploy();
    let raw = IResearchBalanceDispatcher { contract_address: address };
    let safe = IResearchBalanceSafeDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    let owner = account(201);
    let initial: u256 = current.into();
    raw.set_balance(owner, initial);
    let expected = initial + amount.into();
    let result = safe.increase(owner, amount);
    if expected >= P {
        expect_error(result, 'ERC721: balance overflow');
        assert_eq!(nft.balance_of(owner), initial);
    } else {
        result.unwrap();
        assert_eq!(nft.balance_of(owner), expected);
    }
    // Force a prime-boundary crossing in every nonzero-amount fuzz run.
    if amount != 0 {
        let edge = P - Into::<u128, u256>::into(amount);
        raw.set_balance(owner, edge);
        expect_error(safe.increase(owner, amount), 'ERC721: balance overflow');
        assert_eq!(nft.balance_of(owner), edge);
        raw.set_balance(owner, edge - 1);
        raw.increase(owner, amount);
        assert_eq!(nft.balance_of(owner), P - 1);
    }
}

#[starknet::interface]
pub trait IResearchConsecutive<T> {
    fn burn(ref self: T, id: u256);
    fn mint_consecutive(ref self: T, to: ContractAddress, amount: u64) -> u64;
}
#[starknet::contract]
pub mod ResearchConsecutiveBalanceHost {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::erc721::ERC721Component;
    use crate::erc721::extensions::erc721_consecutive::{DefaultConfig, ERC721ConsecutiveComponent};
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721ConsecutiveComponent, storage: consecutive, event: ConsecutiveEvent);
    impl Owner = ERC721Component::ConsecutiveERC721TokenOwnerImpl<ContractState>;
    impl Config = DefaultConfig;
    impl Internal = ERC721Component::InternalImpl<ContractState>;
    impl ConsecutiveInternal = ERC721ConsecutiveComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl NFT = ERC721Component::ERC721Impl<ContractState>;
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        consecutive: ERC721ConsecutiveComponent::Storage,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ConsecutiveEvent: ERC721ConsecutiveComponent::Event,
    }
    impl Hooks of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract = self.get_contract_mut();
            contract.consecutive.before_update(to, token_id, auth);
        }
        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract = self.get_contract_mut();
            contract.consecutive.after_update(to, token_id, auth);
        }
    }
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.consecutive.mint_consecutive(owner, 3);
    }
    #[abi(embed_v0)]
    impl Controls of super::IResearchConsecutive<ContractState> {
        fn burn(ref self: ContractState, id: u256) {
            self.erc721.burn(id);
        }
        fn mint_consecutive(ref self: ContractState, to: ContractAddress, amount: u64) -> u64 {
            self.consecutive.mint_consecutive(to, amount)
        }
    }
}
#[test]
#[feature("safe_dispatcher")]
fn research_balance_consecutive_owner_uses_checked_increase_and_tracks_transfer_burn() {
    let owner = account(201);
    let recipient = account(202);
    let operator = account(203);
    let (address, _) = declare("ResearchConsecutiveBalanceHost")
        .unwrap()
        .contract_class()
        .deploy(@array![owner.into()])
        .unwrap();
    let nft = IERC721Dispatcher { contract_address: address };
    let safe = IERC721SafeDispatcher { contract_address: address };
    assert_eq!(nft.balance_of(owner), 3);
    for id in 0_u32..3 {
        assert_eq!(nft.owner_of(id.into()), owner);
    }
    context(address, 201, 42000, 1700000000);
    nft.approve(operator, 1);
    context(address, 203, 42000, 1700000000);
    nft.transfer_from(owner, recipient, 1);
    assert_eq!(nft.owner_of(1), recipient);
    assert_eq!(nft.balance_of(owner), 2);
    assert_eq!(nft.balance_of(recipient), 1);
    IResearchConsecutiveDispatcher { contract_address: address }.burn(0);
    assert_eq!(nft.balance_of(owner), 1);
    expect_error(safe.owner_of(0), 'ERC721: invalid token ID');
    assert_eq!(nft.owner_of(2), owner);
}

#[test]
fn felt_mint_entrypoint_covers_entire_representable_domain() {
    let address = deploy();
    let raw = IResearchBalanceDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    let owner = account(201);
    for id in array![
        0_felt252, 1, 0x100000000000000000000000000000000,
        0x800000000000000000000000000000000000000000000000000000000000000,
        0x800000000000011000000000000000000000000000000000000000000000000,
    ] {
        raw.mint_felt(owner, id);
        assert_eq!(nft.owner_of(id.into()), owner);
    }
    assert_eq!(nft.balance_of(owner), 5);
}
