/// Mock contract that embeds the PrizeComponent for testing storage gas
#[starknet::contract]
pub mod PrizeMock {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::prize::prize_component::PrizeComponent;
    use crate::prize::structs::{Prize, PrizeType, TokenPrizePayload};

    component!(path: PrizeComponent, storage: prize, event: PrizeEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl PrizeImpl = PrizeComponent::PrizeImpl<ContractState>;

    impl PrizeInternalImpl = PrizeComponent::PrizeInternalImpl<ContractState>;

    impl PrizeInitializerImpl = PrizeComponent::PrizeInitializerImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        prize: PrizeComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PrizeEvent: PrizeComponent::Event,
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.prize.initializer();
    }

    /// Hash a prize type (exposes internal function for testing)
    #[external(v0)]
    fn hash_prize_type(self: @ContractState, prize_type: PrizeType) -> felt252 {
        self.prize.hash_prize_type(prize_type)
    }

    /// Check if prize is claimed (computes hash each time)
    #[external(v0)]
    fn is_claimed(self: @ContractState, context_id: u64, prize_type: PrizeType) -> bool {
        self.prize._is_prize_claimed(context_id, prize_type)
    }

    /// Check if prize is claimed using pre-computed hash
    #[external(v0)]
    fn is_claimed_by_hash(self: @ContractState, context_id: u64, prize_type_hash: felt252) -> bool {
        self.prize._is_prize_claimed_by_hash(context_id, prize_type_hash)
    }

    /// Set prize as claimed (computes hash each time)
    #[external(v0)]
    fn set_claimed(ref self: ContractState, context_id: u64, prize_type: PrizeType) {
        self.prize.set_prize_claimed(context_id, prize_type);
    }

    /// Set prize as claimed using pre-computed hash
    #[external(v0)]
    fn set_claimed_by_hash(ref self: ContractState, context_id: u64, prize_type_hash: felt252) {
        self.prize._set_prize_claimed_by_hash(context_id, prize_type_hash);
    }

    /// Check and set claimed in one operation (computes hash twice - before optimization pattern)
    #[external(v0)]
    fn check_and_set_claimed_no_cache(
        ref self: ContractState, context_id: u64, prize_type: PrizeType,
    ) -> bool {
        // This pattern computes the hash twice
        let was_claimed = self.prize._is_prize_claimed(context_id, prize_type);
        if !was_claimed {
            self.prize.set_prize_claimed(context_id, prize_type);
        }
        was_claimed
    }

    /// Check and set claimed in one operation (computes hash once - optimized pattern)
    #[external(v0)]
    fn check_and_set_claimed_with_cache(
        ref self: ContractState, context_id: u64, prize_type: PrizeType,
    ) -> bool {
        // This pattern computes the hash once and reuses it
        let prize_type_hash = self.prize.hash_prize_type(prize_type);
        let was_claimed = self.prize._is_prize_claimed_by_hash(context_id, prize_type_hash);
        if !was_claimed {
            self.prize._set_prize_claimed_by_hash(context_id, prize_type_hash);
        }
        was_claimed
    }

    /// Store a token prize directly (for component testing without token transfers)
    #[external(v0)]
    fn set_token_record(
        ref self: ContractState,
        prize_id: u64,
        context_id: u64,
        sponsor_address: ContractAddress,
        payload: TokenPrizePayload,
    ) {
        self.prize.set_token_record(prize_id, context_id, sponsor_address, payload);
    }

    // Note: get_prize and get_total_prizes are already exposed via #[abi(embed_v0)] PrizeImpl

    /// Increment prize count
    #[external(v0)]
    fn increment_prize_count(ref self: ContractState) -> u64 {
        self.prize.increment_prize_count()
    }

    /// Assert prize exists (panics if not)
    #[external(v0)]
    fn assert_prize_exists(self: @ContractState, prize_id: u64) {
        self.prize.assert_prize_exists(prize_id);
    }

    /// Assert prize not claimed (panics if claimed)
    #[external(v0)]
    fn assert_prize_not_claimed(self: @ContractState, context_id: u64, prize_type: PrizeType) {
        self.prize.assert_prize_not_claimed(context_id, prize_type);
    }

    /// Get custom shares for a prize
    #[external(v0)]
    fn get_custom_shares(self: @ContractState, prize_id: u64) -> Array<u16> {
        self.prize._get_custom_shares(prize_id)
    }

    /// Get extension address for a context and prize
    #[external(v0)]
    fn get_extension_address(
        self: @ContractState, context_id: u64, prize_id: u64,
    ) -> starknet::ContractAddress {
        self.prize.get_extension_address(context_id, prize_id)
    }

    /// Forward a payout to the prize extension for (context_id, prize_id).
    #[external(v0)]
    fn payout_prize_extension(
        ref self: ContractState,
        context_id: u64,
        prize_id: u64,
        token_id: Option<felt252>,
        payout_params: Span<felt252>,
    ) {
        self.prize.payout_prize_extension(context_id, prize_id, token_id, payout_params);
    }

    /// Add a prize (delegates to component). Exposes the full Prize sum-type
    /// so tests can drive both the Config and Extension paths.
    #[external(v0)]
    fn add_prize(ref self: ContractState, context_id: u64, prize: Prize) -> u64 {
        self.prize.add_prize(context_id, prize)
    }
}
