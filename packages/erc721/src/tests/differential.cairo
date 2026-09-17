use openzeppelin_interfaces::erc721::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721SafeDispatcher, IERC721SafeDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyTrait, EventsFilterTrait, declare, spy_events,
};
use starknet::ContractAddress;
use super::balance_support::{IResearchBalanceDispatcher, IResearchBalanceDispatcherTrait};
use super::safety_helpers::context;

#[test]
#[fuzzer]
#[feature("safe_dispatcher")]
fn shared_domain_state_events_and_errors_match_pristine_oz(id: felt252, seed: u8) {
    let (felt, _) = declare("ResearchBalanceHost")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();
    let (wide, _) = declare("PristineBalanceHost")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();
    let owner: ContractAddress = 201.try_into().unwrap();
    let next: ContractAddress = 202.try_into().unwrap();
    let operator: ContractAddress = 203.try_into().unwrap();
    let mut spy = spy_events();
    for target in array![felt, wide] {
        let raw = IResearchBalanceDispatcher { contract_address: target };
        let nft = IERC721Dispatcher { contract_address: target };
        raw.mint(owner, id.into());
        context(target, 201, 0, 0);
        nft.approve(operator, id.into());
        context(target, 203, 0, 0);
        nft.transfer_from(owner, next, id.into());
        context(target, 202, 0, 0);
        nft.set_approval_for_all(operator, true);
        context(target, 203, 0, 0);
        nft.transfer_from(next, next, id.into());
        raw.increase(next, seed.into());
        raw.burn(id.into());
        raw.mint(owner, id.into());
    }
    let a = IERC721Dispatcher { contract_address: felt };
    let b = IERC721Dispatcher { contract_address: wide };
    assert_eq!(a.owner_of(id.into()), b.owner_of(id.into()));
    assert_eq!(a.get_approved(id.into()), b.get_approved(id.into()));
    for who in array![owner, next, operator] {
        assert_eq!(a.balance_of(who), b.balance_of(who));
        assert_eq!(a.is_approved_for_all(who, operator), b.is_approved_for_all(who, operator));
    }
    context(felt, 204, 0, 0);
    context(wide, 204, 0, 0);
    assert_eq!(
        IERC721SafeDispatcher { contract_address: felt }.transfer_from(owner, next, id.into()),
        IERC721SafeDispatcher { contract_address: wide }.transfer_from(owner, next, id.into()),
    );
    let events = spy.get_events();
    let left = events.emitted_by(felt);
    let right = events.emitted_by(wide);
    assert_eq!(left.events.len(), right.events.len());
    for i in 0..left.events.len() {
        assert_eq!(@left.events.at(i).1, @right.events.at(i).1);
    };
}
