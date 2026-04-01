use EnumerableComponent::{EnumerableImpl, InternalImpl};
use game_components_embeddable_game_standard::token::extensions::enumerable::enumerable::EnumerableComponent;
use game_components_embeddable_game_standard::token::extensions::enumerable::interface::IERC721_ENUMERABLE_ID;
use game_components_test_common::mocks::mock_enumerable::EnumerableMock;
use openzeppelin_interfaces::introspection::ISRC5_ID;
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_token::erc721::ERC721Component::{ERC721Impl, InternalImpl as ERC721InternalImpl};
use starknet::ContractAddress;
use starknet::storage::StorageMapReadAccess;

// Constants
const TOKEN_1: u256 = 'TOKEN_1';
const TOKEN_2: u256 = 'TOKEN_2';
const TOKEN_3: u256 = 'TOKEN_3';

fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn RECIPIENT() -> ContractAddress {
    'RECIPIENT'.try_into().unwrap()
}

fn OTHER() -> ContractAddress {
    'OTHER'.try_into().unwrap()
}

fn ZERO() -> ContractAddress {
    0.try_into().unwrap()
}

// Setup

type ComponentState = EnumerableComponent::ComponentState<EnumerableMock::ContractState>;

fn CONTRACT_STATE() -> EnumerableMock::ContractState {
    EnumerableMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    EnumerableComponent::component_state_for_testing()
}

fn setup() -> (ComponentState, Span<u256>) {
    let mut state = COMPONENT_STATE();
    let mut mock_state = CONTRACT_STATE();
    state.initializer();

    let tokens_list = array![TOKEN_1, TOKEN_2, TOKEN_3].span();
    for token in tokens_list {
        mock_state.erc721.mint(OWNER(), *token);
    }

    (state, tokens_list)
}

// ================================================================================================
// Initializer
// ================================================================================================

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer();

    assert!(mock_state.supports_interface(IERC721_ENUMERABLE_ID));
    assert!(mock_state.supports_interface(ISRC5_ID));
}

// ================================================================================================
// total_supply
// ================================================================================================

#[test]
fn test_total_supply() {
    let mut state = COMPONENT_STATE();
    let mut contract_state = CONTRACT_STATE();

    assert!(state.total_supply() == 0, "initial supply should be 0");

    contract_state.erc721.mint(OWNER(), TOKEN_1);
    assert!(state.total_supply() == 1, "supply should be 1 after mint");

    contract_state.erc721.mint(OWNER(), TOKEN_2);
    assert!(state.total_supply() == 2, "supply should be 2 after second mint");
}

// ================================================================================================
// token_by_index
// ================================================================================================

#[test]
fn test_token_by_index() {
    let (_, token_list) = setup();
    assert_token_by_index(token_list);
}

#[test]
#[should_panic(expected: 'ERC721Enum: out of bounds index')]
fn test_token_by_index_equal_to_supply() {
    let (state, token_list) = setup();
    let supply: u256 = token_list.len().into();
    state.token_by_index(supply);
}

#[test]
#[should_panic(expected: 'ERC721Enum: out of bounds index')]
fn test_token_by_index_greater_than_supply() {
    let (state, token_list) = setup();
    let supply_plus_one: u256 = token_list.len().into() + 1;
    state.token_by_index(supply_plus_one);
}


// ================================================================================================
// token_of_owner_by_index
// ================================================================================================

#[test]
fn test_token_of_owner_by_index() {
    let (_, tokens_list) = setup();
    assert_token_of_owner_by_index(OWNER(), tokens_list);
}

#[test]
#[should_panic(expected: 'ERC721Enum: out of bounds index')]
fn test_token_of_owner_by_index_when_index_equals_owned_tokens() {
    let (state, tokens_list) = setup();
    let owned_token_len: u256 = tokens_list.len().into();
    state.token_of_owner_by_index(OWNER(), owned_token_len);
}

#[test]
#[should_panic(expected: 'ERC721Enum: out of bounds index')]
fn test_token_of_owner_by_index_when_index_exceeds_owned_tokens() {
    let (state, tokens_list) = setup();
    let owned_tokens_len_plus_one: u256 = tokens_list.len().into() + 1;
    state.token_of_owner_by_index(OWNER(), owned_tokens_len_plus_one);
}

#[test]
#[should_panic(expected: 'ERC721Enum: out of bounds index')]
fn test_token_of_owner_by_index_when_target_has_no_tokens() {
    let (state, _) = setup();
    state.token_of_owner_by_index(OTHER(), 0);
}

#[test]
#[should_panic(expected: 'ERC721: invalid account')]
fn test_token_of_owner_by_index_when_owner_is_zero() {
    let (state, _) = setup();
    state.token_of_owner_by_index(ZERO(), 0);
}

#[test]
fn test_token_of_owner_by_index_remove_last_token() {
    let _ = setup();
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc721.transfer(OWNER(), RECIPIENT(), TOKEN_3);

    assert_token_of_owner_by_index(OWNER(), array![TOKEN_1, TOKEN_2].span());
}

