use metagame_extensions_interfaces::extension::ExtensionConfig;
use starknet::ContractAddress;
use crate::prize::structs::{Prize, PrizeRecord, PrizeType, TokenPrizePayload};
#[starknet::interface]
pub trait IHostPrize<T> {
    fn _get_prize(self: @T, prize_id: u64) -> PrizeRecord;
    fn _get_custom_shares(self: @T, prize_id: u64) -> Array<u16>;
    fn _get_custom_share_at(self: @T, prize_id: u64, position: u32) -> u16;
    fn set_token_record(
        ref self: T,
        prize_id: u64,
        context_id: u64,
        sponsor_address: ContractAddress,
        payload: TokenPrizePayload,
    );
    fn _get_total_prizes(self: @T) -> u64;
    fn increment_prize_count(ref self: T) -> u64;
    fn hash_prize_type(self: @T, prize_type: PrizeType) -> felt252;
    fn _is_prize_claimed(self: @T, context_id: u64, prize_type: PrizeType) -> bool;
    fn _is_prize_claimed_by_hash(self: @T, context_id: u64, prize_type_hash: felt252) -> bool;
    fn set_prize_claimed(ref self: T, context_id: u64, prize_type: PrizeType);
    fn _set_prize_claimed_by_hash(ref self: T, context_id: u64, prize_type_hash: felt252);
    fn assert_prize_exists(self: @T, prize_id: u64);
    fn assert_prize_not_claimed(self: @T, context_id: u64, prize_type: PrizeType);
    fn get_payout_position(self: @T, prize_id: u64) -> u32;
    fn set_payout_position(ref self: T, prize_id: u64, position: u32);
    fn _assert_prize_not_claimed_by_hash(self: @T, context_id: u64, prize_type_hash: felt252);
    fn add_prize(ref self: T, context_id: u64, prize: Prize) -> u64;
    fn _add_token_prize(ref self: T, context_id: u64, payload: TokenPrizePayload) -> u64;
    fn _set_extension(ref self: T, context_id: u64, prize_id: u64, ext: ExtensionConfig);
    fn payout_prize_extension(
        ref self: T,
        context_id: u64,
        prize_id: u64,
        token_id: Option<felt252>,
        payout_params: Span<felt252>,
    );
    fn payout_erc20(
        ref self: T, token_address: ContractAddress, amount: u128, recipient: ContractAddress,
    );
    fn payout_erc721(
        ref self: T, token_address: ContractAddress, token_id: u128, recipient: ContractAddress,
    );
    fn refund_prize_erc20(ref self: T, prize_id: u64, amount: u128);
    fn refund_prize_erc721(ref self: T, prize_id: u64, token_id: u128);
    fn get_extension_address(self: @T, context_id: u64, prize_id: u64) -> ContractAddress;
}
#[starknet::embeddable]
pub impl HostPrizeApi<
    TContractState, +crate::prize::store::Store<TContractState>, +Drop<TContractState>,
