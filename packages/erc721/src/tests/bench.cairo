use starknet::ContractAddress;
#[starknet::interface]
pub trait IBenchTarget<T> {
    fn execute(ref self: T, op: u8, count: u32, to: ContractAddress, id: u256) -> u256;
}
#[starknet::contract]
pub mod FeltBenchTarget {
    use openzeppelin_interfaces::erc721::IERC721;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::StorageMapWriteAccess;
    use crate::erc721::{ERC721Component, ERC721HooksEmptyImpl, ERC721OwnerOfDefaultImpl};
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    impl Owner = ERC721OwnerOfDefaultImpl<ContractState>;
    impl Hooks = ERC721HooksEmptyImpl<ContractState>;
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
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }
    #[abi(embed_v0)]
    impl Controls of super::super::balance_support::IResearchBalance<ContractState> {
        // Research only: seed extreme/inconsistent balances without creating P tokens.
        fn set_balance(ref self: ContractState, owner: ContractAddress, balance: u256) {
            let Some(value) = balance.try_into() else {
                core::panic_with_felt252('RESEARCH_BALANCE_RANGE');
            };
            self.erc721.ERC721_balances.write(owner, value);
        }
        fn increase(ref self: ContractState, owner: ContractAddress, amount: u128) {
            self.erc721.increase_balance(owner, amount);
        }
        fn mint_felt(ref self: ContractState, to: ContractAddress, id: felt252) {
            self.erc721.mint_felt(to, id);
        }
        fn mint(ref self: ContractState, to: ContractAddress, id: u256) {
            self.erc721.mint(to, id);
        }
        fn mint_pair(ref self: ContractState, to: ContractAddress, first: u256, second: u256) {
            self.erc721.mint(to, first);
            self.erc721.mint(to, second);
        }
        fn safe_mint(ref self: ContractState, to: ContractAddress, id: u256) {
            self.erc721.safe_mint(to, id, array![].span());
        }
        fn burn(ref self: ContractState, id: u256) {
            self.erc721.burn(id);
        }
    }

    #[abi(embed_v0)]
    impl Bench of super::IBenchTarget<ContractState> {
        fn execute(
            ref self: ContractState, op: u8, count: u32, to: ContractAddress, id: u256,
        ) -> u256 {
            if op == 0 {
                self.erc721.mint(to, id);
            } else if op == 1 {
                self.erc721.mint_felt(to, id.try_into().unwrap());
            } else if op == 2 || op == 3 {
                for i in 0..count {
                    let recipient = if op == 3 {
                        (201 + i.into()).try_into().unwrap()
                    } else {
                        to
                    };
                    self.erc721.mint_felt(recipient, (id + i.into()).try_into().unwrap());
                };
            } else if op == 4 || op == 5 {
                self.erc721.transfer_from(201.try_into().unwrap(), to, id);
            } else if op == 6 {
                self.erc721.burn(id);
            } else if op == 7 {
                self.erc721.safe_mint(to, id, array![].span());
            } else if op == 8 {
                self.erc721.safe_transfer_from(201.try_into().unwrap(), to, id, array![].span());
            } else if op == 9 {
                return self.erc721.balance_of(to);
            } else if op == 10 {
                let owner: felt252 = self.erc721._owner_of(id).into();
                return owner.into();
            } else if op == 11 {
                self.erc721.approve(to, id);
            } else {
                self.erc721.set_approval_for_all(to, true);
            }
            0
        }
    }
}
#[starknet::contract]
pub mod OZBenchTarget {
    use openzeppelin_interfaces::erc721::IERC721;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{
        ERC721Component, ERC721HooksEmptyImpl, ERC721OwnerOfDefaultImpl,
    };
    use starknet::ContractAddress;
    use starknet::storage::StorageMapWriteAccess;
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    impl Owner = ERC721OwnerOfDefaultImpl<ContractState>;
    impl Hooks = ERC721HooksEmptyImpl<ContractState>;
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
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }
    #[abi(embed_v0)]
    impl Controls of super::super::balance_support::IResearchBalance<ContractState> {
        // Research only: seed extreme/inconsistent balances without creating P tokens.
        fn set_balance(ref self: ContractState, owner: ContractAddress, balance: u256) {
            self.erc721.ERC721_balances.write(owner, balance);
        }
        fn increase(ref self: ContractState, owner: ContractAddress, amount: u128) {
            self.erc721.increase_balance(owner, amount);
        }
        fn mint_felt(ref self: ContractState, to: ContractAddress, id: felt252) {
            self.erc721.mint(to, id.into());
        }
        fn mint(ref self: ContractState, to: ContractAddress, id: u256) {
            self.erc721.mint(to, id);
        }
        fn mint_pair(ref self: ContractState, to: ContractAddress, first: u256, second: u256) {
            self.erc721.mint(to, first);
            self.erc721.mint(to, second);
        }
        fn safe_mint(ref self: ContractState, to: ContractAddress, id: u256) {
            self.erc721.safe_mint(to, id, array![].span());
        }
        fn burn(ref self: ContractState, id: u256) {
            self.erc721.burn(id);
        }
    }

    #[abi(embed_v0)]
    impl Bench of super::IBenchTarget<ContractState> {
        fn execute(
            ref self: ContractState, op: u8, count: u32, to: ContractAddress, id: u256,
        ) -> u256 {
            if op == 0 {
                self.erc721.mint(to, id);
            } else if op == 1 {
                let felt: felt252 = id.try_into().unwrap();
                self.erc721.mint(to, felt.into());
            } else if op == 2 || op == 3 {
                for i in 0..count {
                    let recipient = if op == 3 {
                        (201 + i.into()).try_into().unwrap()
                    } else {
                        to
                    };
                    let felt: felt252 = (id + i.into()).try_into().unwrap();
                    self.erc721.mint(recipient, felt.into());
                };
            } else if op == 4 || op == 5 {
                self.erc721.transfer_from(201.try_into().unwrap(), to, id);
            } else if op == 6 {
                self.erc721.burn(id);
            } else if op == 7 {
                self.erc721.safe_mint(to, id, array![].span());
            } else if op == 8 {
                self.erc721.safe_transfer_from(201.try_into().unwrap(), to, id, array![].span());
            } else if op == 9 {
                return self.erc721.balance_of(to);
            } else if op == 10 {
                let owner: felt252 = self.erc721._owner_of(id).into();
                return owner.into();
            } else if op == 11 {
                self.erc721.approve(to, id);
            } else {
                self.erc721.set_approval_for_all(to, true);
            }
            0
        }
    }
}
#[starknet::contract]
pub mod BenchFloor {
    use starknet::ContractAddress;
    #[storage]
    struct Storage {}
    #[abi(embed_v0)]
    impl Bench of super::IBenchTarget<ContractState> {
        fn execute(
            ref self: ContractState, op: u8, count: u32, to: ContractAddress, id: u256,
        ) -> u256 {
            if op == 9 {
                if count == 1 {
                    0x100000000000000000000000000000000
                } else if count == 2 {
                    3
                } else {
                    1
                }
            } else if op == 10 {
                201
            } else {
                0
            }
        }
    }
}
#[starknet::contract]
pub mod BenchProbe {
    use starknet::ContractAddress;
    use super::{IBenchTargetDispatcher, IBenchTargetDispatcherTrait};
    #[storage]
    struct Storage {}
    #[external(v0)]
    fn felt_first_u256(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(0, 0, to, id)
    }
    #[external(v0)]
    fn oz_first_u256(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(0, 0, to, id)
    }
    #[external(v0)]
    fn floor_first_u256(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(0, 0, to, id)
    }
    #[external(v0)]
    fn felt_repeat_u256(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(0, 0, to, id)
    }
    #[external(v0)]
    fn oz_repeat_u256(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(0, 0, to, id)
    }
    #[external(v0)]
    fn floor_repeat_u256(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(0, 0, to, id)
    }
    #[external(v0)]
    fn felt_first_felt(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(1, 0, to, id)
    }
    #[external(v0)]
    fn oz_first_felt(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(1, 0, to, id)
    }
    #[external(v0)]
    fn floor_first_felt(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(1, 0, to, id)
    }
    #[external(v0)]
    fn felt_repeat_felt(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(1, 0, to, id)
    }
    #[external(v0)]
    fn oz_repeat_felt(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(1, 0, to, id)
    }
    #[external(v0)]
    fn floor_repeat_felt(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(1, 0, to, id)
    }
    #[external(v0)]
    fn felt_batch_repeat_1(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 1, to, id)
    }
    #[external(v0)]
    fn oz_batch_repeat_1(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 1, to, id)
    }
    #[external(v0)]
    fn floor_batch_repeat_1(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 1, to, id)
    }
    #[external(v0)]
    fn felt_batch_distinct_1(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 1, to, id)
    }
    #[external(v0)]
    fn oz_batch_distinct_1(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 1, to, id)
    }
    #[external(v0)]
    fn floor_batch_distinct_1(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 1, to, id)
    }
    #[external(v0)]
    fn felt_batch_repeat_2(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 2, to, id)
    }
    #[external(v0)]
    fn oz_batch_repeat_2(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 2, to, id)
    }
    #[external(v0)]
    fn floor_batch_repeat_2(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 2, to, id)
    }
    #[external(v0)]
    fn felt_batch_distinct_2(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 2, to, id)
    }
    #[external(v0)]
    fn oz_batch_distinct_2(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 2, to, id)
    }
    #[external(v0)]
    fn floor_batch_distinct_2(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 2, to, id)
    }
    #[external(v0)]
    fn felt_batch_repeat_10(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 10, to, id)
    }
    #[external(v0)]
    fn oz_batch_repeat_10(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 10, to, id)
    }
    #[external(v0)]
    fn floor_batch_repeat_10(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 10, to, id)
    }
    #[external(v0)]
    fn felt_batch_distinct_10(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 10, to, id)
    }
    #[external(v0)]
    fn oz_batch_distinct_10(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 10, to, id)
    }
    #[external(v0)]
    fn floor_batch_distinct_10(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 10, to, id)
    }
    #[external(v0)]
    fn felt_batch_repeat_50(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 50, to, id)
    }
    #[external(v0)]
    fn oz_batch_repeat_50(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 50, to, id)
    }
    #[external(v0)]
    fn floor_batch_repeat_50(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 50, to, id)
    }
    #[external(v0)]
    fn felt_batch_distinct_50(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 50, to, id)
    }
    #[external(v0)]
    fn oz_batch_distinct_50(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 50, to, id)
    }
    #[external(v0)]
    fn floor_batch_distinct_50(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 50, to, id)
    }
    #[external(v0)]
    fn felt_batch_repeat_100(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 100, to, id)
    }
    #[external(v0)]
    fn oz_batch_repeat_100(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 100, to, id)
    }
    #[external(v0)]
    fn floor_batch_repeat_100(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(2, 100, to, id)
    }
    #[external(v0)]
    fn felt_batch_distinct_100(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 100, to, id)
    }
    #[external(v0)]
    fn oz_batch_distinct_100(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 100, to, id)
    }
    #[external(v0)]
    fn floor_batch_distinct_100(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(3, 100, to, id)
    }
    #[external(v0)]
    fn felt_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(4, 0, to, id)
    }
    #[external(v0)]
    fn oz_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(4, 0, to, id)
    }
    #[external(v0)]
    fn floor_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(4, 0, to, id)
    }
    #[external(v0)]
    fn felt_self_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(5, 0, to, id)
    }
    #[external(v0)]
    fn oz_self_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(5, 0, to, id)
    }
    #[external(v0)]
    fn floor_self_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(5, 0, to, id)
    }
    #[external(v0)]
    fn felt_burn(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(6, 0, to, id)
    }
    #[external(v0)]
    fn oz_burn(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(6, 0, to, id)
    }
    #[external(v0)]
    fn floor_burn(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(6, 0, to, id)
    }
    #[external(v0)]
    fn felt_safe_mint(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(7, 0, to, id)
    }
    #[external(v0)]
    fn oz_safe_mint(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(7, 0, to, id)
    }
    #[external(v0)]
    fn floor_safe_mint(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(7, 0, to, id)
    }
    #[external(v0)]
    fn felt_safe_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(8, 0, to, id)
    }
    #[external(v0)]
    fn oz_safe_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(8, 0, to, id)
    }
    #[external(v0)]
    fn floor_safe_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(8, 0, to, id)
    }
    #[external(v0)]
    fn felt_balance_low(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(9, 0, to, id)
    }
    #[external(v0)]
    fn oz_balance_low(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(9, 0, to, id)
    }
    #[external(v0)]
    fn floor_balance_low(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(9, 0, to, id)
    }
    #[external(v0)]
    fn felt_balance_high(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(9, 1, to, id)
    }
    #[external(v0)]
    fn oz_balance_high(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(9, 1, to, id)
    }
    #[external(v0)]
    fn floor_balance_high(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(9, 1, to, id)
    }
    #[external(v0)]
    fn felt_owner(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(10, 0, to, id)
    }
    #[external(v0)]
    fn oz_owner(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(10, 0, to, id)
    }
    #[external(v0)]
    fn floor_owner(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(10, 0, to, id)
    }
    #[external(v0)]
    fn felt_approve(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(11, 0, to, id)
    }
    #[external(v0)]
    fn oz_approve(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(11, 0, to, id)
    }
    #[external(v0)]
    fn floor_approve(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(11, 0, to, id)
    }
    #[external(v0)]
    fn felt_operator_approval(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(12, 0, to, id)
    }
    #[external(v0)]
    fn oz_operator_approval(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(12, 0, to, id)
    }
    #[external(v0)]
    fn floor_operator_approval(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(12, 0, to, id)
    }
    #[external(v0)]
    fn felt_consecutive_owner(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(10, 2, to, id)
    }
    #[external(v0)]
    fn oz_consecutive_owner(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(10, 2, to, id)
    }
    #[external(v0)]
    fn floor_consecutive_owner(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(10, 2, to, id)
    }
    #[external(v0)]
    fn felt_consecutive_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(4, 2, to, id)
    }
    #[external(v0)]
    fn oz_consecutive_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(4, 2, to, id)
    }
    #[external(v0)]
    fn floor_consecutive_transfer(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(4, 2, to, id)
    }
    #[external(v0)]
    fn felt_consecutive_balance(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(9, 2, to, id)
    }
    #[external(v0)]
    fn oz_consecutive_balance(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(9, 2, to, id)
    }
    #[external(v0)]
    fn floor_consecutive_balance(
        ref self: ContractState, target: ContractAddress, to: ContractAddress, id: u256,
    ) -> u256 {
        IBenchTargetDispatcher { contract_address: target }.execute(9, 2, to, id)
    }
}
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::SyscallResultTrait;
use super::balance_support::{IResearchBalanceDispatcher, IResearchBalanceDispatcherTrait};
use super::safety_helpers::context;
fn run(
    felt_selector: felt252,
    oz_selector: felt252,
    floor_selector: felt252,
    op: u8,
    count: u32,
    repeat: bool,
) {
    let (felt, _) = declare("FeltBenchTarget").unwrap().contract_class().deploy(@array![]).unwrap();
    let (oz, _) = declare("OZBenchTarget").unwrap().contract_class().deploy(@array![]).unwrap();
    let (floor, _) = declare("BenchFloor").unwrap().contract_class().deploy(@array![]).unwrap();
    let (probe, _) = declare("BenchProbe").unwrap().contract_class().deploy(@array![]).unwrap();
    let (receiver, _) = declare("DualCaseAccountMock")
        .unwrap()
        .contract_class()
        .deploy(@array![1234])
        .unwrap();
    let owner: ContractAddress = 201.try_into().unwrap();
    let to: ContractAddress = if op == 7 || op == 8 {
        receiver
    } else if op == 4 || op == 11 || op == 12 {
        202.try_into().unwrap()
    } else {
        owner
    };
    let id: u256 = 0x100000000000000000000000000000001;
    for target in array![felt, oz] {
        let raw = IResearchBalanceDispatcher { contract_address: target };
        if repeat {
            let previous = if op == 0 || op == 1 {
                id + 1
            } else {
                id
            };
            raw.mint(owner, previous);
        }
        if op == 9 && count == 1 {
            raw.set_balance(owner, 0x100000000000000000000000000000000);
        }
        context(target, 201, 0, 0);
    }
    let a = starknet::syscalls::call_contract_syscall(
        probe, felt_selector, array![felt.into(), to.into(), id.low.into(), id.high.into()].span(),
    )
        .unwrap_syscall();
    let b = starknet::syscalls::call_contract_syscall(
        probe, oz_selector, array![oz.into(), to.into(), id.low.into(), id.high.into()].span(),
    )
        .unwrap_syscall();
    let c = starknet::syscalls::call_contract_syscall(
        probe,
        floor_selector,
        array![floor.into(), to.into(), id.low.into(), id.high.into()].span(),
    )
        .unwrap_syscall();
    assert_eq!(a, b);
    assert_eq!(a, c);
}
#[test]
#[ignore]
fn bench_erc721_first_u256() {
    run(
        selector!("felt_first_u256"),
        selector!("oz_first_u256"),
        selector!("floor_first_u256"),
        0,
        0,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_repeat_u256() {
    run(
        selector!("felt_repeat_u256"),
        selector!("oz_repeat_u256"),
        selector!("floor_repeat_u256"),
        0,
        0,
        true,
    );
}
#[test]
#[ignore]
fn bench_erc721_first_felt() {
    run(
        selector!("felt_first_felt"),
        selector!("oz_first_felt"),
        selector!("floor_first_felt"),
        1,
        0,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_repeat_felt() {
    run(
        selector!("felt_repeat_felt"),
        selector!("oz_repeat_felt"),
        selector!("floor_repeat_felt"),
        1,
        0,
        true,
    );
}
#[test]
#[ignore]
fn bench_erc721_batch_repeat_1() {
    run(
        selector!("felt_batch_repeat_1"),
        selector!("oz_batch_repeat_1"),
        selector!("floor_batch_repeat_1"),
        2,
        1,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_batch_distinct_1() {
    run(
        selector!("felt_batch_distinct_1"),
        selector!("oz_batch_distinct_1"),
        selector!("floor_batch_distinct_1"),
        3,
        1,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_batch_repeat_2() {
    run(
        selector!("felt_batch_repeat_2"),
        selector!("oz_batch_repeat_2"),
        selector!("floor_batch_repeat_2"),
        2,
        2,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_batch_distinct_2() {
    run(
        selector!("felt_batch_distinct_2"),
        selector!("oz_batch_distinct_2"),
        selector!("floor_batch_distinct_2"),
        3,
        2,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_batch_repeat_10() {
    run(
        selector!("felt_batch_repeat_10"),
        selector!("oz_batch_repeat_10"),
        selector!("floor_batch_repeat_10"),
        2,
        10,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_batch_distinct_10() {
    run(
        selector!("felt_batch_distinct_10"),
        selector!("oz_batch_distinct_10"),
        selector!("floor_batch_distinct_10"),
        3,
        10,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_batch_repeat_50() {
    run(
        selector!("felt_batch_repeat_50"),
        selector!("oz_batch_repeat_50"),
        selector!("floor_batch_repeat_50"),
        2,
        50,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_batch_distinct_50() {
    run(
        selector!("felt_batch_distinct_50"),
        selector!("oz_batch_distinct_50"),
        selector!("floor_batch_distinct_50"),
        3,
        50,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_batch_repeat_100() {
    run(
        selector!("felt_batch_repeat_100"),
        selector!("oz_batch_repeat_100"),
        selector!("floor_batch_repeat_100"),
        2,
        100,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_batch_distinct_100() {
    run(
        selector!("felt_batch_distinct_100"),
        selector!("oz_batch_distinct_100"),
        selector!("floor_batch_distinct_100"),
        3,
        100,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_transfer() {
    run(
        selector!("felt_transfer"),
        selector!("oz_transfer"),
        selector!("floor_transfer"),
        4,
        0,
        true,
    );
}
#[test]
#[ignore]
fn bench_erc721_self_transfer() {
    run(
        selector!("felt_self_transfer"),
        selector!("oz_self_transfer"),
        selector!("floor_self_transfer"),
        5,
        0,
        true,
    );
}
#[test]
#[ignore]
fn bench_erc721_burn() {
    run(selector!("felt_burn"), selector!("oz_burn"), selector!("floor_burn"), 6, 0, true);
}
#[test]
#[ignore]
fn bench_erc721_safe_mint() {
    run(
        selector!("felt_safe_mint"),
        selector!("oz_safe_mint"),
        selector!("floor_safe_mint"),
        7,
        0,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_safe_transfer() {
    run(
        selector!("felt_safe_transfer"),
        selector!("oz_safe_transfer"),
        selector!("floor_safe_transfer"),
        8,
        0,
        true,
    );
}
#[test]
#[ignore]
fn bench_erc721_balance_low() {
    run(
        selector!("felt_balance_low"),
        selector!("oz_balance_low"),
        selector!("floor_balance_low"),
        9,
        0,
        true,
    );
}
#[test]
#[ignore]
fn bench_erc721_balance_high() {
    run(
        selector!("felt_balance_high"),
        selector!("oz_balance_high"),
        selector!("floor_balance_high"),
        9,
        1,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_owner() {
    run(selector!("felt_owner"), selector!("oz_owner"), selector!("floor_owner"), 10, 0, true);
}
#[test]
#[ignore]
fn bench_erc721_approve() {
    run(
        selector!("felt_approve"), selector!("oz_approve"), selector!("floor_approve"), 11, 0, true,
    );
}
#[test]
#[ignore]
fn bench_erc721_operator_approval() {
    run(
        selector!("felt_operator_approval"),
        selector!("oz_operator_approval"),
        selector!("floor_operator_approval"),
        12,
        0,
        false,
    );
}
#[starknet::contract]
pub mod FeltConsecutiveBenchTarget {
    use openzeppelin_interfaces::erc721::IERC721;
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
    impl Controls of super::super::balance_boundaries::IResearchConsecutive<ContractState> {
        fn burn(ref self: ContractState, id: u256) {
            self.erc721.burn(id);
        }
        fn mint_consecutive(ref self: ContractState, to: ContractAddress, amount: u64) -> u64 {
            self.consecutive.mint_consecutive(to, amount)
        }
    }

    #[abi(embed_v0)]
    impl Bench of super::IBenchTarget<ContractState> {
        fn execute(
            ref self: ContractState, op: u8, count: u32, to: ContractAddress, id: u256,
        ) -> u256 {
            if op == 10 {
                let owner: felt252 = self.erc721._owner_of(id).into();
                return owner.into();
            }
            if op == 9 {
                return self.erc721.balance_of(to);
            }
            self.erc721.transfer_from(201.try_into().unwrap(), to, id);
            0
        }
    }
}
#[starknet::contract]
pub mod OZConsecutiveBenchTarget {
    use openzeppelin_interfaces::erc721::IERC721;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::extensions::erc721_consecutive::{
        DefaultConfig, ERC721ConsecutiveComponent,
    };
    use starknet::ContractAddress;
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
    impl Controls of super::super::balance_boundaries::IResearchConsecutive<ContractState> {
        fn burn(ref self: ContractState, id: u256) {
            self.erc721.burn(id);
        }
        fn mint_consecutive(ref self: ContractState, to: ContractAddress, amount: u64) -> u64 {
            self.consecutive.mint_consecutive(to, amount)
        }
    }

    #[abi(embed_v0)]
    impl Bench of super::IBenchTarget<ContractState> {
        fn execute(
            ref self: ContractState, op: u8, count: u32, to: ContractAddress, id: u256,
        ) -> u256 {
            if op == 10 {
                let owner: felt252 = self.erc721._owner_of(id).into();
                return owner.into();
            }
            if op == 9 {
                return self.erc721.balance_of(to);
            }
            self.erc721.transfer_from(201.try_into().unwrap(), to, id);
            0
        }
    }
}
fn run_consecutive(
    felt_selector: felt252,
    oz_selector: felt252,
    floor_selector: felt252,
    op: u8,
    count: u32,
    repeat: bool,
) {
    let (felt, _) = declare("FeltConsecutiveBenchTarget")
        .unwrap()
        .contract_class()
        .deploy(@array![201])
        .unwrap();
    let (oz, _) = declare("OZConsecutiveBenchTarget")
        .unwrap()
        .contract_class()
        .deploy(@array![201])
        .unwrap();
    let (floor, _) = declare("BenchFloor").unwrap().contract_class().deploy(@array![]).unwrap();
    let (probe, _) = declare("BenchProbe").unwrap().contract_class().deploy(@array![]).unwrap();
    let (receiver, _) = declare("DualCaseAccountMock")
        .unwrap()
        .contract_class()
        .deploy(@array![1234])
        .unwrap();
    let owner: ContractAddress = 201.try_into().unwrap();
    let to: ContractAddress = if op == 7 || op == 8 {
        receiver
    } else if op == 4 || op == 11 || op == 12 {
        202.try_into().unwrap()
    } else {
        owner
    };
    let id: u256 = 0;
    for target in array![felt, oz] {
        context(target, 201, 0, 0);
    }
    let a = starknet::syscalls::call_contract_syscall(
        probe, felt_selector, array![felt.into(), to.into(), id.low.into(), id.high.into()].span(),
    )
        .unwrap_syscall();
    let b = starknet::syscalls::call_contract_syscall(
        probe, oz_selector, array![oz.into(), to.into(), id.low.into(), id.high.into()].span(),
    )
        .unwrap_syscall();
    let c = starknet::syscalls::call_contract_syscall(
        probe,
        floor_selector,
        array![floor.into(), to.into(), id.low.into(), id.high.into()].span(),
    )
        .unwrap_syscall();
    assert_eq!(a, b);
    assert_eq!(a, c);
}
#[test]
#[ignore]
fn bench_erc721_consecutive_owner() {
    run_consecutive(
        selector!("felt_consecutive_owner"),
        selector!("oz_consecutive_owner"),
        selector!("floor_consecutive_owner"),
        10,
        2,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_consecutive_transfer() {
    run_consecutive(
        selector!("felt_consecutive_transfer"),
        selector!("oz_consecutive_transfer"),
        selector!("floor_consecutive_transfer"),
        4,
        2,
        false,
    );
}
#[test]
#[ignore]
fn bench_erc721_consecutive_balance() {
    run_consecutive(
        selector!("felt_consecutive_balance"),
        selector!("oz_consecutive_balance"),
        selector!("floor_consecutive_balance"),
        9,
        2,
        false,
    );
}
