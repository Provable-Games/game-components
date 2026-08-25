// =============================================================================
// TEST: MetagameComponent
// =============================================================================
//
// The mint tests here ran through a legacy token mock; that generation is
// retired and the equivalent coverage now lives in `test_libs`, against the
// real merged game+token contract. What remains is the fee path, which is
// component-level rather than lib-level: it resolves terms, computes the
// amount and moves ERC20 value.

use game_components_testing::constants::{ALICE, OWNER};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;

// =============================================================================
// FEE TRANSFER
// =============================================================================

#[starknet::interface]
pub trait IMockFeePayer<TContractState> {
    fn pay_game_fee(
        ref self: TContractState,
        game_address: ContractAddress,
        payment_token: ContractAddress,
        revenue: u128,
    ) -> u128;
}

#[starknet::contract]
pub mod MockFeePayer {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::metagame::metagame_component::MetagameComponent;

    component!(path: MetagameComponent, storage: metagame, event: MetagameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    impl MetagameInternalImpl = MetagameComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        metagame: MetagameComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MetagameEvent: MetagameComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[abi(embed_v0)]
    impl MockFeePayerImpl of super::IMockFeePayer<ContractState> {
        fn pay_game_fee(
            ref self: ContractState,
            game_address: ContractAddress,
            payment_token: ContractAddress,
            revenue: u128,
        ) -> u128 {
            self.metagame.pay_game_fee(game_address, payment_token, revenue)
        }
    }
}

/// Deploys a standard game (game-fee surface, default 500 bps fee) plus the
/// fee-paying metagame.
fn deploy_fee_fixture() -> (ContractAddress, ContractAddress) {
    let game = declare("StandardGameMock").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "StandardToken";
    let symbol: ByteArray = "STD";
    let base_uri: ByteArray = "https://token.test/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    ALICE().serialize(ref calldata); // game fee recipient = payee
    OWNER().serialize(ref calldata);
    let (game_address, _) = game.deploy(@calldata).unwrap();

    let payer = declare("MockFeePayer").unwrap().contract_class();
    let (payer_address, _) = payer.deploy(@array![]).unwrap();
    (game_address, payer_address)
}

/// An ERC20 that returns false rather than reverting must not be reported as
/// a paid fee.
#[test]
#[should_panic(expected: "Metagame: game fee transfer failed")]
fn test_pay_game_fee_rejects_false_returning_erc20() {
    let (game_address, payer_address) = deploy_fee_fixture();
    let payment_token: ContractAddress = 0xE20.try_into().unwrap();
    mock_call(payment_token, selector!("transfer"), false, 1);

    IMockFeePayerDispatcher { contract_address: payer_address }
        .pay_game_fee(game_address, payment_token, 1_000_000);
}

/// The happy path still returns the computed fee.
#[test]
fn test_pay_game_fee_returns_amount_on_success() {
    let (game_address, payer_address) = deploy_fee_fixture();
    let payment_token: ContractAddress = 0xE20.try_into().unwrap();
    mock_call(payment_token, selector!("transfer"), true, 1);

    let paid = IMockFeePayerDispatcher { contract_address: payer_address }
        .pay_game_fee(game_address, payment_token, 1_000_000);
    // DEFAULT_GAME_FEE_BPS = 500 => 5% of 1_000_000
    assert!(paid == 50_000, "fee should be 5% of revenue, got {}", paid);
}

/// Zero revenue short-circuits before any transfer.
#[test]
fn test_pay_game_fee_zero_revenue_pays_nothing() {
    let (game_address, payer_address) = deploy_fee_fixture();
    let payment_token: ContractAddress = 0xE20.try_into().unwrap();

    let paid = IMockFeePayerDispatcher { contract_address: payer_address }
        .pay_game_fee(game_address, payment_token, 0);
    assert!(paid == 0, "zero revenue should pay no fee");
}