> of IHostPrize<TContractState> {
    fn _get_prize(self: @TContractState, prize_id: u64) -> PrizeRecord {
        crate::prize::api::PrizeInternalImpl::_get_prize(self, prize_id)
    }
    fn _get_custom_shares(self: @TContractState, prize_id: u64) -> Array<u16> {
        crate::prize::api::PrizeInternalImpl::_get_custom_shares(self, prize_id)
    }
    fn _get_custom_share_at(self: @TContractState, prize_id: u64, position: u32) -> u16 {
        crate::prize::api::PrizeInternalImpl::_get_custom_share_at(self, prize_id, position)
    }
    fn set_token_record(
        ref self: TContractState,
        prize_id: u64,
        context_id: u64,
        sponsor_address: ContractAddress,
        payload: TokenPrizePayload,
    ) {
        crate::prize::api::PrizeInternalImpl::set_token_record(
            ref self, prize_id, context_id, sponsor_address, payload,
        )
    }
    fn _get_total_prizes(self: @TContractState) -> u64 {
        crate::prize::api::PrizeInternalImpl::_get_total_prizes(self)
    }
    fn increment_prize_count(ref self: TContractState) -> u64 {
        crate::prize::api::PrizeInternalImpl::increment_prize_count(ref self)
    }
    fn hash_prize_type(self: @TContractState, prize_type: PrizeType) -> felt252 {
        crate::prize::api::PrizeInternalImpl::hash_prize_type(self, prize_type)
    }
    fn _is_prize_claimed(self: @TContractState, context_id: u64, prize_type: PrizeType) -> bool {
        crate::prize::api::PrizeInternalImpl::_is_prize_claimed(self, context_id, prize_type)
    }
    fn _is_prize_claimed_by_hash(
        self: @TContractState, context_id: u64, prize_type_hash: felt252,
    ) -> bool {
        crate::prize::api::PrizeInternalImpl::_is_prize_claimed_by_hash(
            self, context_id, prize_type_hash,
        )
    }
    fn set_prize_claimed(ref self: TContractState, context_id: u64, prize_type: PrizeType) {
        crate::prize::api::PrizeInternalImpl::set_prize_claimed(ref self, context_id, prize_type)
    }
    fn _set_prize_claimed_by_hash(
        ref self: TContractState, context_id: u64, prize_type_hash: felt252,
    ) {
        crate::prize::api::PrizeInternalImpl::_set_prize_claimed_by_hash(
            ref self, context_id, prize_type_hash,
        )
    }
    fn assert_prize_exists(self: @TContractState, prize_id: u64) {
        crate::prize::api::PrizeInternalImpl::assert_prize_exists(self, prize_id)
    }
    fn assert_prize_not_claimed(self: @TContractState, context_id: u64, prize_type: PrizeType) {
        crate::prize::api::PrizeInternalImpl::assert_prize_not_claimed(self, context_id, prize_type)
    }
    fn get_payout_position(self: @TContractState, prize_id: u64) -> u32 {
        crate::prize::api::PrizeInternalImpl::get_payout_position(self, prize_id)
    }
    fn set_payout_position(ref self: TContractState, prize_id: u64, position: u32) {
        crate::prize::api::PrizeInternalImpl::set_payout_position(ref self, prize_id, position)
    }
    fn _assert_prize_not_claimed_by_hash(
        self: @TContractState, context_id: u64, prize_type_hash: felt252,
    ) {
        crate::prize::api::PrizeInternalImpl::_assert_prize_not_claimed_by_hash(
            self, context_id, prize_type_hash,
        )
    }
    fn add_prize(ref self: TContractState, context_id: u64, prize: Prize) -> u64 {
        crate::prize::api::PrizeInternalImpl::add_prize(ref self, context_id, prize)
    }
    fn _add_token_prize(
        ref self: TContractState, context_id: u64, payload: TokenPrizePayload,
    ) -> u64 {
        crate::prize::api::PrizeInternalImpl::_add_token_prize(ref self, context_id, payload)
    }
    fn _set_extension(
        ref self: TContractState, context_id: u64, prize_id: u64, ext: ExtensionConfig,
    ) {
        crate::prize::api::PrizeInternalImpl::_set_extension(ref self, context_id, prize_id, ext)
    }
    fn payout_prize_extension(
        ref self: TContractState,
        context_id: u64,
        prize_id: u64,
        token_id: Option<felt252>,
        payout_params: Span<felt252>,
    ) {
        crate::prize::api::PrizeInternalImpl::payout_prize_extension(
            ref self, context_id, prize_id, token_id, payout_params,
        )
    }
    fn payout_erc20(
        ref self: TContractState,
        token_address: ContractAddress,
        amount: u128,
        recipient: ContractAddress,
    ) {
        crate::prize::api::PrizeInternalImpl::payout_erc20(
            ref self, token_address, amount, recipient,
        )
    }
    fn payout_erc721(
        ref self: TContractState,
        token_address: ContractAddress,
        token_id: u128,
        recipient: ContractAddress,
    ) {
        crate::prize::api::PrizeInternalImpl::payout_erc721(
            ref self, token_address, token_id, recipient,
        )
    }
    fn refund_prize_erc20(ref self: TContractState, prize_id: u64, amount: u128) {
        crate::prize::api::PrizeInternalImpl::refund_prize_erc20(ref self, prize_id, amount)
    }
    fn refund_prize_erc721(ref self: TContractState, prize_id: u64, token_id: u128) {
        crate::prize::api::PrizeInternalImpl::refund_prize_erc721(ref self, prize_id, token_id)
    }
    fn get_extension_address(
        self: @TContractState, context_id: u64, prize_id: u64,
    ) -> ContractAddress {
        crate::prize::api::PrizeInternalImpl::get_extension_address(self, context_id, prize_id)
    }
}

#[starknet::contract]
pub mod HostPrize {
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::prize::store::Store;
    use crate::prize::structs::{CustomShares, StoredPrize};
    #[storage]
    struct Storage {
        Prize_prizes: Map<u64, StoredPrize>,
        Prize_claims: Map<(u64, felt252), bool>,
        Prize_total_prizes: u64,
        Prize_custom_shares_packed: Map<(u64, u8), CustomShares>,
        Prize_extension_address: Map<(u64, u64), ContractAddress>,
        Prize_extension_prize_sponsor: Map<u64, ContractAddress>,
        metadata: Map<u64, u128>,
    }
    pub impl PrizeHostStore of Store<ContractState> {
        fn get_prize(self: @ContractState, prize_id: u64) -> StoredPrize {
            self.Prize_prizes.entry(prize_id).read()
        }