#[test]
fn test_token_of_owner_by_index_remove_first_token() {
    let _ = setup();
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc721.transfer(OWNER(), RECIPIENT(), TOKEN_1);

    // Removed tokens are replaced by the last token (swap-and-pop)
    assert_token_of_owner_by_index(OWNER(), array![TOKEN_3, TOKEN_2].span());
}

#[test]
fn test_token_of_owner_by_index_when_all_tokens_transferred() {
    let (_, tokens_list) = setup();
    let mut contract_state = CONTRACT_STATE();

    contract_state.erc721.transfer(OWNER(), RECIPIENT(), TOKEN_1);
    contract_state.erc721.transfer(OWNER(), RECIPIENT(), TOKEN_2);
    contract_state.erc721.transfer(OWNER(), RECIPIENT(), TOKEN_3);

    assert_token_of_owner_by_index(RECIPIENT(), tokens_list);
}

// ================================================================================================
// before_update
// ================================================================================================

#[test]
#[should_panic(expected: 'ERC721Enum: burn not supported')]
fn test_before_update_burn_panics() {
    let (mut state, _) = setup();
    state.before_update(ZERO(), TOKEN_1);
}

#[test]
#[should_panic(expected: 'ERC721Enum: burn not supported')]
fn test_before_update_mint_to_zero_panics() {
    let (mut state, _) = setup();
    let unminted_token = 'UNMINTED';
    state.before_update(ZERO(), unminted_token);
}

#[test]
fn test_before_update_when_mint() {
    let (mut state, _) = setup();
    let new_token = 'TOKEN_4';

    state.before_update(OWNER(), new_token);

    assert!(state.total_supply() == 4, "supply should be 4");
    assert_owned_tokens_list_after_update(
        OWNER(), array![TOKEN_1, TOKEN_2, TOKEN_3, new_token].span(),
    );
    assert_token_by_index(array![TOKEN_1, TOKEN_2, TOKEN_3, new_token].span());
}

#[test]
fn test_before_update_when_transfer_last_token() {
    let (mut state, _) = setup();

    state.before_update(RECIPIENT(), TOKEN_3);

    assert!(state.total_supply() == 3, "supply should stay 3");
    assert_owned_tokens_list_after_update(OWNER(), array![TOKEN_1, TOKEN_2].span());
    assert_owned_tokens_list_after_update(RECIPIENT(), array![TOKEN_3].span());
    assert_token_by_index(array![TOKEN_1, TOKEN_2, TOKEN_3].span());
}

#[test]
fn test_before_update_when_transfer_first_token() {
    let (mut state, _) = setup();

    state.before_update(RECIPIENT(), TOKEN_1);

    assert!(state.total_supply() == 3, "supply should stay 3");
    assert_owned_tokens_list_after_update(OWNER(), array![TOKEN_3, TOKEN_2].span());
    assert_owned_tokens_list_after_update(RECIPIENT(), array![TOKEN_1].span());
    assert_token_by_index(array![TOKEN_1, TOKEN_2, TOKEN_3].span());
}

// ================================================================================================
// _add_token_to_owner_enumeration
// ================================================================================================

#[test]
fn test__add_token_to_owner_enumeration() {
    let (mut state, tokens_list) = setup();
    let new_token_id: felt252 = 'TOKEN_4';
    let new_token_index: felt252 = tokens_list.len().into();

    assert_owner_tokens_index_to_id(OWNER(), new_token_index, 0);
    assert_owner_tokens_id_to_index(new_token_id, 0);

    state._add_token_to_owner_enumeration(OWNER(), new_token_id);

    assert_owner_tokens_index_to_id(OWNER(), new_token_index, new_token_id);
    assert_owner_tokens_id_to_index(new_token_id, new_token_index);
}

// ================================================================================================
// _add_token_to_all_tokens_enumeration
// ================================================================================================

#[test]
fn test__add_token_to_all_tokens_enumeration() {
    let (mut state, _) = setup();
    let new_token_id: felt252 = 'TOKEN_4';
    let initial_supply_felt: felt252 = state.total_supply().try_into().unwrap();

    assert_all_tokens_index_to_id(initial_supply_felt, 0);

    state._add_token_to_all_tokens_enumeration(new_token_id);

    assert_all_tokens_index_to_id(initial_supply_felt, new_token_id);
    assert!(state.total_supply() == 4, "supply should be 4");
}

// ================================================================================================
// _remove_token_from_owner_enumeration
// ================================================================================================

#[test]
fn test__remove_token_from_owner_enumeration_with_last_token() {
    let (mut state, _) = setup();
    let last_token_index: felt252 = (state.total_supply() - 1).try_into().unwrap();
    let last_token_id: felt252 = TOKEN_3.try_into().unwrap();

    assert_owner_tokens_index_to_id(OWNER(), last_token_index, last_token_id);
    assert_owner_tokens_id_to_index(last_token_id, last_token_index);

    state._remove_token_from_owner_enumeration(OWNER(), last_token_id);

    assert_owner_tokens_index_to_id(OWNER(), last_token_index, 0);
    assert_owner_tokens_id_to_index(last_token_id, 0);
}

