use openzeppelin_interfaces::erc721::{
    IERC721CamelOnlySafeDispatcher, IERC721CamelOnlySafeDispatcherTrait, IERC721Dispatcher,
    IERC721DispatcherTrait, IERC721SafeDispatcher, IERC721SafeDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use super::balance_support::{
    IResearchBalanceDispatcher, IResearchBalanceDispatcherTrait, IResearchBalanceSafeDispatcher,
    IResearchBalanceSafeDispatcherTrait,
};
use super::safety_helpers::{context, expect_error};
#[feature("safe_dispatcher")]
pub fn nonreceiver_case(mode: u8) {
    let (address, _) = declare("ResearchBalanceHost")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();
    let (recipient, _) = declare("NonImplementingMock")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();
    let owner: ContractAddress = 201.try_into().unwrap();
    let operator: ContractAddress = 202.try_into().unwrap();
    let raw = IResearchBalanceDispatcher { contract_address: address };
    let nft = IERC721Dispatcher { contract_address: address };
    context(address, 201, 0, 0);
    if mode != 2 {
        raw.mint(owner, 1);
        nft.approve(operator, 1);
    }
    let result = if mode == 0 {
        IERC721SafeDispatcher { contract_address: address }
            .safe_transfer_from(owner, recipient, 1, array![].span())
    } else if mode == 1 {
        IERC721CamelOnlySafeDispatcher { contract_address: address }
            .safeTransferFrom(owner, recipient, 1, array![].span())
    } else {
        IResearchBalanceSafeDispatcher { contract_address: address }.safe_mint(recipient, 1)
    };
    let error = result.unwrap_err();
    assert_eq!(error, array!['ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED']);
    assert_eq!(nft.balance_of(recipient), 0);
    if mode != 2 {
        assert_eq!(nft.owner_of(1), owner);
        assert_eq!(nft.get_approved(1), operator);
        assert_eq!(nft.balance_of(owner), 1);
    } else {
        expect_error(
            IERC721SafeDispatcher { contract_address: address }.owner_of(1),
            'ERC721: invalid token ID',
        );
    }
}