        fn set_prize(ref self: ContractState, prize_id: u64, prize: StoredPrize) {
            self.Prize_prizes.entry(prize_id).write(prize);
        }

        fn get_claim(self: @ContractState, context_id: u64, hash: felt252) -> bool {
            self.Prize_claims.entry((context_id, hash)).read()
        }

        fn set_claim(ref self: ContractState, context_id: u64, hash: felt252, claimed: bool) {
            self.Prize_claims.entry((context_id, hash)).write(claimed);
        }

        fn get_total_prizes(self: @ContractState) -> u64 {
            self.Prize_total_prizes.read()
        }

        fn set_total_prizes(ref self: ContractState, count: u64) {
            self.Prize_total_prizes.write(count);
        }

        fn get_custom_shares_count(self: @ContractState, prize_id: u64) -> u32 {
            ((self.metadata.entry(prize_id).read() / 0x10000000000000000_u128) & 0xffffffff)
                .try_into()
                .unwrap()
        }

        fn set_custom_shares_count(ref self: ContractState, prize_id: u64, count: u32) {
            let old = self.metadata.entry(prize_id).read();
            let value: u128 = count.into();
            self
                .metadata
                .entry(prize_id)
                .write(old - (old & 0xffffffff0000000000000000) + value * 0x10000000000000000_u128);
        }

        fn get_custom_shares_packed(self: @ContractState, prize_id: u64, slot: u8) -> CustomShares {
            self.Prize_custom_shares_packed.entry((prize_id, slot)).read()
        }

        fn set_custom_shares_packed(
            ref self: ContractState, prize_id: u64, slot: u8, shares: CustomShares,
        ) {
            self.Prize_custom_shares_packed.entry((prize_id, slot)).write(shares);
        }

        fn get_extension_address(
            self: @ContractState, context_id: u64, prize_id: u64,
        ) -> ContractAddress {
            self.Prize_extension_address.entry((context_id, prize_id)).read()
        }

        fn set_extension_address(
            ref self: ContractState, context_id: u64, prize_id: u64, addr: ContractAddress,
        ) {
            self.Prize_extension_address.entry((context_id, prize_id)).write(addr);
        }

        fn get_extension_prize_context(self: @ContractState, prize_id: u64) -> u64 {
            ((self.metadata.entry(prize_id).read() / 0x1_u128) & 0xffffffffffffffff)
                .try_into()
                .unwrap()
        }

        fn set_extension_prize_context(ref self: ContractState, prize_id: u64, context_id: u64) {
            let old = self.metadata.entry(prize_id).read();
            let value: u128 = context_id.into();
            self
                .metadata
                .entry(prize_id)
                .write(old - (old & 0xffffffffffffffff) + value * 0x1_u128);
        }

        fn get_extension_prize_sponsor(self: @ContractState, prize_id: u64) -> ContractAddress {
            self.Prize_extension_prize_sponsor.entry(prize_id).read()
        }

        fn set_extension_prize_sponsor(
            ref self: ContractState, prize_id: u64, sponsor: ContractAddress,
        ) {
            self.Prize_extension_prize_sponsor.entry(prize_id).write(sponsor);
        }

        fn get_payout_position(self: @ContractState, prize_id: u64) -> u32 {
            ((self.metadata.entry(prize_id).read() / 0x1000000000000000000000000_u128) & 0xffffffff)
                .try_into()
                .unwrap()
        }

        fn set_payout_position(ref self: ContractState, prize_id: u64, position: u32) {
            let old = self.metadata.entry(prize_id).read();
            let value: u128 = position.into();
            self
                .metadata
                .entry(prize_id)
                .write(
                    old
                        - (old & 0xffffffff000000000000000000000000)
                        + value * 0x1000000000000000000000000_u128,
                );
        }
    }
    #[abi(embed_v0)]
    impl Views = crate::prize::api::PrizeImpl<ContractState>;
    #[abi(embed_v0)]
    impl TestApi = super::HostPrizeApi<ContractState>;
}
#[starknet::contract]
pub mod AdapterPrize {
    use crate::prize::prize_component::PrizeComponent;
    component!(path: PrizeComponent, storage: prize, event: PrizeEvent);
    #[storage]
    struct Storage {
        #[substorage(v0)]
        prize: PrizeComponent::Storage,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PrizeEvent: PrizeComponent::Event,
    }
    impl PrizeStorage = crate::prize::storage_adapter::ComponentStore<ContractState>;
    #[abi(embed_v0)]
    impl Views = crate::prize::api::PrizeImpl<ContractState>;
    #[abi(embed_v0)]
    impl TestApi = super::HostPrizeApi<ContractState>;
}