#[test]
fn test__remove_token_from_owner_enumeration_with_first_token() {
    let (mut state, _) = setup();
    let first_token_id: felt252 = TOKEN_1.try_into().unwrap();
    let last_token_id: felt252 = TOKEN_3.try_into().unwrap();

    assert_owner_tokens_index_to_id(OWNER(), 0, first_token_id);
    assert_owner_tokens_id_to_index(first_token_id, 0);

    state._remove_token_from_owner_enumeration(OWNER(), first_token_id);

    // Note: the original last token id is now first because of swap-and-pop
    assert_owner_tokens_index_to_id(OWNER(), 0, last_token_id);
    assert_owner_tokens_id_to_index(first_token_id, 0);
}

// ================================================================================================
// all_tokens_of_owner
// ================================================================================================

#[test]
fn test_all_tokens_of_owner() {
    let (_, tokens_list) = setup();
    assert_all_tokens_of_owner(OWNER(), tokens_list);
}

#[test]
fn test_all_tokens_of_owner_after_transfer_first_token() {
    let _ = setup();
    let mut contract_state = CONTRACT_STATE();

    contract_state.erc721.transfer(OWNER(), RECIPIENT(), TOKEN_1);

    assert_all_tokens_of_owner(OWNER(), array![TOKEN_3, TOKEN_2].span());
    assert_all_tokens_of_owner(RECIPIENT(), array![TOKEN_1].span());
}

#[test]
fn test_all_tokens_of_owner_after_transfer_last_token() {
    let _ = setup();
    let mut contract_state = CONTRACT_STATE();

    contract_state.erc721.transfer(OWNER(), RECIPIENT(), TOKEN_3);

    assert_all_tokens_of_owner(OWNER(), array![TOKEN_1, TOKEN_2].span());
    assert_all_tokens_of_owner(RECIPIENT(), array![TOKEN_3].span());
}

// ================================================================================================
// Helpers
// ================================================================================================

fn assert_token_of_owner_by_index(owner: ContractAddress, expected_token_list: Span<u256>) {
    let state = @COMPONENT_STATE();
    let contract_state = @CONTRACT_STATE();

    let owner_bal: u256 = contract_state.balance_of(owner);
    let expected_list_len: u256 = expected_token_list.len().into();
    assert!(owner_bal == expected_list_len, "balance mismatch");

    let mut i: u32 = 0;
    while i != expected_token_list.len() {
        let index: u256 = i.into();
        let token = state.token_of_owner_by_index(owner, index);
        assert!(token == *expected_token_list.at(i), "token_of_owner_by_index mismatch");
        i += 1;
    }
}

fn assert_token_by_index(expected_token_list: Span<u256>) {
    let state = @COMPONENT_STATE();

    let total_supply: u256 = state.total_supply();
    let expected_list_len: u256 = expected_token_list.len().into();
    assert!(total_supply == expected_list_len, "total_supply mismatch");

    let mut i: u32 = 0;
    while i != expected_token_list.len() {
        let index: u256 = i.into();
        let token = state.token_by_index(index);
        assert!(token == *expected_token_list.at(i), "token_by_index mismatch");
        i += 1;
    }
}

/// Reads from storage directly, bypassing the out of bounds check.
/// The `before_update` function does not update the ERC721 state.
fn assert_owned_tokens_list_after_update(owner: ContractAddress, expected_list: Span<u256>) {
    let state = @COMPONENT_STATE();

    let mut i: u32 = 0;
    while i != expected_list.len() {
        let index_felt: felt252 = i.into();
        let token: felt252 = state.Enumerable_owned_tokens.read((owner, index_felt));
        let token_u256: u256 = token.into();
        assert!(token_u256 == *expected_list.at(i), "owned_tokens mismatch");
        i += 1;
    }
}

fn assert_all_tokens_index_to_id(index: felt252, exp_token_id: felt252) {
    let state = @COMPONENT_STATE();
    let index_to_id = state.Enumerable_all_tokens.read(index);
    assert!(index_to_id == exp_token_id, "all_tokens index->id mismatch");
}

fn assert_owner_tokens_index_to_id(owner: ContractAddress, index: felt252, exp_token_id: felt252) {
    let state = @COMPONENT_STATE();
    let index_to_id = state.Enumerable_owned_tokens.read((owner, index));
    assert!(index_to_id == exp_token_id, "owned_tokens index->id mismatch");
}

fn assert_owner_tokens_id_to_index(token_id: felt252, exp_index: felt252) {
    let state = @COMPONENT_STATE();
    let id_to_index = state.Enumerable_owned_tokens_index.read(token_id);
    assert!(id_to_index == exp_index, "owned_tokens id->index mismatch");
}

fn assert_all_tokens_of_owner(owner: ContractAddress, exp_tokens: Span<u256>) {
    let state = @COMPONENT_STATE();
    let tokens = state.all_tokens_of_owner(owner);
    assert!(tokens == exp_tokens, "all_tokens_of_owner mismatch");
}
