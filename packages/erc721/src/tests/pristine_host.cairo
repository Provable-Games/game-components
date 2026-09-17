#[starknet::contract]
pub mod PristineBalanceHost {
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
}
